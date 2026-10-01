package com.example.native_media_app

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * Factory for PendingIntents bound to MediaActionReceiver.
 * Centralised so every notification action shares the same intent flags.
 */
object MediaControlReceiver {

    fun buildIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, MediaActionReceiver::class.java).apply {
            this.action = action
            // Explicit package so Android 12+ enforced explicit receivers won't drop it.
            setPackage(context.packageName)
        }
        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
