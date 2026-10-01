package com.example.native_media_app

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

/**
 * Generates and manages video thumbnails using MediaMetadataRetriever.
 */
object ThumbnailGenerator {

    private const val THUMBNAIL_SIZE = 256 // pixels
    private const val THUMBNAIL_QUALITY = 85

    /**
     * Generate a thumbnail for a video at the specified path or URI.
     * Returns a File path to the saved thumbnail, or null if generation fails.
     */
    suspend fun generateThumbnail(context: Context, videoPath: String): String? =
        withContext(Dispatchers.IO) {
            try {
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(videoPath)

                // Get first frame at 1 second
                val bitmap = retriever.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST)
                retriever.release()

                if (bitmap != null) {
                    val thumbnailPath = saveThumbnail(context, bitmap, videoPath)
                    bitmap.recycle()
                    return@withContext thumbnailPath
                }
            } catch (e: Exception) {
                Log.e("ThumbnailGenerator", "Error generating thumbnail for $videoPath: ${e.message}")
            }
            null
        }

    /**
     * Generate a thumbnail at a specific time (in milliseconds).
     */
    suspend fun generateThumbnailAtTime(
        context: Context,
        videoPath: String,
        timeMs: Long
    ): String? = withContext(Dispatchers.IO) {
        try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(videoPath)

            val bitmap = retriever.getFrameAtTime(timeMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
            retriever.release()

            if (bitmap != null) {
                val thumbnailPath = saveThumbnail(context, bitmap, videoPath)
                bitmap.recycle()
                return@withContext thumbnailPath
            }
        } catch (e: Exception) {
            Log.e("ThumbnailGenerator", "Error generating thumbnail at $timeMs ms: ${e.message}")
        }
        null
    }

    /**
     * Get video metadata without generating thumbnail.
     */
    suspend fun getVideoMetadata(videoPath: String): Map<String, String> =
        withContext(Dispatchers.IO) {
            val metadata = mutableMapOf<String, String>()
            try {
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(videoPath)

                // Extract common metadata
                metadata["duration"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION) ?: "0"
                metadata["width"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH) ?: "0"
                metadata["height"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT) ?: "0"
                metadata["rotation"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: "0"
                metadata["bitrate"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE) ?: "0"
                metadata["framerate"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE) ?: "0"
                metadata["mimeType"] = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) ?: ""

                retriever.release()
            } catch (e: Exception) {
                Log.e("ThumbnailGenerator", "Error getting metadata for $videoPath: ${e.message}")
            }
            metadata
        }

    /**
     * Clear cached thumbnails for a specific video.
     */
    fun clearThumbnail(context: Context, videoPath: String) {
        try {
            val thumbnailFile = getThumbnailFile(context, videoPath)
            if (thumbnailFile.exists()) {
                thumbnailFile.delete()
            }
        } catch (e: Exception) {
            Log.w("ThumbnailGenerator", "Error clearing thumbnail: ${e.message}")
        }
    }

    /**
     * Check if a thumbnail exists for a video.
     */
    fun thumbnailExists(context: Context, videoPath: String): Boolean {
        return getThumbnailFile(context, videoPath).exists()
    }

    /**
     * Get the path to a cached thumbnail.
     */
    fun getThumbnailPath(context: Context, videoPath: String): String {
        return getThumbnailFile(context, videoPath).absolutePath
    }

    private fun saveThumbnail(context: Context, bitmap: Bitmap, videoPath: String): String? {
        return try {
            val thumbnailFile = getThumbnailFile(context, videoPath)
            thumbnailFile.parentFile?.mkdirs()

            FileOutputStream(thumbnailFile).use { fos ->
                val scaledBitmap = scaleBitmap(bitmap, THUMBNAIL_SIZE)
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, THUMBNAIL_QUALITY, fos)
                if (scaledBitmap != bitmap) {
                    scaledBitmap.recycle()
                }
            }

            thumbnailFile.absolutePath
        } catch (e: Exception) {
            Log.e("ThumbnailGenerator", "Error saving thumbnail: ${e.message}")
            null
        }
    }

    private fun getThumbnailFile(context: Context, videoPath: String): File {
        val cacheDir = File(context.cacheDir, "video_thumbnails")
        val fileName = videoPath.hashCode().toString() + ".jpg"
        return File(cacheDir, fileName)
    }

    private fun scaleBitmap(bitmap: Bitmap, targetSize: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val aspectRatio = width.toFloat() / height.toFloat()

        val newWidth: Int
        val newHeight: Int

        if (width > height) {
            newWidth = targetSize
            newHeight = (targetSize / aspectRatio).toInt()
        } else {
            newHeight = targetSize
            newWidth = (targetSize * aspectRatio).toInt()
        }

        return if (newWidth == width && newHeight == height) {
            bitmap
        } else {
            Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
        }
    }

    /**
     * Clear all cached thumbnails.
     */
    fun clearAllThumbnails(context: Context) {
        try {
            val cacheDir = File(context.cacheDir, "video_thumbnails")
            if (cacheDir.exists()) {
                cacheDir.deleteRecursively()
            }
        } catch (e: Exception) {
            Log.e("ThumbnailGenerator", "Error clearing all thumbnails: ${e.message}")
        }
    }
}
