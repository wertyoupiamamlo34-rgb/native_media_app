import 'package:shared_preferences/shared_preferences.dart';

class PlaylistStorage {
  static const customPlaylistsKey = 'custom_playlist_names_v1';

  static String playlistTracksKey(String name) {
    return 'custom_playlist_tracks_${Uri.encodeComponent(name)}';
  }

  static Future<List<String>> loadPlaylistNames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(customPlaylistsKey) ?? const <String>[];
  }

  static Future<Map<String, List<String>>> loadAllPlaylistTrackIds() async {
    final prefs = await SharedPreferences.getInstance();
    final names = await loadPlaylistNames();
    final result = <String, List<String>>{};
    for (final name in names) {
      result[name] =
          prefs.getStringList(playlistTracksKey(name)) ?? const <String>[];
    }
    return result;
  }

  static Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final names =
        (prefs.getStringList(customPlaylistsKey) ?? const <String>[]).toSet();
    names.add(trimmed);
    await prefs.setStringList(
        customPlaylistsKey, names.toList(growable: false));
    await prefs.setStringList(playlistTracksKey(trimmed),
        prefs.getStringList(playlistTracksKey(trimmed)) ?? const <String>[]);
  }

  static Future<void> addTrackToPlaylist(
      String playlistName, String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = playlistTracksKey(playlistName);
    final ids = (prefs.getStringList(key) ?? const <String>[]).toSet();
    ids.add(trackId);
    await prefs.setStringList(key, ids.toList(growable: false));
  }
}
