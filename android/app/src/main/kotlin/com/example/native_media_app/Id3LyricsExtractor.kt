package com.example.native_media_app

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.InputStream

/**
 * Extracts USLT (Unsynchronized Lyrics) frame from an MP3's ID3v2 tag.
 * Pure Kotlin, no external libraries. Returns null if not found or on parse failure.
 *
 * ID3v2 spec (simplified for USLT):
 *   Header: "ID3" + version(2) + flags(1) + size(4, synchsafe) = 10 bytes
 *   Frame : id(4) + size(4) + flags(2) + payload
 *   USLT payload: encoding(1) + language(3) + descriptor(text + terminator) + lyrics(text)
 */
object Id3LyricsExtractor {

    fun extract(context: Context, fileUri: Uri): String? {
        return try {
            val stream = when (fileUri.scheme?.lowercase()) {
                "file" -> {
                    val path = fileUri.path
                    if (path.isNullOrBlank()) null else File(path).inputStream()
                }
                else -> context.contentResolver.openInputStream(fileUri)
            }
            stream?.use { readUslt(it) }
        } catch (_: Exception) {
            null
        }
    }

    private fun readUslt(stream: InputStream): String? {
        val header = ByteArray(10)
        if (stream.read(header) != 10) return null
        if (header[0] != 'I'.code.toByte() ||
            header[1] != 'D'.code.toByte() ||
            header[2] != '3'.code.toByte()
        ) return null

        val majorVersion = header[3].toInt() and 0xFF
        val tagSize = synchsafeToInt(header, 6)
        if (tagSize <= 0 || tagSize > 50_000_000) return null

        val tagBody = ByteArray(tagSize)
        var read = 0
        while (read < tagSize) {
            val n = stream.read(tagBody, read, tagSize - read)
            if (n <= 0) break
            read += n
        }
        if (read <= 0) return null

        var i = 0
        if (majorVersion == 2) {
            while (i + 6 <= read) {
                val id = String(tagBody, i, 3, Charsets.ISO_8859_1)
                if (id[0] == '\u0000') break
                val frameSize = ((tagBody[i + 3].toInt() and 0xFF) shl 16) or
                    ((tagBody[i + 4].toInt() and 0xFF) shl 8) or
                    (tagBody[i + 5].toInt() and 0xFF)
                val payloadStart = i + 6
                val end = payloadStart + frameSize
                if (frameSize <= 0 || end > read) break

                val extracted = extractLyricsFromFrame(tagBody, id, payloadStart, end)
                if (!extracted.isNullOrBlank()) return extracted
                i = end
            }
            return null
        }

        while (i + 10 <= read) {
            val id = String(tagBody, i, 4, Charsets.ISO_8859_1)
            if (id[0] == '\u0000') break
            val frameSize = if (majorVersion >= 4) {
                synchsafeToInt(tagBody, i + 4)
            } else {
                ((tagBody[i + 4].toInt() and 0xFF) shl 24) or
                    ((tagBody[i + 5].toInt() and 0xFF) shl 16) or
                    ((tagBody[i + 6].toInt() and 0xFF) shl 8) or
                    (tagBody[i + 7].toInt() and 0xFF)
            }
            val payloadStart = i + 10
            val end = payloadStart + frameSize
            if (frameSize <= 0 || end > read) break

            val extracted = extractLyricsFromFrame(tagBody, id, payloadStart, end)
            if (!extracted.isNullOrBlank()) return extracted
            i = end
        }
        return null
    }

    private fun extractLyricsFromFrame(
        bytes: ByteArray,
        id: String,
        payloadStart: Int,
        end: Int
    ): String? {
        if (id.equals("USLT", ignoreCase = true) || id.equals("ULT", ignoreCase = true)) {
            val encoding = bytes[payloadStart].toInt() and 0xFF
            var p = payloadStart + 1 + 3 // encoding + language

            val charset = when (encoding) {
                0 -> Charsets.ISO_8859_1
                1 -> Charsets.UTF_16
                2 -> Charsets.UTF_16BE
                3 -> Charsets.UTF_8
                else -> Charsets.UTF_8
            }

            p = skipTerminator(bytes, p, end, encoding)
            if (p >= end) return null
            val lyricsBytes = bytes.copyOfRange(p, end)
            val text = String(lyricsBytes, charset)
                .trimEnd('\u0000', '\uFEFF', ' ', '\n', '\r')
            return text.ifBlank { null }
        }

        if (id.equals("SYLT", ignoreCase = true) || id.equals("SLT", ignoreCase = true)) {
            val encoding = bytes[payloadStart].toInt() and 0xFF
            var p = payloadStart + 1 + 3 + 1 + 1 // enc + lang + timeFormat + contentType

            val charset = when (encoding) {
                0 -> Charsets.ISO_8859_1
                1 -> Charsets.UTF_16
                2 -> Charsets.UTF_16BE
                3 -> Charsets.UTF_8
                else -> Charsets.UTF_8
            }

            p = skipTerminator(bytes, p, end, encoding)
            if (p >= end) return null
            val raw = String(bytes.copyOfRange(p, end), charset)
            val cleaned = raw.filter { ch -> ch.code >= 32 || ch == '\n' || ch == '\r' }
                .trimEnd('\u0000', '\uFEFF', ' ', '\n', '\r')
            return cleaned.ifBlank { null }
        }

        return null
    }

    private fun synchsafeToInt(bytes: ByteArray, offset: Int): Int {
        return ((bytes[offset].toInt() and 0x7F) shl 21) or
            ((bytes[offset + 1].toInt() and 0x7F) shl 14) or
            ((bytes[offset + 2].toInt() and 0x7F) shl 7) or
            (bytes[offset + 3].toInt() and 0x7F)
    }

    private fun skipTerminator(bytes: ByteArray, start: Int, end: Int, encoding: Int): Int {
        var p = start
        if (encoding == 1 || encoding == 2) {
            // UTF-16 terminator: 0x00 0x00 aligned
            while (p + 1 < end) {
                if (bytes[p].toInt() == 0 && bytes[p + 1].toInt() == 0) {
                    return p + 2
                }
                p += 2
            }
        } else {
            while (p < end) {
                if (bytes[p].toInt() == 0) return p + 1
                p++
            }
        }
        return p
    }
}
