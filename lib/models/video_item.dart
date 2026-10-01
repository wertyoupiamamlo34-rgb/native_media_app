/// نموذج بيانات لفيديو يأتي من الـ MediaStore الأصلي.
class VideoItem {
  final String id;
  final String uri;
  final String title;
  final String displayName;
  final int duration; // milliseconds
  final int size; // bytes
  final int dateAdded; // seconds since epoch
  final String? path;
  final String? thumbnailUri;

  const VideoItem({
    required this.id,
    required this.uri,
    required this.title,
    required this.displayName,
    required this.duration,
    required this.size,
    required this.dateAdded,
    required this.path,
    required this.thumbnailUri,
  });

  factory VideoItem.fromMap(Map<dynamic, dynamic> map) {
    return VideoItem(
      id: (map['id'] ?? '').toString(),
      uri: (map['uri'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      duration: (map['duration'] ?? 0) is int
          ? map['duration'] as int
          : int.tryParse(map['duration'].toString()) ?? 0,
      size: (map['size'] ?? 0) is int
          ? map['size'] as int
          : int.tryParse(map['size'].toString()) ?? 0,
      dateAdded: (map['dateAdded'] ?? 0) is int
          ? map['dateAdded'] as int
          : int.tryParse(map['dateAdded'].toString()) ?? 0,
      path: map['path']?.toString(),
      thumbnailUri: map['thumbnailUri']?.toString(),
    );
  }

  String get displayTitle => title.trim().isEmpty ? displayName : title;
}
