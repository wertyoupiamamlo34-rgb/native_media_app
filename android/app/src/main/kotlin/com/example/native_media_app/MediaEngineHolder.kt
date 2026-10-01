package com.example.native_media_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.Virtualizer
import androidx.core.content.ContextCompat
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import kotlin.math.abs

/**
 * Central holder of the ExoPlayer instance + MediaSession.
 *
 * Responsibilities:
 *   - Start/stop the foreground PlaybackService.
 *   - Build MediaItems with full metadata (including album art).
 *   - Apply repeat/shuffle modes and keep MediaState in sync.
 *   - Persist queue/index/position/repeat/shuffle to MediaPreferences.
 *   - Emit the unified playback_state event after every change.
 */
object MediaEngineHolder {

    var player: ExoPlayer? = null
    var mediaSession: MediaSession? = null
    private var appContext: Context? = null

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var attachedAudioSessionId: Int = C.AUDIO_SESSION_ID_UNSET
    private val uiBandFrequenciesHz = listOf(32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)

    private var eqEnabled = true
    private var bassBoostDb = 0f
    private var trebleDb = 0f
    private var virtualizerEnabled = false
    private var virtualizerStrength = 0f
    private val uiBandLevelsMb = mutableMapOf<Int, Int>()

    // ---------- Lifecycle ----------
    fun ensureServiceStarted(context: Context) {
        appContext = context.applicationContext
        val intent = Intent(appContext, PlaybackService::class.java)
        ContextCompat.startForegroundService(appContext!!, intent)
    }

    fun attach(context: Context, exoPlayer: ExoPlayer, session: MediaSession) {
        appContext = context.applicationContext
        player = exoPlayer
        mediaSession = session

        // Hydrate from preferences
        MediaState.repeatMode = MediaPreferences.loadRepeatMode(context)
        MediaState.shuffleMode = MediaPreferences.loadShuffleMode(context)
        MediaState.favoriteIds.clear()
        MediaState.favoriteIds.addAll(MediaPreferences.loadFavorites(context))

        exoPlayer.repeatMode = mapRepeat(MediaState.repeatMode)
        exoPlayer.shuffleModeEnabled = MediaState.shuffleMode

        exoPlayer.addListener(object : Player.Listener {
            override fun onAudioSessionIdChanged(audioSessionId: Int) {
                attachAudioEffects(audioSessionId)
            }
        })

        AndroidVisualizerEngine.setFrameListener { frame ->
            PlaybackEventBus.emit(
                mapOf(
                    "event" to "visualizer_frame",
                    "bins" to frame.bins,
                    "peaks" to frame.peaks,
                    "timestampMs" to frame.timestampMs,
                    "engine" to "visualizer_api"
                )
            )
        }

        attachAudioEffects(exoPlayer.audioSessionId)

        emitPlaybackState()
    }

    fun releaseAudioEffects() {
        AndroidVisualizerEngine.release()
        runCatching { equalizer?.release() }
        runCatching { bassBoost?.release() }
        runCatching { virtualizer?.release() }
        equalizer = null
        bassBoost = null
        virtualizer = null
        attachedAudioSessionId = C.AUDIO_SESSION_ID_UNSET
    }

    fun updateVisualizerAnalysisConfig(partialConfig: Map<String, Any?>) {
        AndroidVisualizerEngine.updateConfig(partialConfig)
    }

    fun setVolume(volume: Float) {
        player?.volume = volume.coerceIn(0f, 1f)
        emitPlaybackState()
    }

    fun setEqualizerEnabled(enabled: Boolean) {
        eqEnabled = enabled
        equalizer?.enabled = enabled
    }

    fun setEqualizerBandLevel(bandIndex: Int, levelDb: Float) {
        val safeUiBandIndex = bandIndex.coerceIn(0, uiBandFrequenciesHz.lastIndex)
        uiBandLevelsMb[safeUiBandIndex] = (levelDb.coerceIn(-15f, 15f) * 100f).toInt()
        equalizer?.let { applyEqualizerBands(it) }
    }

    fun setBassBoostDb(valueDb: Float) {
        bassBoostDb = valueDb.coerceIn(-10f, 10f)
        applyBassBoost()
    }

    fun setTrebleDb(valueDb: Float) {
        trebleDb = valueDb.coerceIn(-10f, 10f)
        equalizer?.let { applyEqualizerBands(it) }
    }

    fun setVirtualizerEnabled(enabled: Boolean) {
        virtualizerEnabled = enabled
        virtualizer?.enabled = enabled
    }

    fun setVirtualizerStrength(strength: Float) {
        virtualizerStrength = strength.coerceIn(0f, 1f)
        val v = virtualizer ?: return
        runCatching {
            v.setStrength((virtualizerStrength * 1000f).toInt().toShort())
        }
    }

