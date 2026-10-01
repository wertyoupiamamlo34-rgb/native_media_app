package com.example.native_media_app

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import java.io.File

/**
 * Strategy (offline-only, no network):
 *   1. Local .lrc file matching the song title in MediaStore.
 *   2. Local .lrc file sitting next to the audio file (same folder, same base name).
 *   3. Embedded ID3v2 USLT frame inside the MP3.
 *   4. Empty list (UI shows "No lyrics available").
 *
 * In-memory LRU-ish cache keyed by trackId.
 */
class LyricsRepository(private val context: Context) {
    private val tag = "LyricsRepository"
    private val lyricExtensions = setOf("lrc", "txt", "srt")

    companion object {
        private val cache = LinkedHashMap<String, List<Map<String, Any>>>(32, 0.75f, true)
        private const val MAX_CACHE = 64
    }

    fun load(trackId: String, title: String, audioUri: String?, audioPath: String?, displayName: String?): List<Map<String, Any>> {
        cache[trackId]?.let { cached ->
            if (cached.isNotEmpty()) {
                Log.d(tag, "cache hit trackId=$trackId lines=${cached.size}")
                return cached
            }
        }

        Log.d(tag, "load start trackId=$trackId title=$title uri=${!audioUri.isNullOrBlank()} path=${!audioPath.isNullOrBlank()}")

        val initialBases = mutableListOf(title, displayName.orEmpty())
        if (!audioPath.isNullOrBlank()) {
            initialBases += File(audioPath).nameWithoutExtension
        }
        if (!audioUri.isNullOrBlank()) {
            initialBases += Uri.parse(audioUri).lastPathSegment.orEmpty().substringBeforeLast('.')
        }

        // 1) External lyric files by song title variants (.lrc/.txt/.srt).
        var lyrics = loadLyricsByBases(initialBases)
        if (lyrics.isNotEmpty()) Log.d(tag, "lyrics found by title lines=${lyrics.size}")

        // 2) External lyric files adjacent to audio file path.
        if (lyrics.isEmpty() && !audioPath.isNullOrBlank()) {
            lyrics = loadSiblingByPath(audioPath, initialBases)
            if (lyrics.isNotEmpty()) Log.d(tag, "lyrics found by sibling path lines=${lyrics.size}")
        }

        // 3) External lyric files by URI/display-name/title variants.
        if (lyrics.isEmpty() && !audioUri.isNullOrBlank()) {
            lyrics = loadSiblingByUri(audioUri, title, displayName)
            if (lyrics.isNotEmpty()) Log.d(tag, "lyrics found by sibling uri lines=${lyrics.size}")
        }

        // 4) Embedded ID3 lyrics (USLT/SYLT + v2.2 ULT/SLT).
        if (lyrics.isEmpty()) {
            val embedded = loadEmbeddedLyrics(audioUri, audioPath)
            if (!embedded.isNullOrBlank()) {
                lyrics = parseLyricsText(embedded)
                if (lyrics.isNotEmpty()) Log.d(tag, "lyrics found embedded lines=${lyrics.size}")
            }
        }

        if (lyrics.isEmpty()) {
            Log.d(tag, "lyrics not found trackId=$trackId")
        }

        putCache(trackId, lyrics)
        return lyrics
    }

    private fun parseLyricsText(raw: String): List<Map<String, Any>> {
        if (raw.isBlank()) return emptyList()

        // Handle SRT-style subtitles as unsynced plain lyrics lines.
        if (raw.contains("-->")) {
            val srtLines = raw.lineSequence()
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .filterNot { it.matches(Regex("""^\d+$""")) }
                .filterNot { it.contains("-->") }
                .toList()
            if (srtLines.isNotEmpty()) {
                return srtLines.map { line -> mapOf("timeMs" to -1, "text" to line) }
            }
        }

        var parsed = LyricsParser.parseLrc(raw)
        if (parsed.isEmpty()) parsed = LyricsParser.fromPlain(raw)
        return parsed
    }

    private fun loadEmbeddedLyrics(audioUri: String?, audioPath: String?): String? {
        return when {
            !audioUri.isNullOrBlank() -> Id3LyricsExtractor.extract(context, Uri.parse(audioUri))
            !audioPath.isNullOrBlank() -> Id3LyricsExtractor.extract(context, Uri.fromFile(File(audioPath)))
            else -> null
        }
    }

    private fun normalizeBaseName(value: String): String {
        return value.lowercase()
            .replace(Regex("""[\u064B-\u065F\u0670\u06D6-\u06ED]"""), "") // Arabic diacritics
            .replace(Regex("""[\s_\-\[\](){}]+"""), "")
            .replace(Regex("""[^\p{L}\p{N}]"""), "")
            .trim()
    }

