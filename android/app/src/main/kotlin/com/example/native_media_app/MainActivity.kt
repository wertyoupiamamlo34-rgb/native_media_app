package com.example.native_media_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import kotlinx.coroutines.runBlocking
import java.io.File
import java.nio.ByteBuffer

/**
 * Flutter <-> Native bridge.
 *
 * MethodChannel:  app.media.commands
 * EventChannel :  app.media.events
 *
 * Available methods:
 *   initPlayer
 *   play / pause / next / previous / seekTo(positionMs)
 *   loadQueue(items, startIndex, startPositionMs?)
 *   getDeviceAudio / getDeviceVideos
 *   loadLyrics(trackId, title, audioUri?)
 *   setRepeatMode(mode 0..2)
 *   setShuffleMode(on:Bool)
 *   toggleFavorite           // current track
 *   toggleFavoriteById(id)
 *   getFavorites             // -> List<String>
 *   getLastSession           // -> { items, index, positionMs, repeatMode, shuffleMode }
 *   refreshLibrary           // manual nudge for library_changed event
 */
class MainActivity : FlutterActivity() {

    private val commandChannel = "app.media.commands"
    private val eventChannel = "app.media.events"
    private val mediaStoreChannel = "sonva/media_store"

    private lateinit var lyricsRepo: LyricsRepository
    private lateinit var mediaRepo: MediaStoreRepo

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        lyricsRepo = LyricsRepository(applicationContext)
        mediaRepo = MediaStoreRepo(applicationContext)

