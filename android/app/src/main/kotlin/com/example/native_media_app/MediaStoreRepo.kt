package com.example.native_media_app

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * Reads device audio/video from MediaStore.
 * - Adds albumArtUri (per-track) via the audio album-art content provider.
 * - Filters out short audio tracks (ringtones, notifications).
 * - Queries every indexed external storage volume, including SD cards when present.
 * - Exposes raw file path (DATA) or relativePath when Android hides DATA.
 */
class MediaStoreRepo(private val context: Context) {

    companion object {
        private const val MIN_DURATION_MS = 30_000L
        private const val AUDIO_CACHE = "library_audio_cache.json"
        private const val VIDEO_CACHE = "library_video_cache.json"
        private val ALBUM_ART_BASE: Uri = Uri.parse("content://media/external/audio/albumart")
    }

    private fun audioCollectionUris(): List<Uri> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return listOf(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI)
        }

        return MediaStore.getExternalVolumeNames(context)
            .plus(MediaStore.VOLUME_EXTERNAL)
            .distinct()
            .map { volume -> MediaStore.Audio.Media.getContentUri(volume) }
    }

    private fun videoCollectionUris(): List<Uri> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return listOf(MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
        }

        return MediaStore.getExternalVolumeNames(context)
            .plus(MediaStore.VOLUME_EXTERNAL)
            .distinct()
            .map { volume -> MediaStore.Video.Media.getContentUri(volume) }
    }

    fun getAllAudio(forceRefresh: Boolean = false): List<Map<String, Any?>> {
        val cacheFile = File(context.cacheDir, AUDIO_CACHE)
        if (!forceRefresh) {
            readCache(cacheFile)?.let { return it }
        }

        val list = queryAudioItems()
        writeCache(cacheFile, list)
        return list
    }

    private fun queryAudioItems(): List<Map<String, Any?>> {
        val resolver = context.contentResolver
        val list = mutableListOf<Map<String, Any?>>()

        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.SIZE
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(MediaStore.Audio.Media.RELATIVE_PATH)
            }
        }.toTypedArray()

        val selection = "${MediaStore.Audio.Media.IS_MUSIC}=1 AND " +
            "${MediaStore.Audio.Media.DURATION}>=?"
        val args = arrayOf(MIN_DURATION_MS.toString())

        audioCollectionUris().forEach { collectionUri ->
            resolver.query(
                collectionUri,
                projection,
                selection,
                args,
                "${MediaStore.Audio.Media.DATE_ADDED} DESC"
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                val relativePathCol = cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)
                val dateAddedCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val uri = ContentUris.withAppendedId(collectionUri, id)
                    val path = if (dataCol >= 0) cursor.getString(dataCol) else null
                    val relativePath = if (relativePathCol >= 0) {
                        cursor.getString(relativePathCol)
                    } else {
                        null
                    }

                    val artCacheFile = File(context.cacheDir, "audio_art_${id}.jpg")
                    list.add(
                        mapOf(
                            "id" to id.toString(),
                            "uri" to uri.toString(),
                            "title" to (cursor.getString(titleCol) ?: ""),
                            "artist" to (cursor.getString(artistCol) ?: ""),
                            "album" to (cursor.getString(albumCol) ?: ""),
                            "albumId" to cursor.getLong(albumIdCol).toString(),
                            "albumArtUri" to if (artCacheFile.exists()) Uri.fromFile(artCacheFile).toString() else "",
                            "duration" to cursor.getLong(durationCol),
                            "displayName" to (cursor.getString(nameCol) ?: ""),
                            "path" to (path ?: relativePath),
                            "relativePath" to relativePath,
                            "dateAdded" to cursor.getLong(dateAddedCol),
                            "size" to cursor.getLong(sizeCol)
                        )
                    )
                }
            }
        }
        return list.distinctBy { itemKey(it) }
    }

    fun getAllVideos(forceRefresh: Boolean = false): List<Map<String, Any?>> {
        val cacheFile = File(context.cacheDir, VIDEO_CACHE)
        if (!forceRefresh) {
            readCache(cacheFile)?.let { return it }
        }

        val list = queryVideoItems()
        writeCache(cacheFile, list)
        return list
    }

    private fun queryVideoItems(): List<Map<String, Any?>> {
        val resolver = context.contentResolver
        val list = mutableListOf<Map<String, Any?>>()

        val projection = mutableListOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
            MediaStore.Video.Media.DATA
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(MediaStore.Video.Media.RELATIVE_PATH)
            }
        }.toTypedArray()

        videoCollectionUris().forEach { collectionUri ->
            resolver.query(
                collectionUri,
                projection,
                null,
                null,
                "${MediaStore.Video.Media.DATE_ADDED} DESC"
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                val dateAddedCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
                val dataCol = cursor.getColumnIndex(MediaStore.Video.Media.DATA)
                val relativePathCol = cursor.getColumnIndex(MediaStore.Video.Media.RELATIVE_PATH)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val uri = ContentUris.withAppendedId(collectionUri, id)
                    val path = if (dataCol >= 0) cursor.getString(dataCol) else null
                    val relativePath = if (relativePathCol >= 0) {
                        cursor.getString(relativePathCol)
                    } else {
                        null
                    }

                    val thumbCacheFile = File(context.cacheDir, "thumb_video_${id}.jpg")
                    list.add(
                        mapOf(
                            "id" to id.toString(),
                            "uri" to uri.toString(),
                            "title" to (cursor.getString(titleCol) ?: ""),
                            "displayName" to (cursor.getString(nameCol) ?: ""),
                            "duration" to cursor.getLong(durationCol),
                            "size" to cursor.getLong(sizeCol),
                            "dateAdded" to cursor.getLong(dateAddedCol),
                            "path" to (path ?: relativePath),
                            "relativePath" to relativePath,
                            "thumbnailUri" to if (thumbCacheFile.exists()) Uri.fromFile(thumbCacheFile).toString() else null
                        )
                    )
                }
            }
        }
        return list.distinctBy { itemKey(it) }
    }

    fun getAudioArtworkUriForTrack(
        trackId: String,
        albumId: String,
        trackUri: String,
        filePath: String?
    ): String {
        val id = trackId.toLongOrNull() ?: -1L
        val uri = Uri.parse(trackUri)
        val cacheFile = File(context.cacheDir, "audio_art_$id.jpg")

        try {
            if (!cacheFile.exists()) {
                val retriever = MediaMetadataRetriever()
                try {
                    if (!filePath.isNullOrEmpty()) {
                        retriever.setDataSource(filePath)
                    } else {
                        retriever.setDataSource(context, uri)
                    }
                    val artBytes = retriever.embeddedPicture
                    if (artBytes != null && artBytes.isNotEmpty()) {
                        FileOutputStream(cacheFile).use { out ->
                            out.write(artBytes)
                            out.flush()
                        }
                    }
                } finally {
                    try { retriever.release() } catch (_: Throwable) {}
                }
            }

            if (!cacheFile.exists() && albumId.isNotEmpty()) {
                val albumArtUri = ContentUris.withAppendedId(ALBUM_ART_BASE, albumId.toLongOrNull() ?: -1L)
                context.contentResolver.openInputStream(albumArtUri)?.use { input ->
                    FileOutputStream(cacheFile).use { out ->
                        input.copyTo(out)
                        out.flush()
                    }
                }
            }

            return if (cacheFile.exists()) {
                Uri.fromFile(cacheFile).toString()
            } else {
                ""
            }
        } catch (t: Throwable) {
            return ""
        }
    }

    fun getVideoThumbnailUriForVideo(
        videoId: String,
        videoUri: String,
        filePath: String?
    ): String? {
        val id = videoId.toLongOrNull() ?: -1L
        val uri = Uri.parse(videoUri)
        val cacheFile = File(context.cacheDir, "thumb_video_$id.jpg")

        return try {
            if (!cacheFile.exists()) {
                val retriever = MediaMetadataRetriever()
                try {
                    if (!filePath.isNullOrEmpty()) {
                        retriever.setDataSource(filePath)
                    } else {
                        retriever.setDataSource(context, uri)
                    }
                    val bmp: Bitmap? = retriever.getFrameAtTime(1_000_000)
                    if (bmp != null) {
                        FileOutputStream(cacheFile).use { out ->
                            bmp.compress(Bitmap.CompressFormat.JPEG, 80, out)
                            out.flush()
                        }
                    }
                } finally {
                    try { retriever.release() } catch (_: Throwable) {}
                }
            }

            if (!cacheFile.exists() && id >= 0) {
                @Suppress("DEPRECATION")
                val bmp = MediaStore.Video.Thumbnails.getThumbnail(
                    context.contentResolver,
                    id,
                    MediaStore.Video.Thumbnails.MINI_KIND,
                    null
                )
                if (bmp != null) {
                    FileOutputStream(cacheFile).use { out ->
                        bmp.compress(Bitmap.CompressFormat.JPEG, 80, out)
                        out.flush()
                    }
                }
            }

            if (cacheFile.exists()) {
                Uri.fromFile(cacheFile).toString()
            } else {
                null
            }
        } catch (t: Throwable) {
            null
        }
    }

    private fun readCache(file: File): List<Map<String, Any?>>? {
        if (!file.exists()) return null
        return try {
            val array = JSONArray(file.readText())
            val list = mutableListOf<Map<String, Any?>>()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val map = mutableMapOf<String, Any?>()
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = obj.opt(key)
                    map[key] = if (value == JSONObject.NULL) null else value
                }
                list.add(map)
            }
            list
        } catch (_: Throwable) {
            null
        }
    }

    private fun writeCache(file: File, items: List<Map<String, Any?>>) {
        try {
            val array = JSONArray()
            items.forEach { item ->
                val obj = JSONObject()
                item.forEach { (key, value) ->
                    if (value == null) {
                        obj.put(key, JSONObject.NULL)
                    } else {
                        obj.put(key, value)
                    }
                }
                array.put(obj)
            }
            file.writeText(array.toString())
        } catch (_: Throwable) {
            // Ignore cache write failures.
        }
    }

    private fun itemKey(item: Map<String, Any?>): String {
        val path = (item["path"] as? String)?.trim()
        if (!path.isNullOrEmpty()) return path.lowercase()

        val relativePath = (item["relativePath"] as? String)?.trim()
        val displayName = (item["displayName"] as? String)?.trim()
        if (!relativePath.isNullOrEmpty()) {
            return if (!displayName.isNullOrEmpty()) {
                "${relativePath.lowercase()}|${displayName.lowercase()}"
            } else {
                relativePath.lowercase()
            }
        }

        val uri = (item["uri"] as? String)?.trim()
        if (!uri.isNullOrEmpty()) return uri.lowercase()

        return (item["id"]?.toString() ?: "").lowercase()
    }
}
