package com.example.native_media_app

import android.content.Context
import android.database.Cursor
import android.provider.MediaStore
import android.util.Log
import androidx.core.content.ContentProviderCompat.requireContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Scans device storage for video files using MediaStore.
 */
object VideoScanner {

    data class VideoInfo(
        val id: String,
        val uri: String,
        val title: String,
        val duration: Long, // milliseconds
        val size: Long, // bytes
        val dateAdded: Long, // unix timestamp
        val path: String? = null,
        val width: Int = 0,
        val height: Int = 0,
        val mimeType: String? = null
    )

    /**
     * Scan for all video files on the device.
     * Returns list of VideoInfo objects.
     */
    suspend fun scanVideos(context: Context): List<VideoInfo> = withContext(Dispatchers.IO) {
        val videos = mutableListOf<VideoInfo>()
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.MIME_TYPE
        )

        val sortOrder = "${MediaStore.Video.Media.DATE_ADDED} DESC"
        val selection = "${MediaStore.Video.Media.SIZE} > 0"

        try {
            context.contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                null,
                sortOrder
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    try {
                        val id = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                        val path = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA))
                        val title = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME))
                        val duration = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION))
                        val size = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE))
                        val dateAdded = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED))
                        val width = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH))
                        val height = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT))
                        val mimeType = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.MIME_TYPE))

                        val uri = "content://media/external/video/media/$id"

                        videos.add(
                            VideoInfo(
                                id = id,
                                uri = uri,
                                title = title,
                                duration = duration,
                                size = size,
                                dateAdded = dateAdded,
                                path = path,
                                width = width,
                                height = height,
                                mimeType = mimeType
                            )
                        )
                    } catch (e: Exception) {
                        Log.w("VideoScanner", "Error reading video entry: ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("VideoScanner", "Error scanning videos: ${e.message}")
        }

        videos
    }

    /**
     * Scan videos in a specific directory.
     */
    suspend fun scanVideosInDirectory(context: Context, directory: String): List<VideoInfo> = withContext(Dispatchers.IO) {
        val videos = mutableListOf<VideoInfo>()
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.MIME_TYPE
        )

        val sortOrder = "${MediaStore.Video.Media.DATE_ADDED} DESC"
        val selection = "${MediaStore.Video.Media.DATA} LIKE ? AND ${MediaStore.Video.Media.SIZE} > 0"
        val selectionArgs = arrayOf("$directory%")

        try {
            context.contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    try {
                        val id = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                        val path = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA))
                        val title = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME))
                        val duration = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION))
                        val size = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE))
                        val dateAdded = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED))
                        val width = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH))
                        val height = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT))
                        val mimeType = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.MIME_TYPE))

                        val uri = "content://media/external/video/media/$id"

                        videos.add(
                            VideoInfo(
                                id = id,
                                uri = uri,
                                title = title,
                                duration = duration,
                                size = size,
                                dateAdded = dateAdded,
                                path = path,
                                width = width,
                                height = height,
                                mimeType = mimeType
                            )
                        )
                    } catch (e: Exception) {
                        Log.w("VideoScanner", "Error reading video entry: ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("VideoScanner", "Error scanning videos in directory: ${e.message}")
        }

        videos
    }

    /**
     * Get a single video by ID.
     */
    suspend fun getVideoById(context: Context, videoId: String): VideoInfo? = withContext(Dispatchers.IO) {
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.MIME_TYPE
        )

        val selection = "${MediaStore.Video.Media._ID} = ?"
        val selectionArgs = arrayOf(videoId)

        try {
            context.contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                    val path = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA))
                    val title = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME))
                    val duration = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION))
                    val size = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE))
                    val dateAdded = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED))
                    val width = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH))
                    val height = cursor.getInt(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT))
                    val mimeType = cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.MIME_TYPE))

                    val uri = "content://media/external/video/media/$id"

                    return@withContext VideoInfo(
                        id = id,
                        uri = uri,
                        title = title,
                        duration = duration,
                        size = size,
                        dateAdded = dateAdded,
                        path = path,
                        width = width,
                        height = height,
                        mimeType = mimeType
                    )
                }
            }
        } catch (e: Exception) {
            Log.e("VideoScanner", "Error getting video by ID: ${e.message}")
        }

        null
    }
}
