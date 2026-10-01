package com.example.native_media_app

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persistent storage layer.
 * - Last played queue (full list of media items)
 * - Last index + last position (resume on launch)
 * - Favorites (Set<String> of media IDs)
 * - Repeat mode (0=off, 1=one, 2=all)
 * - Shuffle mode (false / true)
 */
object MediaPreferences {

    private const val PREF_NAME = "media_prefs"

    private const val KEY_QUEUE = "last_queue"
    private const val KEY_INDEX = "last_index"
    private const val KEY_POSITION = "last_position_ms"
    private const val KEY_FAVORITES = "favorites_ids"
    private const val KEY_REPEAT = "repeat_mode"
    private const val KEY_SHUFFLE = "shuffle_mode"

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    // ----------------- QUEUE -----------------
    fun saveQueue(context: Context, items: List<Map<String, Any?>>) {
        val array = JSONArray()
        items.forEach { item ->
            val obj = JSONObject()
            item.forEach { (k, v) -> obj.put(k, v ?: JSONObject.NULL) }
            array.put(obj)
        }
        prefs(context).edit().putString(KEY_QUEUE, array.toString()).apply()
    }

    fun loadQueue(context: Context): List<Map<String, Any?>> {
        val raw = prefs(context).getString(KEY_QUEUE, null) ?: return emptyList()
        val result = mutableListOf<Map<String, Any?>>()
        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val map = mutableMapOf<String, Any?>()
                obj.keys().forEach { key ->
                    val value = obj.get(key)
                    map[key] = if (value == JSONObject.NULL) null else value
                }
                result.add(map)
            }
        } catch (_: Exception) { }
        return result
    }

    // ----------------- INDEX / POSITION -----------------
    fun saveIndex(context: Context, index: Int) {
        prefs(context).edit().putInt(KEY_INDEX, index).apply()
    }

    fun loadIndex(context: Context): Int =
        prefs(context).getInt(KEY_INDEX, 0)

    fun savePosition(context: Context, positionMs: Long) {
        prefs(context).edit().putLong(KEY_POSITION, positionMs).apply()
    }

    fun loadPosition(context: Context): Long =
        prefs(context).getLong(KEY_POSITION, 0L)

    // ----------------- FAVORITES -----------------
    fun saveFavorites(context: Context, ids: Set<String>) {
        prefs(context).edit().putStringSet(KEY_FAVORITES, ids).apply()
    }

    fun loadFavorites(context: Context): MutableSet<String> {
        val stored = prefs(context).getStringSet(KEY_FAVORITES, emptySet()) ?: emptySet()
        return stored.toMutableSet()
    }

    // ----------------- REPEAT / SHUFFLE -----------------
    fun saveRepeatMode(context: Context, mode: Int) {
        prefs(context).edit().putInt(KEY_REPEAT, mode).apply()
    }

    fun loadRepeatMode(context: Context): Int =
        prefs(context).getInt(KEY_REPEAT, 0)

    fun saveShuffleMode(context: Context, on: Boolean) {
        prefs(context).edit().putBoolean(KEY_SHUFFLE, on).apply()
    }

    fun loadShuffleMode(context: Context): Boolean =
        prefs(context).getBoolean(KEY_SHUFFLE, false)
}