    private fun isNameMatch(fileBaseName: String, rawBases: List<String>): Boolean {
        val fileNorm = normalizeBaseName(fileBaseName)
        if (fileNorm.isBlank()) return false
        val candidateNorms = candidateBaseNames(rawBases).map(::normalizeBaseName).filter { it.isNotBlank() }
        return candidateNorms.any { candidate ->
            fileNorm == candidate || fileNorm.contains(candidate) || candidate.contains(fileNorm)
        }
    }

    private fun similarityScore(fileBaseName: String, rawBases: List<String>): Double {
        val fileNorm = normalizeBaseName(fileBaseName)
        if (fileNorm.isBlank()) return 0.0

        val candidateNorms = candidateBaseNames(rawBases)
            .map(::normalizeBaseName)
            .filter { it.isNotBlank() }
        if (candidateNorms.isEmpty()) return 0.0

        var best = 0.0
        for (candidate in candidateNorms) {
            if (candidate == fileNorm) return 1.0

            val minLen = minOf(candidate.length, fileNorm.length)
            if (minLen == 0) continue

            var commonPrefix = 0
            while (commonPrefix < minLen && candidate[commonPrefix] == fileNorm[commonPrefix]) {
                commonPrefix++
            }

            val containsBoost = when {
                candidate.contains(fileNorm) || fileNorm.contains(candidate) -> 0.35
                else -> 0.0
            }

            val base = commonPrefix.toDouble() / minLen.toDouble()
            val score = (base + containsBoost).coerceAtMost(1.0)
            if (score > best) best = score
        }

        return best
    }

    private fun candidateBaseNames(rawBases: List<String>): List<String> {
        val candidates = linkedSetOf<String>()
        rawBases.forEach { raw ->
            val base = raw.substringBeforeLast('.').trim()
            if (base.isBlank()) return@forEach

            val variants = linkedSetOf<String>()
            variants += base

            // Common metadata decorations in Arabic track titles.
            variants += base.replace(Regex("""\[[^\]]*]"""), " ").trim()
            variants += base.replace(Regex("""\([^)]*\)"""), " ").trim()
            variants += base.replace(Regex("""\b(أداء|اداء|by|feat\.?|ft\.?)\b.*$""", RegexOption.IGNORE_CASE), " ").trim()

            variants.toList().forEach { v ->
                val cleaned = v.replace(Regex("""\s+"""), " ").trim()
                if (cleaned.isBlank()) return@forEach
                candidates += cleaned
                candidates += cleaned.replace('_', ' ')
                candidates += cleaned.replace('-', ' ')
                candidates += cleaned.replace(' ', '_')
                candidates += cleaned.replace(' ', '-')
            }
        }
        return candidates.filter { it.isNotBlank() }
    }

    private fun loadLyricsByBases(rawBases: List<String>): List<Map<String, Any>> {
        val bases = candidateBaseNames(rawBases)
        if (bases.isEmpty()) return emptyList()

        val resolver = context.contentResolver
        val filesUri = MediaStore.Files.getContentUri("external")

        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME
        )

        val args = mutableListOf<String>()
        bases.forEach { base ->
            lyricExtensions.forEach { ext ->
                args += "%$base%.$ext"
            }
        }
        if (args.isEmpty()) return emptyList()
        val selection = args.joinToString(" OR ") {
            "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
        }

