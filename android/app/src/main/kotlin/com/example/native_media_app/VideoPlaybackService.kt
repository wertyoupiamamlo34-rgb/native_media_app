package com.example.native_media_app

import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import android.util.Log
import androidx.media3.session.MediaSession

/**
 * Service that manages video playback lifecycle.
 * Keeps the engine alive and handles background operations.
 */
class VideoPlaybackService : Service() {

    private val binder = VideoBinder()

    inner class VideoBinder : Binder() {
        fun getService(): VideoPlaybackService = this@VideoPlaybackService
    }

    override fun onCreate() {
        super.onCreate()
        Log.d("VideoPlaybackService", "Service created")
        VideoPlaybackEngine.init(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("VideoPlaybackService", "Service started")
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d("VideoPlaybackService", "Service destroyed")
        VideoPlaybackEngine.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder = binder
}
