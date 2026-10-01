package com.example.native_media_app

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import kotlin.concurrent.thread

/**
 * Watches MediaStore for newly added audio/video files and emits a debounced
 * `library_changed` event to Flutter (via PlaybackEventBus).
 *
 * Debounce: many writes can happen in burst (e.g. file copy), so we coalesce
 * notifications inside a 750 ms window.
 */
class MediaContentObserver private constructor(
    private val appContext: Context,
    handler: Handler
) : ContentObserver(handler) {

    private val debouncer = Handler(Looper.getMainLooper())
    private val emitTask = Runnable {
        PlaybackEventBus.emit(
            mapOf(
                "event" to "library_changed",
                "timestamp" to System.currentTimeMillis()
            )
        )

    }

    override fun onChange(selfChange: Boolean) {
        // Coalesce multiple rapid changes into a single event.
        debouncer.removeCallbacks(emitTask)
        debouncer.postDelayed(emitTask, DEBOUNCE_MS)
    }

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        // Forward to the simple onChange handling.
        onChange(selfChange)
    }

    companion object {
        private const val DEBOUNCE_MS = 750L

        @Volatile
        private var instance: MediaContentObserver? = null

        fun register(context: Context) {
            if (instance != null) return
            val handler = Handler(Looper.getMainLooper())
            val observer = MediaContentObserver(context.applicationContext, handler)
            val resolver = context.applicationContext.contentResolver

            resolver.registerContentObserver(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, true, observer
            )
            resolver.registerContentObserver(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true, observer
            )
            instance = observer
        }

        fun unregister(context: Context) {
            instance?.let {
                context.applicationContext.contentResolver.unregisterContentObserver(it)
            }
            instance = null
        }
    }
}
