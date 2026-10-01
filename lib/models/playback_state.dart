/// لقطة لحظية لحالة مشغل الصوت تأتي عبر EventChannel.
class PlaybackSnapshot {
  final bool playing;
  final int positionMs;
  final int durationMs;
  final int bufferedPositionMs;
  final int currentIndex;
  final Map<dynamic, dynamic>? track;
  final int repeatMode; // 0=off, 1=one, 2=all
  final bool shuffleMode;
  final bool favorite;

  const PlaybackSnapshot({
    required this.playing,
    required this.positionMs,
    required this.durationMs,
    required this.bufferedPositionMs,
    required this.currentIndex,
    required this.track,
    required this.repeatMode,
    required this.shuffleMode,
    required this.favorite,
  });

  static const empty = PlaybackSnapshot(
    playing: false,
    positionMs: 0,
    durationMs: 0,
    bufferedPositionMs: 0,
    currentIndex: -1,
    track: null,
    repeatMode: 0,
    shuffleMode: false,
    favorite: false,
  );

  factory PlaybackSnapshot.fromEvent(Map<dynamic, dynamic> ev) {
    return PlaybackSnapshot(
      playing: ev['playing'] == true,
      positionMs: (ev['positionMs'] ?? 0) is int
          ? ev['positionMs'] as int
          : int.tryParse(ev['positionMs'].toString()) ?? 0,
      durationMs: (ev['durationMs'] ?? 0) is int
          ? ev['durationMs'] as int
          : int.tryParse(ev['durationMs'].toString()) ?? 0,
      bufferedPositionMs: (ev['bufferedPositionMs'] ?? 0) is int
          ? ev['bufferedPositionMs'] as int
          : int.tryParse(ev['bufferedPositionMs'].toString()) ?? 0,
      currentIndex: (ev['currentIndex'] ?? -1) is int
          ? ev['currentIndex'] as int
          : int.tryParse(ev['currentIndex'].toString()) ?? -1,
      track: ev['track'] is Map ? ev['track'] as Map : null,
      repeatMode: (ev['repeatMode'] ?? 0) is int
          ? ev['repeatMode'] as int
          : int.tryParse(ev['repeatMode'].toString()) ?? 0,
      shuffleMode: ev['shuffleMode'] == true,
      favorite: ev['favorite'] == true,
    );
  }

  String? get currentTrackId => track?['id']?.toString();
  String? get currentTitle => track?['title']?.toString();
  String? get currentArtist => track?['artist']?.toString();
  String? get currentAlbumArt => track?['albumArtUri']?.toString();
}
