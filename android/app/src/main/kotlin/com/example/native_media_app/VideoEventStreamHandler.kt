package com.example.native_media_app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Handles video playback events stream between native and Flutter.
 */
class VideoEventStreamHandler : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        VideoPlaybackEngine.setEventListener { event, data ->
            mainHandler.post {
                eventSink?.success(data)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        VideoPlaybackEngine.setEventListener(null)
    }
}
