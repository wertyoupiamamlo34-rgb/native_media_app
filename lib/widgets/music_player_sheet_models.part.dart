part of 'music_player_sheet.dart';

// حاوية بسيطة لقيم الموضع والمدة لضبط شريط التقدم.
class PlaybackSnapshotSafe {
  final int positionMs;
  final int durationMs;

  PlaybackSnapshotSafe(this.positionMs, this.durationMs);
}
