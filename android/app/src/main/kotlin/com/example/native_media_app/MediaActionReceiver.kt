package com.example.native_media_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives notification button clicks and forwards them to the engine.
 * The state change is then re-broadcast to Flutter via PlaybackEventBus.
 */
class MediaActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PLAY_PAUSE -> MediaEngineHolder.player?.let {
                if (it.isPlaying) it.pause() else it.play()
            }
            ACTION_NEXT -> MediaEngineHolder.player?.seekToNextMediaItem()
            ACTION_PREV -> MediaEngineHolder.player?.seekToPreviousMediaItem()

            ACTION_FAVORITE -> MediaEngineHolder.toggleFavoriteForCurrent()

            ACTION_REPEAT -> {
                val next = (MediaState.repeatMode + 1) % 3
                MediaEngineHolder.setRepeatMode(next)
            }
            ACTION_SHUFFLE -> MediaEngineHolder.setShuffleMode(!MediaState.shuffleMode)

            ACTION_CLOSE -> {
                MediaEngineHolder.persistPlaybackProgress()
                MediaEngineHolder.player?.apply {
                    pause(); release()
                }
                MediaEngineHolder.mediaSession?.release()
                MediaEngineHolder.player = null
                MediaEngineHolder.mediaSession = null
                context.stopService(Intent(context, PlaybackService::class.java))
            }
        }

        MediaEngineHolder.emitPlaybackState()
        // Ask service to redraw notification (icons depend on state).
        context.sendBroadcast(
            Intent(ACTION_INTERNAL_NOTIFY_REFRESH).setPackage(context.packageName)
        )
    }

    companion object {
        const val ACTION_PLAY_PAUSE = "app.media.PLAY_PAUSE"
        const val ACTION_NEXT = "app.media.NEXT"
        const val ACTION_PREV = "app.media.PREV"
        const val ACTION_FAVORITE = "app.media.FAVORITE"
        const val ACTION_REPEAT = "app.media.REPEAT"
        const val ACTION_SHUFFLE = "app.media.SHUFFLE"
        const val ACTION_CLOSE = "app.media.CLOSE"
        const val ACTION_INTERNAL_NOTIFY_REFRESH = "app.media.NOTIFY_REFRESH"
    }
}
