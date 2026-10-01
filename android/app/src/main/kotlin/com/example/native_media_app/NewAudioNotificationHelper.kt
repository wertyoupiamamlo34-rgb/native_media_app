package com.example.native_media_app

import android.Manifest
import android.media.MediaPlayer
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.media.AudioAttributes
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.io.File

object NewAudioNotificationHelper {
    private const val tag = "NewAudioNotifHelper"
    private const val prefsName = "FlutterSharedPreferences"
    private const val knownTracksKey = "known_audio_tracks_v1"
    private const val baselineReadyKey = "audio_library_baseline_ready_v1"
    private const val enabledKey = "flutter.new_song_notifications_enabled"
    private const val soundEnabledKey = "flutter.new_song_notifications_sound_enabled"
    private const val toneKeyPref = "flutter.new_song_notification_tone_key"
    private const val defaultToneKey = "tone_one"
    private const val silentChannelId = "new_song_channel_silent"
    private const val channelName = "New Songs"
    private const val channelDescription = "Alerts the user when new songs are detected in the library."

    fun ensureChannels(context: Context) {
        // Channels stay silent; custom tones are played from Flutter assets at notify time.
        ensureChannel(context, toneKey = "tone_one")
        ensureChannel(context, toneKey = "tone_two")
        ensureChannel(context, toneKey = "tone_three")
        ensureChannel(context, soundEnabled = false)
    }

    fun syncAndNotifyIfNeeded(context: Context, tracks: List<Map<String, Any?>>) {
        if (!hasMediaPermission(context)) return

        val currentTrackKeys = tracks
            .map(::trackKey)
            .filter { it.isNotEmpty() }
            .toSet()

        if (currentTrackKeys.isEmpty()) return

        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val knownTrackKeys = prefs.getStringSet(knownTracksKey, emptySet()).orEmpty()
        val baselineReady = prefs.getBoolean(baselineReadyKey, false)
        val notificationsEnabled = prefs.getBoolean(enabledKey, true)
        val soundEnabled = prefs.getBoolean(soundEnabledKey, true)
        val toneKey = prefs.getString(toneKeyPref, defaultToneKey) ?: defaultToneKey

        if (!baselineReady) {
            prefs.edit()
                .putStringSet(knownTracksKey, currentTrackKeys)
                .putBoolean(baselineReadyKey, true)
                .apply()
            return
        }

        val newTracks = tracks
            .filter { !knownTrackKeys.contains(trackKey(it)) }
            .sortedByDescending { (it["dateAdded"] as? Number)?.toLong() ?: 0L }

        if (notificationsEnabled && newTracks.isNotEmpty()) {
            showNewTracksNotification(context, newTracks, soundEnabled, toneKey)
        }

        prefs.edit().putStringSet(knownTracksKey, currentTrackKeys).apply()
    }

    private fun showNewTracksNotification(
        context: Context,
        tracks: List<Map<String, Any?>>,
        soundEnabled: Boolean,
        toneKey: String,
    ) {
        if (!hasNotificationPermission(context)) return

        val channelId = if (soundEnabled) {
            channelIdForTone(toneKey)
        } else {
            silentChannelId
        }
        if (soundEnabled) {
            ensureChannel(context, toneKey)
        } else {
            ensureChannel(context, soundEnabled = false)
        }

        val firstTrack = tracks.first()
        val title = if (tracks.size == 1) {
            "تم استلام أغنية جديدة"
        } else {
            "تم استلام ${tracks.size} أغانٍ جديدة"
        }
        val trackTitle = firstTrack["title"]?.toString()?.takeIf { it.isNotBlank() }
            ?: firstTrack["displayName"]?.toString().orEmpty()
        val artist = firstTrack["artist"]?.toString()?.takeIf { it.isNotBlank() && it != "<unknown>" }
            ?: "فنان غير معروف"
        val body = if (tracks.size == 1) {
            "$trackTitle • $artist"
        } else {
            "$trackTitle • $artist و${tracks.size - 1} أخرى"
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }

        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(
            System.currentTimeMillis().toInt(),
            notification
        )

        if (soundEnabled) {
            playToneFromFlutterAssets(context, toneKey)
        }
    }

    private fun ensureChannel(context: Context, toneKey: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = channelIdForTone(toneKey)
        val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
            .apply {
                description = channelDescription
                setSound(null, null)
                enableVibration(true)
            }
        manager.createNotificationChannel(channel)
    }

    private fun ensureChannel(context: Context, soundEnabled: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(silentChannelId, channelName, NotificationManager.IMPORTANCE_HIGH)
            .apply {
                description = channelDescription
                setSound(null, null)
                enableVibration(false)
            }
        manager.createNotificationChannel(channel)
    }

    private fun channelIdForTone(toneKey: String): String = when (toneKey) {
        "tone_two" -> "new_song_channel_tone_two"
        "tone_three" -> "new_song_channel_tone_three"
        else -> "new_song_channel_tone_one"
    }

    private fun playToneFromFlutterAssets(context: Context, toneKey: String) {
        val flutterAssetPath = when (toneKey) {
            "tone_two" -> "flutter_assets/assets/audio/Sonva_Energy_Aura_1.mp3"
            "tone_three" -> "flutter_assets/assets/audio/Sonva_Energy_Aura_2.mp3"
            else -> "flutter_assets/assets/audio/Sonva_Energy_Aura_0.mp3"
        }

        try {
            val toneFile = copyAssetToInternalStorage(context, flutterAssetPath, toneKey) ?: return
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.setDataSource(toneFile.absolutePath)
            player.setOnPreparedListener { it.start() }
            player.setOnCompletionListener { it.release() }
            player.setOnErrorListener { mp, _, _ ->
                mp.release()
                true
            }
            player.prepareAsync()
        } catch (e: Exception) {
            Log.w(tag, "Unable to play notification tone from assets", e)
        }
    }

    private fun copyAssetToInternalStorage(
        context: Context,
        assetPath: String,
        toneKey: String,
    ): File? {
        return try {
            val tonesDir = File(context.filesDir, "notification_tones").apply { mkdirs() }
            val targetFile = File(tonesDir, "$toneKey.mp3")
            if (!targetFile.exists() || targetFile.length() == 0L) {
                context.assets.open(assetPath).use { input ->
                    targetFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }
            targetFile
        } catch (e: Exception) {
            Log.w(tag, "Unable to copy $assetPath to internal storage", e)
            null
        }
    }

    private fun trackKey(track: Map<String, Any?>): String {
        val path = track["path"]?.toString()?.trim().orEmpty()
        if (path.isNotEmpty()) return path.lowercase()

        val uri = track["uri"]?.toString()?.trim().orEmpty()
        if (uri.isNotEmpty()) return uri.lowercase()

        val name = track["displayName"]?.toString()?.trim().orEmpty()
        val duration = (track["duration"] as? Number)?.toLong() ?: 0L
        if (name.isNotEmpty() && duration > 0L) {
            return "${name.lowercase()}|$duration"
        }

        return track["id"]?.toString().orEmpty()
    }

    private fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun isNotificationSyncEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        return prefs.getBoolean(enabledKey, true) && hasMediaPermission(context)
    }

    private fun hasMediaPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_MEDIA_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }
}