    private fun attachAudioEffects(audioSessionId: Int) {
        if (audioSessionId == C.AUDIO_SESSION_ID_UNSET || audioSessionId == attachedAudioSessionId) {
            return
        }

        releaseAudioEffects()
        attachedAudioSessionId = audioSessionId
        AndroidVisualizerEngine.attach(audioSessionId)

        equalizer = runCatching {
            Equalizer(0, audioSessionId).apply {
                enabled = eqEnabled
            }
        }.getOrNull()

        bassBoost = runCatching {
            BassBoost(0, audioSessionId).apply {
                enabled = true
            }
        }.getOrNull()

        virtualizer = runCatching {
            Virtualizer(0, audioSessionId).apply {
                enabled = virtualizerEnabled
            }
        }.getOrNull()

        equalizer?.let { applyEqualizerBands(it) }
        applyBassBoost()
        setVirtualizerStrength(virtualizerStrength)
    }

    private fun applyBassBoost() {
        val boost = bassBoost ?: return
        val positiveDb = bassBoostDb.coerceAtLeast(0f)
        val strength = (positiveDb / 10f * 1000f).toInt().coerceIn(0, 1000)
        runCatching { boost.setStrength(strength.toShort()) }
    }

    private fun applyEqualizerBands(eq: Equalizer) {
        val range = eq.bandLevelRange
        val minMb = range[0].toInt()
        val maxMb = range[1].toInt()
        val bandCount = eq.numberOfBands.toInt()
        val trebleStart = (bandCount - 3).coerceAtLeast(0)
        val trebleDeltaMb = (trebleDb * 100f).toInt()

        val nativeBandAccumulatedMb = IntArray(bandCount)
        val nativeBandHitCount = IntArray(bandCount)

        for ((uiBandIndex, levelMb) in uiBandLevelsMb) {
            val nativeBand = mapUiBandToNativeBand(eq, uiBandIndex)
            nativeBandAccumulatedMb[nativeBand] += levelMb
            nativeBandHitCount[nativeBand] += 1
        }

        for (band in 0 until bandCount) {
            val baseLevelMb = if (nativeBandHitCount[band] > 0) {
                nativeBandAccumulatedMb[band] / nativeBandHitCount[band]
            } else {
                0
            }
            val levelMb = if (band >= trebleStart) {
                baseLevelMb + trebleDeltaMb
            } else {
                baseLevelMb
            }.coerceIn(minMb, maxMb)

            runCatching {
                eq.setBandLevel(band.toShort(), levelMb.toShort())
            }
        }
    }

    private fun mapUiBandToNativeBand(eq: Equalizer, uiBandIndex: Int): Int {
        val targetHz = uiBandFrequenciesHz.getOrElse(uiBandIndex) { uiBandFrequenciesHz.last() }
        val bandCount = eq.numberOfBands.toInt()
        var nearestBand = 0
        var nearestDiff = Long.MAX_VALUE

        for (band in 0 until bandCount) {
            val centerMilliHz = runCatching { eq.getCenterFreq(band.toShort()) }.getOrDefault(0)
            val centerHz = (centerMilliHz / 1000L)
            val diff = abs(centerHz - targetHz.toLong())
            if (diff < nearestDiff) {
                nearestDiff = diff
                nearestBand = band
            }
        }

        return nearestBand
    }

    // ---------- Queue ----------
    fun loadQueue(items: List<Map<String, Any?>>, startIndex: Int, startPositionMs: Long = 0L) {
        val p = player ?: return
        val safeIndex = startIndex.coerceIn(0, (items.size - 1).coerceAtLeast(0))

        val mediaItems = items.map { item ->
            val artUri = (item["albumArtUri"] as? String)?.takeIf { it.isNotBlank() }
            val metadataBuilder = MediaMetadata.Builder()
                .setTitle(item["title"]?.toString())
                .setArtist(item["artist"]?.toString())
                .setAlbumTitle(item["album"]?.toString())
            if (artUri != null) {
                metadataBuilder.setArtworkUri(Uri.parse(artUri))
            }

            MediaItem.Builder()
                .setMediaId(item["id"]?.toString() ?: "")
                .setUri(item["uri"]?.toString() ?: "")
                .setMediaMetadata(metadataBuilder.build())
                .build()
        }

        p.setMediaItems(mediaItems, safeIndex, startPositionMs)
        p.prepare()
        p.playWhenReady = true

        appContext?.let { ctx ->
            MediaPreferences.saveQueue(ctx, items)
            MediaPreferences.saveIndex(ctx, safeIndex)
            MediaPreferences.savePosition(ctx, startPositionMs)
        }
        emitPlaybackState()
    }

