package com.example.native_media_app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Single sink to Flutter. Late subscribers automatically receive the last
 * emitted event so the UI never starts stale.
 *
 * Event shapes (the "event" key disambiguates):
 *   playback_state    -> playing, positionMs, durationMs, bufferedPositionMs,
 *                        currentIndex, track, repeatMode, shuffleMode, favorite
 *   library_changed   -> timestamp
 *   lyrics_loaded     -> trackId, lines (List<Map>)
 *   favorite_changed  -> id, favorite
 *   error             -> code, message
 */
object PlaybackEventBus {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var lastPlaybackState: Map<String, Any?>? = null

    fun setSink(eventSink: EventChannel.EventSink?) {
        sink = eventSink
        // Re-deliver the last playback snapshot so UI hydrates instantly.
        lastPlaybackState?.let { state ->
            mainHandler.post { sink?.success(state) }
        }
    }

    fun emit(event: Map<String, Any?>) {
        if (event["event"] == "playback_state") {
            lastPlaybackState = event
        }
        mainHandler.post { sink?.success(event) }
    }
}

class PlaybackEventStreamHandler : EventChannel.StreamHandler {
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        PlaybackEventBus.setSink(events)
    }

    override fun onCancel(arguments: Any?) {
        PlaybackEventBus.setSink(null)
    }
}
