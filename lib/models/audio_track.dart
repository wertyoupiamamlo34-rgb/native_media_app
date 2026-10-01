/// نموذج بيانات لمسار صوتي يأتي من الـ MediaStore الأصلي.
class AudioTrack {
  final String id;
  final String uri;
  final String title;
  final String artist;
  final String album;
  final String albumId;
  final String albumArtUri;
  final int duration; // milliseconds
  final String displayName;
  final String? path;
  final int dateAdded; // seconds since epoch
  final int size;

  const AudioTrack({
    required this.id,
    required this.uri,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.albumArtUri,
    required this.duration,
    required this.displayName,
    required this.path,
    required this.dateAdded,
    required this.size,
  });

  factory AudioTrack.fromMap(Map<dynamic, dynamic> map) {
    return AudioTrack(
      id: (map['id'] ?? '').toString(),
      uri: (map['uri'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      artist: (map['artist'] ?? '').toString(),
      album: (map['album'] ?? '').toString(),
      albumId: (map['albumId'] ?? '').toString(),
      albumArtUri: (map['albumArtUri'] ?? '').toString(),
      duration: () {
        final raw = map['duration'];
        if (raw is int) return raw;
        return int.tryParse(raw?.toString() ?? '') ?? 0;
      }(),
      displayName: (map['displayName'] ?? '').toString(),
      path: map['path']?.toString(),
      dateAdded: () {
        final raw = map['dateAdded'];
        if (raw is int) return raw;
        return int.tryParse(raw?.toString() ?? '') ?? 0;
      }(),
      size: () {
        final raw = map['size'];
        if (raw is int) return raw;
        return int.tryParse(raw?.toString() ?? '') ?? 0;
      }(),
    );
  }

  /// تحويل العنصر إلى صيغة تفهمها قائمة تشغيل ExoPlayer الأصلية.
  Map<String, dynamic> toQueueItem() => {
        'id': id,
        'uri': uri,
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtUri': albumArtUri,
        'duration': duration,
      };

  String get displayArtist => artist.trim().isEmpty || artist == '<unknown>'
      ? 'فنان غير معروف'
      : artist;

  String get displayTitle => title.trim().isEmpty ? displayName : title;
}
