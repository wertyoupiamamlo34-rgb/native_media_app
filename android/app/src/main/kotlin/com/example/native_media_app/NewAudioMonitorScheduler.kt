package com.example.native_media_app

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object NewAudioMonitorScheduler {
    private const val periodicWorkName = "new_audio_monitor_periodic"
    private const val immediateWorkName = "new_audio_monitor_immediate"

    fun schedule(context: Context) {
        val workManager = WorkManager.getInstance(context)

        val immediateWork = OneTimeWorkRequestBuilder<NewAudioMonitorWorker>().build()
        workManager.enqueueUniqueWork(
            immediateWorkName,
            ExistingWorkPolicy.REPLACE,
            immediateWork
        )

        val periodicWork = PeriodicWorkRequestBuilder<NewAudioMonitorWorker>(
            15,
            TimeUnit.MINUTES
        ).build()
        workManager.enqueueUniquePeriodicWork(
            periodicWorkName,
            ExistingPeriodicWorkPolicy.UPDATE,
            periodicWork
        )
    }
}