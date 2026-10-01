// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_track.dart';
import '../models/lyric_line.dart';
import '../models/playback_state.dart';
import '../services/media_service.dart';
import '../services/playlist_storage.dart';
import '../services/waveform_prewarm_service.dart';
import 'album_art.dart';

part 'music_player_sheet_models.part.dart';
part 'music_player_sheet_portrait.part.dart';
part 'music_player_sheet_landscape.part.dart';
part 'music_player_sheet_lyrics.part.dart';
part 'music_player_sheet_search.part.dart';
part 'music_player_sheet_tools.part.dart';

// الواجهة الرئيسية لصفحة مشغل الموسيقى.
class MusicPlayerSheet extends StatefulWidget {
  const MusicPlayerSheet({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const MusicPlayerSheet(),
        transitionsBuilder: (_, animation, __, child) {
          final slideTween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<MusicPlayerSheet> createState() => _MusicPlayerSheetState();
}

// إدارة الحالة والسلوك الكامل لصفحة المشغل.
class _MusicPlayerSheetState extends State<MusicPlayerSheet> {
  static const bool _trackActiveLyricsLine = false;
  List<LyricLine> _lyricsLines = const [];
  bool _loadingLyrics = false;
  String _lyricsKey = '';
  double? _dragValue;
  Timer? _throttle;

  Future<dynamic> Function() get _openEqualizerPage => () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _EqualizerPage(),
          ),
        );
      };

  @override
  void initState() {
    super.initState();
    // السماح بالوضع الأفقي في صفحة المشغل
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    MediaService.instance.addListener(_onPlaybackChanged);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _throttle?.cancel();
    MediaService.instance.removeListener(_onPlaybackChanged);
    // العودة للوضع العمودي عند الخروج
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await MediaService.instance.init();
    await MediaService.instance.loadAudio();
    if (!mounted) return;
    unawaited(_loadLyricsForCurrentTrack(force: true));
    unawaited(WaveformPrewarmService.prewarmForNewTracks(
      MediaService.instance.audioTracks,
    ));
    unawaited(MediaService.instance.prewarmLyricsForCurrentLibrary());
  }