        return runCatching {
            resolver.query(filesUri, projection, selection, args.toTypedArray(), null)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    val fileName = cursor.getString(nameCol).orEmpty()
                    val isGoodMatch = isNameMatch(fileName.substringBeforeLast('.'), bases)
                    if (!isGoodMatch) continue

                    val id = cursor.getLong(idCol)
                    val uri = ContentUris.withAppendedId(filesUri, id)
                    resolver.openInputStream(uri)?.bufferedReader()?.use { reader ->
                        val parsed = parseLyricsText(reader.readText())
                        if (parsed.isNotEmpty()) {
                            return@runCatching parsed
                        }
                    }
                }
                emptyList<Map<String, Any>>()
            } ?: emptyList()
        }.getOrDefault(emptyList())
    }

    private fun loadSiblingByPath(audioPath: String, rawBases: List<String>): List<Map<String, Any>> {
        val audioFile = File(audioPath)
        val parent = audioFile.parentFile ?: return emptyList()
        if (!parent.exists() || !parent.isDirectory) return emptyList()

        val candidates = mutableListOf(audioFile.nameWithoutExtension)
        candidates.addAll(rawBases)

        val lyricFiles = parent.listFiles()
            ?.filter { file ->
                file.isFile && lyricExtensions.contains(file.extension.lowercase())
            }
            .orEmpty()
        if (lyricFiles.isEmpty()) return emptyList()

        Log.d(tag, "sibling path scan dir=${parent.path} lyricFiles=${lyricFiles.size}")

        val directMatch = lyricFiles.firstOrNull { file ->
            isNameMatch(file.nameWithoutExtension, candidates)
        }

        val lyricFile = if (directMatch != null) {
            directMatch
        } else {
            val ranked = lyricFiles
                .map { file -> file to similarityScore(file.nameWithoutExtension, candidates) }
                .sortedByDescending { it.second }

            val best = ranked.firstOrNull()
            if (best != null && best.second >= 0.40) {
                Log.d(tag, "sibling ranked match file=${best.first.name} score=${best.second}")
                best.first
            } else {
                lyricFiles.singleOrNull()
            }
        } ?: return emptyList()

        Log.d(tag, "sibling selected file=${lyricFile.name}")

        return runCatching {
            parseLyricsText(lyricFile.readText())
        }.getOrDefault(emptyList())
    }

    /**
     * Some audio URIs are content://... so a direct file-sibling lookup isn't possible
     * via path. We approximate by querying MediaStore for a .lrc whose DISPLAY_NAME
     * starts with the song's base name.
     */
    private fun loadSiblingByUri(audioUri: String, title: String, displayName: String?): List<Map<String, Any>> {
        val resolver = context.contentResolver
        val uri = Uri.parse(audioUri)

        var relativePath = ""

        val fromDisplayName = runCatching {
            resolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.RELATIVE_PATH),
                null,
                null,
                null
            )
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                        val relIdx = cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                        if (relIdx >= 0) {
                            relativePath = cursor.getString(relIdx).orEmpty()
                        }
                        if (idx >= 0) {
                            cursor.getString(idx)?.substringBeforeLast('.')?.trim().orEmpty()
                        } else {
                            ""
                        }
                    } else {
                        ""
                    }
                }.orEmpty()
        }.getOrDefault("")

        val fromUriName = uri.lastPathSegment
            ?.substringAfterLast('/')
            ?.substringBeforeLast('.')
            ?.trim()
            .orEmpty()

        val bases = listOf(
            fromDisplayName,
            fromUriName,
            displayName.orEmpty(),
            title,
        )

        if (relativePath.isNotBlank()) {
            val inSameFolder = loadLyricsByRelativePath(relativePath, bases)
            if (inSameFolder.isNotEmpty()) return inSameFolder
        }

        return loadLyricsByBases(
            bases,
        )
    }

    private fun loadLyricsByRelativePath(relativePath: String, rawBases: List<String>): List<Map<String, Any>> {
        val bases = candidateBaseNames(rawBases)
        if (bases.isEmpty()) return emptyList()

        val resolver = context.contentResolver
        val filesUri = MediaStore.Files.getContentUri("external")
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.RELATIVE_PATH,
        )

        val extSelection = lyricExtensions.joinToString(" OR ") {
            "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?"
        }
        val selection =
            "${MediaStore.Files.FileColumns.RELATIVE_PATH}=? AND ($extSelection)"
        val args = mutableListOf(relativePath)
        lyricExtensions.forEach { ext -> args += "%.${ext}" }

        return runCatching {
            resolver.query(filesUri, projection, selection, args.toTypedArray(), null)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    val fileName = cursor.getString(nameCol).orEmpty()
                    val isGoodMatch = isNameMatch(fileName.substringBeforeLast('.'), bases)
                    if (!isGoodMatch) continue

                    val id = cursor.getLong(idCol)
                    val lyricUri = ContentUris.withAppendedId(filesUri, id)
                    resolver.openInputStream(lyricUri)?.bufferedReader()?.use { reader ->
                        val parsed = parseLyricsText(reader.readText())
                        if (parsed.isNotEmpty()) {
                            return@runCatching parsed
                        }
                    }
                }
                emptyList<Map<String, Any>>()
            } ?: emptyList()
        }.getOrDefault(emptyList())
    }

    private fun putCache(key: String, value: List<Map<String, Any>>) {
        if (value.isEmpty()) return
        cache[key] = value
        if (cache.size > MAX_CACHE) {
            val iterator = cache.entries.iterator()
            if (iterator.hasNext()) {
                iterator.next(); iterator.remove()
            }
        }
    }

    fun clearCache() { cache.clear() }
}
