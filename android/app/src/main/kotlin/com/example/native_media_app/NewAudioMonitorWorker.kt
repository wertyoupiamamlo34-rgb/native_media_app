package com.example.native_media_app

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class NewAudioMonitorWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return try {
            if (!NewAudioNotificationHelper.isNotificationSyncEnabled(applicationContext)) {
                return Result.success()
            }
            val tracks = MediaStoreRepo(applicationContext).getAllAudio(forceRefresh = true)
            NewAudioNotificationHelper.syncAndNotifyIfNeeded(applicationContext, tracks)
            Result.success()
        } catch (_: Throwable) {
            Result.retry()
        }
    }
}