  void _onPlaybackChanged() {
    _throttle?.cancel();
    _throttle = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      unawaited(_loadLyricsForCurrentTrack());
      unawaited(_preloadCutterWaveformForCurrentTrack());
      unawaited(WaveformPrewarmService.prewarmForNewTracks(
        MediaService.instance.audioTracks,
      ));
      unawaited(MediaService.instance.prewarmLyricsForCurrentLibrary());
    });
  }

  Future<void> _preloadCutterWaveformForCurrentTrack() async {
    final snapshot = MediaService.instance.snapshot;
    final track = _currentTrack(snapshot);
    final source = _resolveTrackSource(snapshot, track);
    if (source == null || source.isEmpty) return;

    await _AudioCutterPageState.prewarmWaveform(source);
  }

  AudioTrack? _currentTrack([PlaybackSnapshot? inputSnapshot]) {
    final snapshot = inputSnapshot ?? MediaService.instance.snapshot;
    final tracks = MediaService.instance.audioTracks;

    if (tracks.isEmpty) return null;

    String normalize(String? value) {
      return (value ?? '').trim().toLowerCase();
    }

    bool isKnown(String? value) {
      final v = normalize(value);
      return v.isNotEmpty && v != '<unknown>';
    }

    final trackId = snapshot.currentTrackId;
    if (trackId != null && trackId.isNotEmpty) {
      for (final track in tracks) {
        if (track.id == trackId) return track;
      }
    }

    final eventTrack = snapshot.track;
    final sourceCandidates = <String>{
      normalize(eventTrack?['path']?.toString()),
      normalize(eventTrack?['uri']?.toString()),
    }..removeWhere((value) => value.isEmpty);

    if (sourceCandidates.isNotEmpty) {
      for (final track in tracks) {
        final path = normalize(track.path);
        final uri = normalize(track.uri);
        if (sourceCandidates.contains(path) || sourceCandidates.contains(uri)) {
          return track;
        }
      }
    }

    final title = snapshot.currentTitle;
    if (isKnown(title)) {
      final titleKey = normalize(title);
      final artistKey = normalize(snapshot.currentArtist);
      for (final track in tracks) {
        if (normalize(track.displayTitle) != titleKey) continue;
        if (artistKey.isEmpty || normalize(track.displayArtist) == artistKey) {
          return track;
        }
      }
    }

    final index = snapshot.currentIndex;
    if (index < 0 || index >= tracks.length) {
      return null;
    }
    return tracks[index];
  }

  String? _resolveTrackSource(PlaybackSnapshot snapshot, AudioTrack? track) {
    final path = track?.path?.trim();
    if (path != null && path.isNotEmpty) return path;

    final uri = track?.uri.trim();
    if (uri != null && uri.isNotEmpty) return uri;

    final eventPath = snapshot.track?['path']?.toString().trim();
    if (eventPath != null && eventPath.isNotEmpty) return eventPath;

    final eventUri = snapshot.track?['uri']?.toString().trim();
    if (eventUri != null && eventUri.isNotEmpty) return eventUri;

    return null;
  }

  Future<void> _loadLyricsForCurrentTrack({bool force = false}) async {
    final snapshot = MediaService.instance.snapshot;
    final track = _currentTrack(snapshot);
    final trackId = snapshot.currentTrackId ?? track?.id;
    final title = snapshot.currentTitle ?? track?.displayTitle ?? '';

    if (trackId == null || title.trim().isEmpty) {
      if (_lyricsLines.isNotEmpty || _lyricsKey.isNotEmpty) {
        setState(() {
          _lyricsLines = const [];
          _lyricsKey = '';
          _loadingLyrics = false;
        });
      }
      return;
    }

    final key =
        '$trackId|${snapshot.currentArtist ?? track?.displayArtist ?? ''}|$title';
    if (!force && key == _lyricsKey) return;

    setState(() {
      _lyricsKey = key;
      _loadingLyrics = true;
    });

    final lines = await MediaService.instance.loadLyrics(
      trackId: trackId,
      title: title,
      artist: snapshot.currentArtist ?? track?.artist,
      durationMs:
          snapshot.durationMs > 0 ? snapshot.durationMs : track?.duration,
      audioUri: track?.uri,
      audioPath: track?.path,
      displayName: track?.displayName,
    );

    if (!mounted || _lyricsKey != key) return;

    setState(() {
      _lyricsLines = lines;
      _loadingLyrics = false;
    });
  }

  Future<void> _togglePlayPause() async {
    final s = MediaService.instance.snapshot;
    if (s.playing) {
      await MediaService.instance.pause();
    } else {
      await MediaService.instance.play();
    }
  }

  Future<void> _toggleFavorite() async {
    final id = MediaService.instance.snapshot.currentTrackId;
    if (id == null || id.isEmpty) return;
    await MediaService.instance.toggleFavoriteById(id);
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '00:00';
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _progressValue(PlaybackSnapshotSafe s) {
    if (s.durationMs <= 0) return 0;
    return (s.positionMs / s.durationMs).clamp(0.0, 1.0);
  }

  int _resolveActiveLyricsIndex(int positionMs, int durationMs) {
    if (_lyricsLines.isEmpty) return -1;

    final hasSynced = _lyricsLines.any((l) => l.timeMs >= 0);
    if (!hasSynced) {
      if (durationMs <= 0) return 0;
      final ratio = (positionMs / durationMs).clamp(0.0, 1.0);
      final idx = (ratio * (_lyricsLines.length - 1)).round();
      return idx.clamp(0, _lyricsLines.length - 1);
    }

    var active = -1;
    for (var i = 0; i < _lyricsLines.length; i++) {
      final time = _lyricsLines[i].timeMs;
      if (time < 0) continue;
      if (positionMs >= time) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  Future<void> _openLyricsPage() async {
    final snapshot = MediaService.instance.snapshot;
    final track = _currentTrack(snapshot);
    final trackId = snapshot.currentTrackId ?? track?.id;
    if (trackId == null) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _LyricsPage(
          trackId: trackId,
          trackTitle: snapshot.currentTitle ?? track?.displayTitle ?? 'Unknown',
          trackArtist: snapshot.currentArtist ?? track?.displayArtist ?? '',
          albumArtUri: snapshot.currentAlbumArt ?? track?.albumArtUri,
          initialLines: _lyricsLines,
        ),
      ),
    );

    if (changed == true) {
      await _loadLyricsForCurrentTrack(force: true);
    }
  }

  Future<void> _searchAndPlay() async {
    final tracks = MediaService.instance.audioTracks;
    if (tracks.isEmpty) return;

    final selected = await showSearch<AudioTrack?>(
      context: context,
      delegate: _TrackSearchDelegate(tracks),
    );
    if (selected == null || !mounted) return;

    final index = tracks.indexWhere((t) => t.id == selected.id);
    if (index < 0) return;

    await MediaService.instance.playQueue(
      tracks,
      startIndex: index,
      startPositionMs: 0,
    );
  }

  Future<void> _showQueueSheet(
      BuildContext context, MediaService service) async {
    if (service.audioTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد أغاني متاحة حاليًا')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'قائمة التشغيل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${service.audioTracks.length} أغنية',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: service.audioTracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = service.audioTracks[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          height: 40,
                          width: 50,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            color: Colors.white24,
                          ),
                          child: AlbumArt(
                            uri: track.albumArtUri,
                            size: 60,
                            radius: 6,
                            fallbackImage: 'assets/images/Sonva_album.png',
                            lazyFetchUri: () => MediaService.instance
                                .fetchAlbumArtUriForTrack(track),
                          ),
                        ),
                        title: Text(
                          track.displayTitle,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.displayArtist,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await service.playQueue(service.audioTracks,
                              startIndex: index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCutterPage() async {
    final snapshot = MediaService.instance.snapshot;
    final track = _currentTrack(snapshot);
    final source = _resolveTrackSource(snapshot, track);
    if (source == null || source.isEmpty) return;
    unawaited(WaveformPrewarmService.prewarmWaveform(source));

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AudioCutterPage(
          title: snapshot.currentTitle ?? track?.displayTitle ?? 'Unknown',
          artist: snapshot.currentArtist ?? track?.displayArtist ?? 'Unknown',
          durationMs: snapshot.durationMs > 0
              ? snapshot.durationMs
              : (track?.duration ?? 0),
          albumArtUri: snapshot.currentAlbumArt ?? track?.albumArtUri,
          source: source,
        ),
      ),
    );
  }

  Widget _buildLyricsPreview({required int previewIndex}) {
    if (_loadingLyrics) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_lyricsLines.isEmpty) {
      return const Center(
        child: Column(
          children: [
            Text(
              'No lyrics found !',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              'Tap here to add lyrics',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final idx = previewIndex >= 0 ? previewIndex : 0;
    final current = _lyricsLines[idx].text;
    final next =
        idx + 1 < _lyricsLines.length ? _lyricsLines[idx + 1].text : '';

    return Column(
      children: [
        Text(
          current,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        if (next.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            next,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MediaService.instance,
      builder: (context, _) {
        final snapshot = MediaService.instance.snapshot;
        final safe =
            PlaybackSnapshotSafe(snapshot.positionMs, snapshot.durationMs);
        final track = _currentTrack();
        final orientation = MediaQuery.of(context).orientation;

        if (track == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'No track is playing',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final playbackLyricsIndex = _resolveActiveLyricsIndex(
          safe.positionMs,
          safe.durationMs,
        );

        final activeLyricsIndex =
            _trackActiveLyricsLine ? playbackLyricsIndex : -1;

        final art = (snapshot.currentAlbumArt?.isNotEmpty ?? false)
            ? snapshot.currentAlbumArt
            : track.albumArtUri;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: AlbumArt(
                  uri: art,
                  size: 1400,
                  radius: 0,
                  lazyFetchUri: () =>
                      MediaService.instance.fetchAlbumArtUriForTrack(track),
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                  child: Container(color: Colors.black.withOpacity(0.64)),
                ),
              ),
              orientation == Orientation.landscape
                  ? _LandscapePlayer(
                      track: track,
                      positionMs: safe.positionMs,
                      durationMs: safe.durationMs,
                      playing: snapshot.playing,
                      isFavorite: MediaService.instance
                          .isFavorite(snapshot.currentTrackId ?? ''),
                      repeatMode: snapshot.repeatMode,
                      shuffleMode: snapshot.shuffleMode,
                      progressValue: _dragValue ?? _progressValue(safe),
                      formatDuration: _formatDuration,
                      onSeekStart: (value) =>
                          setState(() => _dragValue = value),
                      onSeekEnd: (value) async {
                        final ms = (value * safe.durationMs).round();
                        await MediaService.instance.seekTo(ms);
                        if (mounted) setState(() => _dragValue = null);
                      },
                      onPlayPause: _togglePlayPause,
                      onNext: MediaService.instance.next,
                      onPrevious: MediaService.instance.previous,
                      onShuffle: MediaService.instance.toggleShuffle,
                      onRepeat: MediaService.instance.toggleRepeat,
                      onFavorite: _toggleFavorite,
                      onShare: MediaService.instance.shareCurrent,
                      onQueue: () =>
                          _showQueueSheet(context, MediaService.instance),
                      onSearch: _searchAndPlay,
                      onOpenLyrics: _openLyricsPage,
                      onQueueItemTap: (index) =>
                          MediaService.instance.playQueue(
                        MediaService.instance.audioTracks,
                        startIndex: index,
                      ),
                      lyrics: _lyricsLines,
                      activeLyricsIndex: activeLyricsIndex,
                    )
                  : SafeArea(
                      child: _PortraitPlayer(
                        onOpenEqualizerPage: _openEqualizerPage,
                        track: track,
                        positionMs: safe.positionMs,
                        durationMs: safe.durationMs,
                        playing: snapshot.playing,
                        isFavorite: MediaService.instance
                            .isFavorite(snapshot.currentTrackId ?? ''),
                        repeatMode: snapshot.repeatMode,
                        shuffleMode: snapshot.shuffleMode,
                        progressValue: _dragValue ?? _progressValue(safe),
                        formatDuration: _formatDuration,
                        onSeekStart: (value) =>
                            setState(() => _dragValue = value),
                        onSeekEnd: (value) async {
                          final ms = (value * safe.durationMs).round();
                          await MediaService.instance.seekTo(ms);
                          if (mounted) setState(() => _dragValue = null);
                        },
                        onPlayPause: _togglePlayPause,
                        onNext: MediaService.instance.next,
                        onPrevious: MediaService.instance.previous,
                        onShuffle: MediaService.instance.toggleShuffle,
                        onRepeat: MediaService.instance.toggleRepeat,
                        onFavorite: _toggleFavorite,
                        onShare: MediaService.instance.shareCurrent,
                        onQueue: () =>
                            _showQueueSheet(context, MediaService.instance),
                        onSearch: _searchAndPlay,
                        onOpenLyrics: _openLyricsPage,
                        onOpenQueuePage: () =>
                            _showQueueSheet(context, MediaService.instance),
                        onOpenCutterPage: _openCutterPage,
                        lyricsPreview: _buildLyricsPreview(
                          previewIndex: playbackLyricsIndex,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}
