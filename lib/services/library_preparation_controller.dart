import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/media_service.dart';
import '../services/permission_service.dart';

// ============================================================
// LIBRARY PREPARATION STATUS
// ============================================================

enum LibraryPreparationStatus {
  scanning,
  artwork,
  lyrics,
  indexing,
  completed,
}

// ============================================================
// LIBRARY PREPARATION STATE (external input)
// ============================================================

class LibraryPreparationState {
  final double progress;
  final LibraryPreparationStatus currentStatus;

  final int songsCount;
  final int artistsCount;
  final int videosCount;
  final int lyricsFilesCount;
  final bool permissionDenied;

  const LibraryPreparationState({
    this.progress = 0.0,
    this.currentStatus = LibraryPreparationStatus.scanning,
    this.songsCount = 0,
    this.artistsCount = 0,
    this.videosCount = 0,
    this.lyricsFilesCount = 0,
    this.permissionDenied = false,
  });

  bool get isCompleted => currentStatus == LibraryPreparationStatus.completed;

  LibraryPreparationState copyWith({
    double? progress,
    LibraryPreparationStatus? currentStatus,
    int? songsCount,
    int? artistsCount,
    int? videosCount,
    int? lyricsFilesCount,
    bool? permissionDenied,
  }) {
    return LibraryPreparationState(
      progress: progress ?? this.progress,
      currentStatus: currentStatus ?? this.currentStatus,
      songsCount: songsCount ?? this.songsCount,
      artistsCount: artistsCount ?? this.artistsCount,
      videosCount: videosCount ?? this.videosCount,
      lyricsFilesCount: lyricsFilesCount ?? this.lyricsFilesCount,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

class LibraryPreparationController {
  LibraryPreparationController({
    LibraryPreparationState initialState = const LibraryPreparationState(),
  }) : state = ValueNotifier(initialState);

  final ValueNotifier<LibraryPreparationState> state;

  bool _running = false;
  bool _disposed = false;

  LibraryPreparationState get current => state.value;

  void _update({
    double? progress,
    LibraryPreparationStatus? status,
    int? songsCount,
    int? videosCount,
    int? lyricsFilesCount,
    int? artistsCount,
    bool? permissionDenied,
  }) {
    if (_disposed) return;

    state.value = state.value.copyWith(
      progress: progress,
      currentStatus: status,
      songsCount: songsCount,
      videosCount: videosCount,
      lyricsFilesCount: lyricsFilesCount,
      artistsCount: artistsCount,
      permissionDenied: permissionDenied,
    );

    debugPrint(
      '[LibraryPreparation] '
      'progress=${(state.value.progress * 100).toInt()}% '
      'songs=${state.value.songsCount} '
      'artists=${state.value.artistsCount} '
      'videos=${state.value.videosCount} '
      'lyrics=${state.value.lyricsFilesCount}',
    );
  }

  Future<void> start() async {
    if (_running || _disposed) return;

    _running = true;

    try {
      // ========================================================
      // INITIALIZE
      // ========================================================

      _update(
        progress: 0.02,
        status: LibraryPreparationStatus.scanning,
      );

      // Ensure we have runtime permission to read device media/storage.
      final hasPerm = await PermissionService.ensureStoragePermission();
      if (!hasPerm) {
        debugPrint(
            '[LibraryPreparation] ⚠️ Storage/media permission not granted — skipping scan');
        // Mark state indicating permission denied so UI can prompt user.
        _update(
          progress: 1.0,
          status: LibraryPreparationStatus.completed,
          songsCount: 0,
          artistsCount: 0,
          lyricsFilesCount: 0,
          permissionDenied: true,
        );
        return;
      } else {
        // clear any previous denial flag
        _update(permissionDenied: false);
      }
      _update(
        progress: 0.10,
        status: LibraryPreparationStatus.scanning,
      );

      await MediaService.instance.loadAudio(
        force: true,
      );

      final songsCount = MediaService.instance.audioTracks.length;
      final artistsCount = MediaService.instance.audioTracks
          .map((t) => t.artist.trim())
          .where((a) => a.isNotEmpty)
          .toSet()
          .length;

      debugPrint(
        '[LibraryPreparation] 🎵 songs = $songsCount',
      );

      _update(
        progress: 0.40,
        status: LibraryPreparationStatus.scanning,
        songsCount: songsCount,
        artistsCount: artistsCount,
      );

      _update(
        progress: 0.45,
        status: LibraryPreparationStatus.artwork,
        songsCount: songsCount,
        artistsCount: artistsCount,
      );

      // ========================================================
      // LYRICS
      // ========================================================

      _update(
        progress: 0.70,
        status: LibraryPreparationStatus.lyrics,
        songsCount: songsCount,
        artistsCount: artistsCount,
        lyricsFilesCount: MediaService.instance.lyricsFilesCount,
      );

      final prewarmFuture =
          MediaService.instance.prewarmLyricsForCurrentLibrary();
      unawaited(
        _watchLyricsProgressWhile(
          prewarmFuture,
          songsCount,
          artistsCount,
        ),
      );
      await prewarmFuture;
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final lyricsFilesCount = MediaService.instance.lyricsFilesCount;

      debugPrint(
        '[LibraryPreparation] 📝 lyrics = $lyricsFilesCount',
      );

      _update(
        progress: 0.90,
        status: LibraryPreparationStatus.indexing,
        songsCount: songsCount,
        artistsCount: artistsCount,
        lyricsFilesCount: lyricsFilesCount,
      );

      // ========================================================
      // COMPLETED
      // ========================================================

      _update(
        progress: 1.0,
        status: LibraryPreparationStatus.completed,
        songsCount: songsCount,
        artistsCount: artistsCount,
        lyricsFilesCount: lyricsFilesCount,
      );

      debugPrint(
        '[LibraryPreparation] ✅ COMPLETED '
        'songs=$songsCount '
        'artists=$artistsCount '
        'lyrics=$lyricsFilesCount',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[LibraryPreparation] ❌ Error: $e',
      );

      debugPrint('$stackTrace');
    } finally {
      _running = false;
    }
  }

  Future<void> _watchLyricsProgressWhile(
    Future<void> prewarmFuture,
    int songsCount,
    int artistsCount,
  ) async {
    if (_disposed) return;

    final timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      _update(
        progress: 0.72,
        status: LibraryPreparationStatus.lyrics,
        songsCount: songsCount,
        artistsCount: artistsCount,
        lyricsFilesCount: MediaService.instance.lyricsFilesCount,
      );
    });

    try {
      await prewarmFuture;
    } finally {
      timer.cancel();
      _update(
        progress: 0.72,
        status: LibraryPreparationStatus.lyrics,
        songsCount: songsCount,
        artistsCount: artistsCount,
        lyricsFilesCount: MediaService.instance.lyricsFilesCount,
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    state.dispose();
  }
}
