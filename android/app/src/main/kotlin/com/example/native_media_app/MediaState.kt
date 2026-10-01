package com.example.native_media_app

/**
 * In-memory mirror of persisted state.
 * Hydrated from MediaPreferences at service start.
 */
object MediaState {

    // Repeat constants (match ExoPlayer values)
    const val REPEAT_OFF = 0
    const val REPEAT_ONE = 1
    const val REPEAT_ALL = 2

    /** Current track favorite flag (for the notification star icon). */
    @Volatile
    var favorite: Boolean = false

    /** Persistent set of favorited media IDs. */
    val favoriteIds: MutableSet<String> = mutableSetOf()

    /** 0=off, 1=one, 2=all. */
    @Volatile
    var repeatMode: Int = REPEAT_OFF

    @Volatile
    var shuffleMode: Boolean = false

    /** Last known active media id (used to compute `favorite` flag). */
    @Volatile
    var currentMediaId: String = ""

    fun isFavorite(id: String): Boolean = favoriteIds.contains(id)

    fun toggleFavorite(id: String): Boolean {
        val now = if (favoriteIds.contains(id)) {
            favoriteIds.remove(id); false
        } else {
            favoriteIds.add(id); true
        }
        if (id == currentMediaId) favorite = now
        return now
    }

    fun refreshFavoriteFlag() {
        favorite = currentMediaId.isNotEmpty() && favoriteIds.contains(currentMediaId)
    }
}
