package com.example.native_media_app

import android.content.Context
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import kotlin.math.max

/**
 * Handles video playback using Media3 ExoPlayer.
 * Manages state, events, and playback control.
 */
object VideoPlaybackEngine {

    data class VideoState(
        val isPlaying: Boolean = false,
        val positionMs: Long = 0L,
        val durationMs: Long = 0L,
        val bufferedPositionMs: Long = 0L,
        val isBuffering: Boolean = false,
        val playbackSpeed: Float = 1f,
        val isCompleted: Boolean = false
    )

    private var exoPlayer: ExoPlayer? = null
    private var mediaSession: MediaSession? = null
    private var context: Context? = null
    private var eventListener: ((event: String, data: Map<String, Any?>) -> Unit)? = null
    private var playerListener: Player.Listener? = null

    /**
     * Initialize the video engine with a context.
     */
    fun init(ctx: Context) {
        if (exoPlayer != null) {
            context = ctx.applicationContext
            return
        }
        context = ctx.applicationContext

        exoPlayer = ExoPlayer.Builder(context!!)
            .setUseLazyPreparation(true)
            .setSeekBackIncrementMs(5000)
            .setSeekForwardIncrementMs(5000)
            .build()
            .apply {
                setPlayWhenReady(false)
                setHandleAudioBecomingNoisy(true)
            }

        setupPlayerListener()
    }

    private fun ensurePlayerInitialized(): ExoPlayer? {
        if (exoPlayer == null) {
            context?.let { init(it) }
        }
        return exoPlayer
    }

    /**
     * Attach a MediaSession for system integration.
     */
    fun attachMediaSession(session: MediaSession) {
        mediaSession = session
    }

    /**
     * Set a listener for video events.
     */
    fun setEventListener(listener: ((event: String, data: Map<String, Any?>) -> Unit)?) {
        eventListener = listener
    }

    /**
     * Load a video from URI.
     */
    fun loadVideo(uri: String) {
        val player = ensurePlayerInitialized() ?: run {
            emitEvent("error", mapOf("message" to "Video engine not initialized"))
            return
        }

        try {
            val mediaItem = MediaItem.fromUri(uri)
            player.setMediaItem(mediaItem)
            player.prepare()
        } catch (e: Exception) {
            emitEvent("error", mapOf("message" to (e.message ?: "Failed to load video")))
        }
    }

    /**
     * Load multiple videos (playlist).
     */
    fun loadPlaylist(uris: List<String>) {
        val player = ensurePlayerInitialized() ?: run {
            emitEvent("error", mapOf("message" to "Video engine not initialized"))
            return
        }

        try {
            val mediaItems = uris.map { MediaItem.fromUri(it) }
            player.setMediaItems(mediaItems)
            player.prepare()
        } catch (e: Exception) {
            emitEvent("error", mapOf("message" to (e.message ?: "Failed to load playlist")))
        }
    }

    /**
     * Play the current video.
     */
    fun play() {
        ensurePlayerInitialized()?.play()
    }

    /**
     * Pause the current video.
     */
    fun pause() {
        ensurePlayerInitialized()?.pause()
    }

    /**
     * Seek to a specific position in milliseconds.
     */
    fun seekTo(positionMs: Long) {
        ensurePlayerInitialized()?.seekTo(positionMs.coerceAtLeast(0))
    }

    /**
     * Seek to a specific track in the playlist.
     */
    fun seekToTrack(index: Int) {
        val player = ensurePlayerInitialized() ?: return
        val trackCount = player.mediaItemCount
        if (index >= 0 && index < trackCount) {
            player.seekToDefaultPosition(index)
        }
    }

    /**
     * Set playback speed.
     */
    fun setPlaybackSpeed(speed: Float) {
        ensurePlayerInitialized()?.setPlaybackSpeed(speed.coerceIn(0.25f, 2f))
    }

    /**
     * Get current state.
     */
    fun getState(): VideoState {
        val player = ensurePlayerInitialized() ?: return VideoState()
        return VideoState(
            isPlaying = player.isPlaying,
            positionMs = player.currentPosition,
            durationMs = player.duration.takeIf { it >= 0 } ?: 0L,
            bufferedPositionMs = player.bufferedPosition,
            isBuffering = player.playbackState == Player.STATE_BUFFERING,
            playbackSpeed = player.playbackParameters.speed,
            isCompleted = player.playbackState == Player.STATE_ENDED
        )
    }

    /**
     * Return the active ExoPlayer instance for platform view rendering.
     */
    fun getPlayer(): ExoPlayer? = ensurePlayerInitialized()

    /**
     * Stop playback and release resources.
     */
    fun stop() {
        ensurePlayerInitialized()?.stop()
        emitEvent("stopped", emptyMap())
    }

    /**
     * Release all resources.
     */
    fun release() {
        playerListener?.let { listener ->
            exoPlayer?.removeListener(listener)
        }
        exoPlayer?.release()
        exoPlayer = null
        context = null
        eventListener = null
    }

    /**
     * Get current track index in playlist.
     */
    fun getCurrentTrackIndex(): Int = ensurePlayerInitialized()?.currentMediaItemIndex ?: 0

    /**
     * Get playlist size.
     */
    fun getPlaylistSize(): Int = ensurePlayerInitialized()?.mediaItemCount ?: 0

    /**
     * Remove a track from playlist by index.
     */
    fun removeTrack(index: Int) {
        val player = ensurePlayerInitialized() ?: return
        val size = player.mediaItemCount
        if (index >= 0 && index < size) {
            player.removeMediaItem(index)
        }
    }

    /**
     * Clear playlist.
     */
    fun clearPlaylist() {
        ensurePlayerInitialized()?.clearMediaItems()
    }

    private fun setupPlayerListener() {
        playerListener = object : Player.Listener {
            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                emitEvent("playing_state", mapOf("playing" to playWhenReady))
            }

            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_READY -> {
                        val videoState = getState()
                        emitEvent("ready", mapOf(
                            "positionMs" to videoState.positionMs,
                            "durationMs" to videoState.durationMs
                        ))
                    }
                    Player.STATE_BUFFERING -> {
                        emitEvent("buffering", mapOf("buffering" to true))
                    }
                    Player.STATE_ENDED -> {
                        emitEvent("completed", mapOf("currentIndex" to getCurrentTrackIndex()))
                    }
                    Player.STATE_IDLE -> {
                        // Idle state
                    }
                }
            }

            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                emitEvent("track_changed", mapOf(
                    "currentIndex" to getCurrentTrackIndex(),
                    "totalTracks" to getPlaylistSize()
                ))
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                emitEvent("error", mapOf(
                    "message" to (error.message ?: "Playback error"),
                    "errorCode" to error.errorCode
                ))
            }
        }

        playerListener?.let { exoPlayer?.addListener(it) }
    }

    private fun emitEvent(event: String, data: Map<String, Any?>) {
        val eventData: MutableMap<String, Any?> = mutableMapOf("event" to event)
        eventData.putAll(data)
        eventListener?.invoke(event, eventData as Map<String, Any?>)
    }
}
