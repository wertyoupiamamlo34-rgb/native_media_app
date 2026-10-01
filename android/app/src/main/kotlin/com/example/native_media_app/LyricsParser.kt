package com.example.native_media_app

/**
 * Parses LRC (synced) and plain lyrics into a unified shape:
 *   [{ "timeMs": Int, "text": String }, ...]
 * Plain text lines get timeMs = -1 so the UI can render them unsynced.
 */
object LyricsParser {

    // Supports [mm:ss], [mm:ss.x], [mm:ss.xx], [mm:ss.xxx]
    private val lineRegex =
        Regex("""\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?](.*)""")

    fun parseLrc(raw: String): List<Map<String, Any>> {
        if (raw.isBlank()) return emptyList()

        val synced = mutableListOf<Map<String, Any>>()
        val plain = mutableListOf<String>()
        var foundAnyTag = false

        raw.lineSequence().forEach { rawLine ->
            val line = rawLine.trim()
            if (line.isEmpty()) return@forEach

            // A single line may contain multiple timestamps e.g. [00:12][00:45]text
            val tags = lineRegex.findAll(line).toList()
            if (tags.isEmpty()) {
                plain.add(line)
                return@forEach
            }

            // Extract trailing text (everything after the last tag)
            val lastTagEnd = tags.last().range.last + 1
            val text = line.substring(lastTagEnd).trim()

            tags.forEach { match ->
                foundAnyTag = true
                val minutes = match.groupValues[1].toIntOrNull() ?: 0
                val seconds = match.groupValues[2].toIntOrNull() ?: 0
                val frac = match.groupValues[3]

                val fracMs = when (frac.length) {
                    1 -> frac.toInt() * 100
                    2 -> frac.toInt() * 10
                    3 -> frac.toInt()
                    else -> 0
                }
                val timeMs = (minutes * 60_000) + (seconds * 1_000) + fracMs
                synced.add(mapOf("timeMs" to timeMs, "text" to text))
            }
        }

        return if (foundAnyTag) {
            synced.sortedBy { it["timeMs"] as Int }
        } else {
            plain.map { mapOf("timeMs" to -1, "text" to it) }
        }
    }

    /** Wraps a plain string as the unified shape. */
    fun fromPlain(text: String): List<Map<String, Any>> {
        if (text.isBlank()) return emptyList()
        return text.split('\n')
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .map { mapOf("timeMs" to -1, "text" to it) }
    }
}