    /** Restores the previous session without starting playback. */
    fun restoreLastSession(context: Context) {
        val saved = MediaPreferences.loadQueue(context)
        if (saved.isEmpty()) return
        val index = MediaPreferences.loadIndex(context)
        val position = MediaPreferences.loadPosition(context)

        val p = player ?: return
        val mediaItems = saved.map { item ->
            val artUri = (item["albumArtUri"] as? String)?.takeIf { it.isNotBlank() }
            val metaBuilder = MediaMetadata.Builder()
                .setTitle(item["title"]?.toString())
                .setArtist(item["artist"]?.toString())
                .setAlbumTitle(item["album"]?.toString())
            if (artUri != null) metaBuilder.setArtworkUri(Uri.parse(artUri))

            MediaItem.Builder()
                .setMediaId(item["id"]?.toString() ?: "")
                .setUri(item["uri"]?.toString() ?: "")
                .setMediaMetadata(metaBuilder.build())
                .build()
        }
        p.setMediaItems(mediaItems, index.coerceIn(0, mediaItems.size - 1), position)
        p.prepare()
        p.playWhenReady = false
        emitPlaybackState()
    }

    // ---------- Modes ----------
    fun setRepeatMode(mode: Int) {
        val clamped = mode.coerceIn(0, 2)
        MediaState.repeatMode = clamped
        player?.repeatMode = mapRepeat(clamped)
        appContext?.let { MediaPreferences.saveRepeatMode(it, clamped) }
        emitPlaybackState()
    }

    fun setShuffleMode(on: Boolean) {
        MediaState.shuffleMode = on
        player?.shuffleModeEnabled = on
        appContext?.let { MediaPreferences.saveShuffleMode(it, on) }
        emitPlaybackState()
    }

    private fun mapRepeat(mode: Int): Int = when (mode) {
        MediaState.REPEAT_ONE -> Player.REPEAT_MODE_ONE
        MediaState.REPEAT_ALL -> Player.REPEAT_MODE_ALL
        else -> Player.REPEAT_MODE_OFF
    }

    // ---------- Favorites ----------
    fun toggleFavoriteForCurrent(): Boolean {
        val id = MediaState.currentMediaId
        if (id.isBlank()) return false
        val now = MediaState.toggleFavorite(id)
        appContext?.let { MediaPreferences.saveFavorites(it, MediaState.favoriteIds) }
        PlaybackEventBus.emit(
            mapOf("event" to "favorite_changed", "id" to id, "favorite" to now)
        )
        emitPlaybackState()
        return now
    }

    fun toggleFavoriteById(id: String): Boolean {
        if (id.isBlank()) return false
        val now = MediaState.toggleFavorite(id)
        appContext?.let { MediaPreferences.saveFavorites(it, MediaState.favoriteIds) }
        PlaybackEventBus.emit(
            mapOf("event" to "favorite_changed", "id" to id, "favorite" to now)
        )
        emitPlaybackState()
        return now
    }

    // ---------- Persistence tick (called by service ticker) ----------
    fun persistPlaybackProgress() {
        val p = player ?: return
        val ctx = appContext ?: return
        MediaPreferences.saveIndex(ctx, p.currentMediaItemIndex)
        MediaPreferences.savePosition(ctx, p.currentPosition)
    }

    // ---------- Emission ----------
    fun emitPlaybackState() {
        val p = player ?: return
        val item = p.currentMediaItem
        val currentId = item?.mediaId ?: ""
        if (currentId != MediaState.currentMediaId) {
            MediaState.currentMediaId = currentId
            MediaState.refreshFavoriteFlag()
        }

        val track = mapOf(
            "id" to currentId,
            "uri" to (item?.localConfiguration?.uri?.toString() ?: ""),
            "title" to (item?.mediaMetadata?.title?.toString() ?: ""),
            "artist" to (item?.mediaMetadata?.artist?.toString() ?: ""),
            "album" to (item?.mediaMetadata?.albumTitle?.toString() ?: ""),
            "albumArtUri" to (item?.mediaMetadata?.artworkUri?.toString() ?: "")
        )

        PlaybackEventBus.emit(
            mapOf(
                "event" to "playback_state",
                "playing" to p.isPlaying,
                "positionMs" to p.currentPosition.toInt(),
                "durationMs" to if (p.duration > 0) p.duration.toInt() else 0,
                "bufferedPositionMs" to p.bufferedPosition.toInt(),
                "currentIndex" to p.currentMediaItemIndex,
                "track" to track,
                "repeatMode" to MediaState.repeatMode,
                "shuffleMode" to MediaState.shuffleMode,
                "favorite" to MediaState.favorite,
                "favoriteIds" to MediaState.favoriteIds.toList()
            )
        )
    }
}
