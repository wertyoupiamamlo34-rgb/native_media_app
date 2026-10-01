package com.example.native_media_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.MediaStyleNotificationHelper

/**
 * Foreground MediaSessionService.
 *
 * Notification features:
 *   - Album art (loaded asynchronously, never blocks the main thread).
 *   - Play/Pause icon flips with state.
 *   - 5 visible actions: Prev / Play-Pause / Next / Favorite / Close.
 *   - System seek-bar from MediaSession (provided by MediaStyle on Android 10+).
 *
 * Other responsibilities:
 *   - Progress ticker (500 ms) for UI sync.
 *   - Persists progress every 2 seconds.
 *   - Receives ACTION_INTERNAL_NOTIFY_REFRESH to re-render the notification
 *     when state changes outside the player listener (e.g. favorite toggle).
 */
class PlaybackService : MediaSessionService() {

    private lateinit var player: ExoPlayer
    private lateinit var mediaSession: MediaSession

    private val mainHandler = Handler(Looper.getMainLooper())
    private var tickCounter = 0
    private val progressTicker = object : Runnable {
        override fun run() {
            MediaEngineHolder.emitPlaybackState()
            tickCounter++
            if (tickCounter % 4 == 0) MediaEngineHolder.persistPlaybackProgress()
            mainHandler.postDelayed(this, TICK_INTERVAL_MS)
        }
    }

    private val notifyRefreshReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            updateNotification()
        }
    }

    private var currentArtBitmap: Bitmap? = null
    private var currentArtUri: String? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        player = ExoPlayer.Builder(this)
            .setHandleAudioBecomingNoisy(true)
            .build()
            .apply { addListener(buildPlayerListener()) }

        mediaSession = MediaSession.Builder(this, player).build()
        MediaEngineHolder.attach(applicationContext, player, mediaSession)
        MediaEngineHolder.restoreLastSession(applicationContext)

        startForeground(NOTIFICATION_ID, buildNotification())
        mainHandler.post(progressTicker)

        val filter = IntentFilter(MediaActionReceiver.ACTION_INTERNAL_NOTIFY_REFRESH)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notifyRefreshReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(notifyRefreshReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession =
        mediaSession

    override fun onTaskRemoved(rootIntent: Intent?) {
        MediaEngineHolder.persistPlaybackProgress()
        if (player.playWhenReady) {
            ContextCompat.startForegroundService(
                applicationContext,
                Intent(applicationContext, PlaybackService::class.java),
            )
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(progressTicker)
        runCatching { unregisterReceiver(notifyRefreshReceiver) }
        MediaEngineHolder.persistPlaybackProgress()
        MediaEngineHolder.releaseAudioEffects()
        mediaSession.release()
        player.release()
        currentArtBitmap?.recycle()
        currentArtBitmap = null
        super.onDestroy()
    }

    // ---------- Listener ----------
    private fun buildPlayerListener() = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            MediaEngineHolder.emitPlaybackState()
            updateNotification()
        }
        override fun onPlaybackStateChanged(state: Int) {
            MediaEngineHolder.emitPlaybackState()
            updateNotification()
        }
        override fun onMediaItemTransition(
            mediaItem: androidx.media3.common.MediaItem?, reason: Int
        ) {
            MediaState.currentMediaId = mediaItem?.mediaId ?: ""
            MediaState.refreshFavoriteFlag()
            loadArtworkAsync(mediaItem?.mediaMetadata?.artworkUri?.toString())
            MediaEngineHolder.emitPlaybackState()
            updateNotification()
        }
    }

    // ---------- Notification ----------
    private fun buildNotification(): Notification {
        val isPlaying = player.isPlaying
        val playPauseIcon =
            if (isPlaying) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play
        val playPauseLabel = if (isPlaying) "Pause" else "Play"

        val item = player.currentMediaItem
        val title = item?.mediaMetadata?.title?.toString() ?: "Media Player"
        val artist = item?.mediaMetadata?.artist?.toString() ?: ""

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(artist)
            .setOngoing(isPlaying)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setStyle(
                MediaStyleNotificationHelper.MediaStyle(mediaSession)
                    .setShowActionsInCompactView(1, 3, 4)
            )
            .addAction(
                android.R.drawable.ic_media_previous, "Previous",
                MediaControlReceiver.buildIntent(this, MediaActionReceiver.ACTION_PREV)
            )
            .addAction(
                playPauseIcon, playPauseLabel,
                MediaControlReceiver.buildIntent(this, MediaActionReceiver.ACTION_PLAY_PAUSE)
            )
            .addAction(
                android.R.drawable.ic_media_next, "Next",
                MediaControlReceiver.buildIntent(this, MediaActionReceiver.ACTION_NEXT)
            )
            .addAction(
                if (MediaState.favorite) android.R.drawable.btn_star_big_on
                else android.R.drawable.btn_star_big_off,
                "Favorite",
                MediaControlReceiver.buildIntent(this, MediaActionReceiver.ACTION_FAVORITE)
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel, "Close",
                MediaControlReceiver.buildIntent(this, MediaActionReceiver.ACTION_CLOSE)
            )

        currentArtBitmap?.let { builder.setLargeIcon(it) }

        // Tap notification -> reopen the app.
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            val pi = PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setContentIntent(pi)
        }

        return builder.build()
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun loadArtworkAsync(uriString: String?) {
        if (uriString.isNullOrBlank()) {
            currentArtBitmap?.recycle()
            currentArtBitmap = null
            currentArtUri = null
            return
        }
        if (uriString == currentArtUri && currentArtBitmap != null) return
        currentArtUri = uriString

        Thread {
            val bmp = try {
                contentResolver.openInputStream(Uri.parse(uriString))?.use {
                    BitmapFactory.decodeStream(it)
                }
            } catch (_: Exception) { null }

            mainHandler.post {
                if (uriString == currentArtUri) {
                    currentArtBitmap?.recycle()
                    currentArtBitmap = bmp
                    updateNotification()
                }
            }
        }.start()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Controls for background audio playback"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "playback_channel"
        private const val NOTIFICATION_ID = 1
        private const val TICK_INTERVAL_MS = 500L
    }
}