        MediaEngineHolder.ensureServiceStarted(applicationContext)
        MediaContentObserver.register(applicationContext)
        NewAudioMonitorScheduler.schedule(applicationContext)
        NewAudioNotificationHelper.ensureChannels(applicationContext)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannel)
            .setStreamHandler(PlaybackEventStreamHandler())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, commandChannel)
            .setMethodCallHandler { call, result ->
                try {
                    handleCall(call.method, call, result)
                } catch (t: Throwable) {
                    result.error("NATIVE_ERROR", t.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaStoreChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "trimAudio" -> handleTrimAudio(call, result)
                        "stopPreview" -> {
                            previewShouldResumeMainPlayer = false
                            stopPreviewPlayback(
                                message = "تم إيقاف المعاينة",
                                ok = true
                            )
                            result.success(
                                mapOf(
                                    "ok" to true,
                                    "message" to "تم إيقاف المعاينة"
                                )
                            )
                        }
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("NATIVE_TRIM_ERROR", t.message, null)
                }
            }
    }

    private fun handleTrimAudio(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        val sourceRaw = call.argument<String>("path").orEmpty()
        val title = call.argument<String>("title").orEmpty().ifBlank { "Track" }
        val artist = call.argument<String>("artist").orEmpty().ifBlank { "Unknown" }
        val startSec = (call.argument<Number>("startSec") ?: 0).toLong().coerceAtLeast(0)
        val endSec = (call.argument<Number>("endSec") ?: 0).toLong().coerceAtLeast(0)
        val action = call.argument<String>("action").orEmpty().ifBlank { "save" }

        if (endSec <= startSec) {
            result.success(
                mapOf(
                    "ok" to false,
                    "message" to "نطاق القص غير صالح",
                    "outputPath" to ""
                )
            )
            return
        }

        val sourceUri = parseSourceUri(sourceRaw)
        if (sourceUri == null) {
            result.success(
                mapOf(
                    "ok" to false,
                    "message" to "المصدر غير صالح",
                    "outputPath" to ""
                )
            )
            return
        }

        if (action == "preview") {
            val mainPlayerWasPlaying = MediaEngineHolder.player?.isPlaying == true
            if (mainPlayerWasPlaying) {
                MediaEngineHolder.player?.pause()
                MediaEngineHolder.emitPlaybackState()
            }
            previewShouldResumeMainPlayer = mainPlayerWasPlaying

            previewSegment(sourceUri, startSec, endSec) { ok, message ->
                if (previewShouldResumeMainPlayer) {
                    MediaEngineHolder.player?.play()
                    MediaEngineHolder.emitPlaybackState()
                }
                previewShouldResumeMainPlayer = false
                result.success(
                    mapOf(
                        "ok" to ok,
                        "message" to message,
                        "outputPath" to ""
                    )
                )
            }
            return
        }

        val outputUri = saveAsClip(sourceUri, title, artist, startSec, endSec)
        if (outputUri == null) {
            result.success(
                mapOf(
                    "ok" to false,
                    "message" to "تعذر حفظ الملف",
                    "outputPath" to ""
                )
            )
            return
        }

        val toneMessage = when (action) {
            "ringtone" -> setAsDefaultTone(outputUri, RingtoneManager.TYPE_RINGTONE)
            "notification" -> setAsDefaultTone(outputUri, RingtoneManager.TYPE_NOTIFICATION)
            "alarm" -> setAsDefaultTone(outputUri, RingtoneManager.TYPE_ALARM)
            else -> null
        }

        val msg = toneMessage ?: when (action) {
            "save" -> "تم حفظ القصاصة بنجاح"
            "ringtone" -> "تم تعيين القصاصة كنغمة رنين"
            "notification" -> "تم تعيين القصاصة كنغمة إشعارات"
            "alarm" -> "تم تعيين القصاصة كنغمة منبه"
            else -> "تمت العملية بنجاح"
        }

        result.success(
            mapOf(
                "ok" to true,
                "message" to msg,
                "outputPath" to outputUri.toString()
            )
        )
    }

    private fun parseSourceUri(raw: String): Uri? {
        val input = raw.trim()
        if (input.isEmpty()) return null
        if (input.startsWith("content://") || input.startsWith("file://")) {
            return Uri.parse(input)
        }
        val file = File(input)
        if (!file.exists()) return null
        return Uri.fromFile(file)
    }

    private fun previewSegment(
        uri: Uri,
        startSec: Long,
        endSec: Long,
        onFinished: (Boolean, String) -> Unit
    ) {
        try {
            previewStopHandler.removeCallbacksAndMessages(null)
            previewPlayer?.release()
            previewPlayer = MediaPlayer().apply {
                var completed = false

                fun complete(ok: Boolean, message: String) {
                    if (completed) return
                    completed = true
                    previewFinishCallback = null
                    onFinished(ok, message)
                }

                previewFinishCallback = { ok, message ->
                    complete(ok, message)
                }

                setDataSource(applicationContext, uri)
                setOnPreparedListener { player ->
                    val startMs = (startSec * 1000L).coerceAtLeast(0)
                    val endMs = endSec * 1000L
                    val boundedEndMs = endMs.coerceAtMost(player.duration.toLong())
                    player.seekTo(startMs.toInt())
                    player.start()
                    val playWindow = (boundedEndMs - startMs).coerceAtLeast(500L)
                    previewStopHandler.postDelayed({
                        try {
                            player.stop()
                        } catch (_: Throwable) {
                        }
                        try {
                            player.release()
                        } catch (_: Throwable) {
                        }
                        if (previewPlayer === player) {
                            previewPlayer = null
                        }
                        complete(true, "تمت معاينة الجزء المحدد")
                    }, playWindow)
                }
                setOnErrorListener { mp, _, _ ->
                    try {
                        mp.release()
                    } catch (_: Throwable) {
                    }
                    if (previewPlayer === mp) {
                        previewPlayer = null
                    }
                    complete(false, "تعذرت المعاينة")
                    true
                }
                prepareAsync()
            }
        } catch (_: Throwable) {
            previewFinishCallback = null
            onFinished(false, "تعذرت المعاينة")
        }
    }

    private fun stopPreviewPlayback(message: String, ok: Boolean) {
        previewStopHandler.removeCallbacksAndMessages(null)

        val player = previewPlayer
        if (player != null) {
            try {
                player.stop()
            } catch (_: Throwable) {
            }
            try {
                player.release()
            } catch (_: Throwable) {
            }
            previewPlayer = null
        }

        val callback = previewFinishCallback
        previewFinishCallback = null
        callback?.invoke(ok, message)
    }

    private fun saveAsClip(
        sourceUri: Uri,
        title: String,
        artist: String,
        startSec: Long,
        endSec: Long
    ): Uri? {
        val ext = "m4a"
        val displayName = buildString {
            append(title.ifBlank { "clip" })
            append("_")
            append(startSec)
            append("-")
            append(endSec)
            append(".")
            append(ext)
        }

        val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "Music/Sonva/Clips"
        } else {
            null
        }

        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.TITLE, title)
            put(MediaStore.Audio.Media.ARTIST, artist)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Audio.Media.RELATIVE_PATH, relativePath)
            }
            put(MediaStore.Audio.Media.IS_MUSIC, 1)
            put(MediaStore.Audio.Media.IS_RINGTONE, 1)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_ALARM, 1)
        }

        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val inserted = resolver.insert(collection, values) ?: return null
        val tempFile = File(
            applicationContext.cacheDir,
            "clip_${System.currentTimeMillis()}.m4a"
        )

        return try {
            val trimmed = trimAudioRangeToFile(
                sourceUri = sourceUri,
                targetFile = tempFile,
                startSec = startSec,
                endSec = endSec
            )
            if (!trimmed || !tempFile.exists() || tempFile.length() <= 0L) {
                throw IllegalStateException("trim failed")
            }

            resolver.openOutputStream(inserted, "w").use { output ->
                if (output == null) throw IllegalStateException("cannot open target")
                tempFile.inputStream().use { input ->
                    input.copyTo(output)
                }
            }
            inserted
        } catch (_: Throwable) {
            runCatching { resolver.delete(inserted, null, null) }
            null
        } finally {
            runCatching {
                if (tempFile.exists()) {
                    tempFile.delete()
                }
            }
        }
    }

    private fun trimAudioRangeToFile(
        sourceUri: Uri,
        targetFile: File,
        startSec: Long,
        endSec: Long
    ): Boolean {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null

        return try {
            extractor.setDataSource(applicationContext, sourceUri, null)
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (audioTrackIndex == -1 || audioFormat == null) {
                return false
            }

            if (targetFile.exists()) {
                targetFile.delete()
            }

            extractor.selectTrack(audioTrackIndex)
            muxer = MediaMuxer(targetFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxerTrackIndex = muxer.addTrack(audioFormat)
            muxer.start()

            val startUs = (startSec.coerceAtLeast(0L)) * 1_000_000L
            val endUs = endSec * 1_000_000L
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

            val maxInputSize = if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceAtLeast(64 * 1024)
            } else {
                256 * 1024
            }
            val byteBuffer = ByteBuffer.allocate(maxInputSize)
            val bufferInfo = MediaCodec.BufferInfo()
            var wroteAnySample = false

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(byteBuffer, 0)
                if (bufferInfo.size < 0) {
                    break
                }

                val sampleTimeUs = extractor.sampleTime
                if (sampleTimeUs < 0) {
                    break
                }
                if (sampleTimeUs < startUs) {
                    extractor.advance()
                    continue
                }
                if (sampleTimeUs >= endUs) {
                    break
                }

                bufferInfo.presentationTimeUs = sampleTimeUs - startUs
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(muxerTrackIndex, byteBuffer, bufferInfo)
                wroteAnySample = true
                extractor.advance()
            }
            wroteAnySample
        } catch (_: Throwable) {
            false
        } finally {
            runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { extractor.release() }
        }
    }

    private fun setAsDefaultTone(uri: Uri, type: Int): String? {
        return try {
            RingtoneManager.setActualDefaultRingtoneUri(applicationContext, type, uri)
            null
        } catch (_: Throwable) {
            "تم الحفظ، لكن تعيين النغمة الافتراضية فشل على هذا الجهاز"
        }
    }

    private fun guessExtension(uri: Uri): String {
        val raw = uri.toString().lowercase()
        return when {
            raw.endsWith(".m4a") -> "m4a"
            raw.endsWith(".wav") -> "wav"
            raw.endsWith(".ogg") -> "ogg"
            raw.endsWith(".flac") -> "flac"
            else -> "mp3"
        }
    }

    companion object {
        private var previewPlayer: MediaPlayer? = null
        private val previewStopHandler = Handler(Looper.getMainLooper())
        private var previewFinishCallback: ((Boolean, String) -> Unit)? = null
        private var previewShouldResumeMainPlayer: Boolean = false
    }

    private fun handleCall(
        method: String,
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        when (method) {
            "initPlayer" -> {
                MediaEngineHolder.ensureServiceStarted(applicationContext)
                result.success(true)
            }

            "play" -> {
                MediaEngineHolder.player?.play()
                MediaEngineHolder.emitPlaybackState()
                result.success(true)
            }

            "pause" -> {
                MediaEngineHolder.player?.pause()
                MediaEngineHolder.emitPlaybackState()
                result.success(true)
            }

            "next" -> {
                MediaEngineHolder.player?.seekToNextMediaItem()
                MediaEngineHolder.emitPlaybackState()
                result.success(true)
            }

            "previous" -> {
                MediaEngineHolder.player?.seekToPreviousMediaItem()
                MediaEngineHolder.emitPlaybackState()
                result.success(true)
            }

            "seekTo" -> {
                val positionMs = (call.argument<Number>("positionMs") ?: 0).toLong()
                MediaEngineHolder.player?.seekTo(positionMs)
                MediaEngineHolder.emitPlaybackState()
                result.success(true)
            }

            "loadQueue" -> {
                @Suppress("UNCHECKED_CAST")
                val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                val startIndex = call.argument<Int>("startIndex") ?: 0
                val startPos = (call.argument<Number>("startPositionMs") ?: 0).toLong()
                MediaEngineHolder.loadQueue(items, startIndex, startPos)
                result.success(true)
            }

            "getDeviceAudio" -> {
                val forceRefresh = call.argument<Boolean>("forceRefresh") ?: false
                val audio = mediaRepo.getAllAudio(forceRefresh = forceRefresh)
                if (NewAudioNotificationHelper.isNotificationSyncEnabled(applicationContext)) {
                    NewAudioNotificationHelper.syncAndNotifyIfNeeded(applicationContext, audio)
                }
                result.success(audio)
            }
            "getAudioArtwork" -> {
                val trackId = call.argument<String>("trackId").orEmpty()
                val albumId = call.argument<String>("albumId").orEmpty()
                val trackUri = call.argument<String>("trackUri").orEmpty()
                val path = call.argument<String>("path")
                result.success(mediaRepo.getAudioArtworkUriForTrack(trackId, albumId, trackUri, path))
            }
            "loadLyrics" -> {
                val trackId = call.argument<String>("trackId").orEmpty()
                val title = call.argument<String>("title").orEmpty()
                val audioUri = call.argument<String>("audioUri")
                val audioPath = call.argument<String>("audioPath")
                val displayName = call.argument<String>("displayName")
                val lines = lyricsRepo.load(trackId, title, audioUri, audioPath, displayName)
                // Push as event too, so any open lyrics screen reacts.
                PlaybackEventBus.emit(
                    mapOf(
                        "event" to "lyrics_loaded",
                        "trackId" to trackId,
                        "lines" to lines
                    )
                )
                result.success(lines)
            }

            "setRepeatMode" -> {
                val mode = call.argument<Int>("mode") ?: 0
                MediaEngineHolder.setRepeatMode(mode)
                result.success(MediaState.repeatMode)
            }

            "setShuffleMode" -> {
                val on = call.argument<Boolean>("on") ?: false
                MediaEngineHolder.setShuffleMode(on)
                result.success(MediaState.shuffleMode)
            }

            "setVolume" -> {
                val volume = (call.argument<Number>("volume") ?: 1.0).toFloat()
                MediaEngineHolder.setVolume(volume)
                result.success(true)
            }

            "setEqualizerEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                MediaEngineHolder.setEqualizerEnabled(enabled)
                result.success(true)
            }

            "setEqualizerBandLevel" -> {
                val bandIndex = call.argument<Int>("bandIndex") ?: 0
                val levelDb = (call.argument<Number>("levelDb") ?: 0).toFloat()
                MediaEngineHolder.setEqualizerBandLevel(bandIndex, levelDb)
                result.success(true)
            }

            "setBassBoostDb" -> {
                val valueDb = (call.argument<Number>("valueDb") ?: 0).toFloat()
                MediaEngineHolder.setBassBoostDb(valueDb)
                result.success(true)
            }

            "setTrebleDb" -> {
                val valueDb = (call.argument<Number>("valueDb") ?: 0).toFloat()
                MediaEngineHolder.setTrebleDb(valueDb)
                result.success(true)
            }

            "setVirtualizerEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                MediaEngineHolder.setVirtualizerEnabled(enabled)
                result.success(true)
            }

            "setVirtualizerStrength" -> {
                val strength = (call.argument<Number>("strength") ?: 0).toFloat()
                MediaEngineHolder.setVirtualizerStrength(strength)
                result.success(true)
            }

            "setVisualizerAnalysisConfig" -> {
                @Suppress("UNCHECKED_CAST")
                val config = call.argument<Map<String, Any?>>("config") ?: emptyMap()
                MediaEngineHolder.updateVisualizerAnalysisConfig(config)
                result.success(true)
            }

            "toggleFavorite" -> {
                val now = MediaEngineHolder.toggleFavoriteForCurrent()
                result.success(now)
            }

            "toggleFavoriteById" -> {
                val id = call.argument<String>("id").orEmpty()
                val now = MediaEngineHolder.toggleFavoriteById(id)
                result.success(now)
            }

            "getFavorites" -> {
                result.success(MediaState.favoriteIds.toList())
            }

            "getLastSession" -> {
                val ctx = applicationContext
                result.success(
                    mapOf(
                        "items" to MediaPreferences.loadQueue(ctx),
                        "index" to MediaPreferences.loadIndex(ctx),
                        "positionMs" to MediaPreferences.loadPosition(ctx),
                        "repeatMode" to MediaPreferences.loadRepeatMode(ctx),
                        "shuffleMode" to MediaPreferences.loadShuffleMode(ctx)
                    )
                )
            }

            "refreshLibrary" -> {
                PlaybackEventBus.emit(
                    mapOf(
                        "event" to "library_changed",
                        "timestamp" to System.currentTimeMillis()
                    )
                )
                result.success(true)
            }

            "openExternalUrl" -> {
                val url = call.argument<String>("url").orEmpty()
                val preferChrome = call.argument<Boolean>("preferChrome") ?: false
                if (url.isBlank()) {
                    result.success(false)
                    return
                }

                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    if (preferChrome) {
                        setPackage("com.android.chrome")
                    }
                }

                try {
                    startActivity(intent)
                    result.success(true)
                } catch (_: Throwable) {
                    try {
                        val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(fallbackIntent)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("OPEN_URL_FAILED", e.message, null)
                    }
                }
            }

            "openNewSongNotificationChannelSettings" -> {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    val intent = android.content.Intent(
                        android.provider.Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS
                    ).apply {
                        putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                        putExtra(
                            android.provider.Settings.EXTRA_CHANNEL_ID,
                            "new_song_channel_sound"
                        )
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            // Backwards compatibility with the previous "FAVORITE" name.
            "FAVORITE" -> {
                val now = MediaEngineHolder.toggleFavoriteForCurrent()
                result.success(now)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDestroy() {
        MediaContentObserver.unregister(applicationContext)
        stopPreviewPlayback(message = "", ok = true)
        super.onDestroy()
    }
}
