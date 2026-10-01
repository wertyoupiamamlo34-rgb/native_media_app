import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_track.dart';
import '../models/lyric_line.dart';
import '../models/playback_state.dart';
import 'waveform_prewarm_service.dart';

/// خدمة مركزية للتواصل مع جانب Android الأصلي عبر MethodChannel & EventChannel.
///
/// تنفّذ نمط Singleton بسيط وتوفّر:
///  - مكتبة الوسائط (صوت/فيديو) مع كاش داخلي
///  - تيار حالة التشغيل (PlaybackSnapshot) للـ Mini Player
///  - مجموعة المفضلات (favorites) ومجموعة عدّاد التشغيلات (play counts) لتبويبة "الشائعة"
class MediaService extends ChangeNotifier {
  MediaService._();
  static final MediaService instance = MediaService._();

  static const _commandChannel = MethodChannel('app.media.commands');
  static const _eventChannel = EventChannel('app.media.events');
  static const _lyricsApi = 'https://lrclib.net/api/search';
  static const _customLyricsKeyPrefix = 'custom_lyrics_';
  static const _lyricsPreparedTracksKey = 'lyrics_prewarm_tracks_v1';
  static const _lyricsAvailableTracksKey = 'lyrics_available_tracks_v1';
  static final Map<String, List<LyricLine>> _lyricsQueryCache = {};
  static final Map<String, List<LyricLine>> _customLyricsCache = {};

  // ─── الحالة المعلنة ─────────────────────────────────────────────────────
  List<AudioTrack> _audio = [];
  Set<String> _favoriteIds = {};
  Map<String, int> _playCounts = {};
  Map<String, int> _lastPlayedAt = {};
  final Map<String, String?> _albumArtUriCache = {};
  final Map<String, Future<String>> _pendingAlbumArtFetches = {};
  final Map<String, String> _albumArtLookupKeys = {};
  PlaybackSnapshot _snapshot = PlaybackSnapshot.empty;
  List<double> _visualizerBins = const [];
  List<double> _visualizerPeaks = const [];
  int _visualizerTimestampMs = 0;

  bool _loadingAudio = false;
  bool _initialized = false;
  bool _lyricsPrewarmRunning = false;
  Future<void>? _lyricsPrewarmFuture;
  Future<void>? _initializationFuture;
  final Set<String> _lyricsAvailableTrackKeys = <String>{};

  StreamSubscription? _eventSub;

  // Getters عامة
  List<AudioTrack> get audioTracks => _audio;
  Set<String> get favoriteIds => _favoriteIds;
  PlaybackSnapshot get snapshot => _snapshot;
  List<double> get visualizerBins => _visualizerBins;
  List<double> get visualizerPeaks => _visualizerPeaks;
  int get visualizerTimestampMs => _visualizerTimestampMs;
  bool get loadingAudio => _loadingAudio;
  bool get initialized => _initialized;
  int get lyricsFilesCount {
    if (_audio.isEmpty) {
      return _lyricsAvailableTrackKeys.length;
    }

    final availableCount = _audio.where((track) {
      final trackId = track.id.trim().toLowerCase();
      if (trackId.isNotEmpty && _lyricsAvailableTrackKeys.contains(trackId)) {
        return true;
      }

      final trackKey = _audioTrackKey(track);
      if (trackKey.isNotEmpty && _lyricsAvailableTrackKeys.contains(trackKey)) {
        return true;
      }

      final displayTitle = track.displayTitle.trim().toLowerCase();
      if (displayTitle.isNotEmpty &&
          _lyricsAvailableTrackKeys.contains(displayTitle)) {
        return true;
      }

      final artist = track.artist.trim().toLowerCase();
      final composite = artist.isEmpty ? displayTitle : '$displayTitle|$artist';
      return composite.isNotEmpty &&
          _lyricsAvailableTrackKeys.contains(composite);
    }).length;

    return availableCount > 0
        ? availableCount
        : _lyricsAvailableTrackKeys.length;
  }

  // ─── التهيئة ───────────────────────────────────────────────────────────
  Future<void> init() async {
    final currentInitialization = _initializationFuture;
    if (currentInitialization != null) {
      return currentInitialization;
    }

    final initialization = _initInternal();
    _initializationFuture = initialization;
    return initialization;
  }

  Future<void> _initInternal() async {
    // اشتراك في تيار أحداث المشغل
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
          _onNativeEvent,
          onError: (e) => debugPrint('[MediaService] event error: $e'),
        );

    // استرجاع المفضلات وعدّاد التشغيل من التخزين المحلي
    await _restoreLocalPrefs();

    // إخبار الـ Native بأنه يجب تجهيز المشغل
    try {
      await _commandChannel.invokeMethod('initPlayer');
    } catch (e) {
      debugPrint('[MediaService] initPlayer failed: $e');
    }

    // قراءة المفضلات من الجانب الأصلي (مصدر الحقيقة لو موجود)
    try {
      final List<dynamic>? nativeFavs =
          await _commandChannel.invokeMethod<List<dynamic>>('getFavorites');
      if (nativeFavs != null && nativeFavs.isNotEmpty) {
        _favoriteIds = nativeFavs.map((e) => e.toString()).toSet();
      }
    } catch (_) {
      // ignore
    }

    _initialized = true;
    notifyListeners();
    // Kick off background lyrics prewarm early so the app can discover
    // available lyrics without waiting for user interaction.
    unawaited(prewarmLyricsForCurrentLibrary());
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  // ─── معالجة أحداث الـ Native ────────────────────────────────────────────
  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final ev = raw['event']?.toString();
    switch (ev) {
      case 'playback_state':
        _snapshot = PlaybackSnapshot.fromEvent(raw);
        notifyListeners();
        break;
      case 'library_changed':
        // أعد تحميل المكتبة في الخلفية
        refreshLibrary(silent: true);
        break;
      case 'favorite_changed':
        final id = raw['id']?.toString();
        final fav = raw['favorite'] == true;
        if (id != null) {
          if (fav) {
            _favoriteIds.add(id);
          } else {
            _favoriteIds.remove(id);
          }
          notifyListeners();
        }
        break;
      case 'visualizer_frame':
        final dynamic rawBins = raw['bins'];
        final dynamic rawPeaks = raw['peaks'];
        final dynamic rawTimestamp = raw['timestampMs'];
        if (rawBins is List) {
          _visualizerBins = rawBins
              .map((e) => e is num ? e.toDouble() : double.tryParse('$e'))
              .whereType<double>()
              .toList(growable: false);
          if (rawPeaks is List) {
            _visualizerPeaks = rawPeaks
                .map((e) => e is num ? e.toDouble() : double.tryParse('$e'))
                .whereType<double>()
                .toList(growable: false);
          }
          _visualizerTimestampMs = rawTimestamp is num
              ? rawTimestamp.toInt()
              : _visualizerTimestampMs;
          notifyListeners();
        }
        break;
      case 'error':
        debugPrint('[MediaService] native error: ${raw['message']}');
        break;
      default:
        break;
    }
  }

  Future<void> setVisualizerAnalysisConfig(Map<String, dynamic> config) async {
    try {
      await _commandChannel.invokeMethod('setVisualizerAnalysisConfig', {
        'config': config,
      });
    } catch (e) {
      debugPrint('[MediaService] setVisualizerAnalysisConfig failed: $e');
    }
  }

  // ─── تحميل المكتبة ─────────────────────────────────────────────────────
  Future<void> loadAudio({bool force = false}) async {
    if (_loadingAudio) return;
    if (_audio.isNotEmpty && !force) return;
    _loadingAudio = true;
    notifyListeners();
    try {
      final List<dynamic>? raw =
          await _commandChannel.invokeMethod<List<dynamic>>(
        'getDeviceAudio',
        {'forceRefresh': force},
      );
      final tracks = (raw ?? [])
          .whereType<Map>()
          .map((m) => AudioTrack.fromMap(m))
          .toList();

      final uniqueTracks = <String, AudioTrack>{};
      for (final track in tracks) {
        final key = _audioTrackKey(track);
        uniqueTracks.putIfAbsent(key, () => track);
      }
      _audio = uniqueTracks.values.toList();
      unawaited(WaveformPrewarmService.prewarmForNewTracks(_audio));
      unawaited(_prewarmLyricsForNewTracks(_audio));
    } catch (e) {
      debugPrint('[MediaService] loadAudio failed: $e');
    } finally {
      _loadingAudio = false;
      notifyListeners();
    }
  }

  String _audioTrackKey(AudioTrack track) {
    final path = track.path?.trim();
    if (path != null && path.isNotEmpty) {
      return path.toLowerCase();
    }
    final uri = track.uri.trim();
    if (uri.isNotEmpty) {
      return uri.toLowerCase();
    }
    if (track.displayName.isNotEmpty && track.duration > 0) {
      return '${track.displayName.toLowerCase()}|${track.duration}';
    }
    return track.id;
  }

  Future<void> _prewarmLyricsForNewTracks(Iterable<AudioTrack> tracks) {
    if (_lyricsPrewarmRunning) {
      return _lyricsPrewarmFuture ?? Future.value();
    }

    _lyricsPrewarmRunning = true;
    _lyricsPrewarmFuture = _prewarmLyricsForNewTracksAsync(tracks);
    return _lyricsPrewarmFuture!;
  }

  Future<void> _prewarmLyricsForNewTracksAsync(
      Iterable<AudioTrack> tracks) async {
    try {
      final list = tracks.toList(growable: false);
      if (list.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final prepared =
          (prefs.getStringList(_lyricsPreparedTracksKey) ?? const <String>[])
              .toSet();

      final pendingTracks = <AudioTrack>[];
      for (final track in list) {
        final key = _audioTrackKey(track);
        final idKey = track.id.trim().toLowerCase();
        final titleKey = track.displayTitle.trim().toLowerCase();
        final artistKey = track.artist.trim().toLowerCase();
        final composite = artistKey.isEmpty ? titleKey : '$titleKey|$artistKey';

        final preparedContainsAny = prepared.contains(key) ||
            (idKey.isNotEmpty && prepared.contains(idKey)) ||
            (titleKey.isNotEmpty && prepared.contains(titleKey)) ||
            (composite.isNotEmpty && prepared.contains(composite));

        final availableContainsAny = _lyricsAvailableTrackKeys.contains(key) ||
            (idKey.isNotEmpty && _lyricsAvailableTrackKeys.contains(idKey)) ||
            (titleKey.isNotEmpty &&
                _lyricsAvailableTrackKeys.contains(titleKey)) ||
            (composite.isNotEmpty &&
                _lyricsAvailableTrackKeys.contains(composite));

        if (preparedContainsAny && availableContainsAny) {
          debugPrint(
              '[MediaService] prewarm skip prepared key=$key id=$idKey title=$titleKey composite=$composite (already available)');
          continue;
        }

        if (preparedContainsAny && !availableContainsAny) {
          debugPrint(
              '[MediaService] prewarm rechecking prepared key=$key id=$idKey title=$titleKey composite=$composite (no available match)');
          // fallthrough to re-check this track — it was marked prepared
          // previously but no lyrics were registered for it, so try again.
        }
        pendingTracks.add(track);
      }

      if (pendingTracks.isEmpty) return;

      for (var i = 0; i < pendingTracks.length; i++) {
        final track = pendingTracks[i];

        final preparedKey = _audioTrackKey(track);
        debugPrint(
            '[MediaService] prewarm processing index=$i/${pendingTracks.length - 1} key=$preparedKey id=${track.id} title=${track.displayTitle}');

        final lines = await loadLyrics(
          trackId: track.id,
          title: track.displayTitle,
          artist: track.artist,
          durationMs: track.duration,
          audioUri: track.uri,
          audioPath: track.path,
          displayName: track.displayName,
        ).timeout(
          const Duration(seconds: 8),
          onTimeout: () => const <LyricLine>[],
        );

        if (lines.isNotEmpty) {
          debugPrint(
              '[MediaService] prewarm found lyrics for id=${track.id} lines=${lines.length}');
          _registerLyricsFound(track.id, track.displayTitle,
              artist: track.artist);
        } else {
          debugPrint('[MediaService] prewarm no lyrics for id=${track.id}');
        }

        _audioTrackKey(track);
        prepared.add(preparedKey);
        final preparedId = track.id.trim().toLowerCase();
        if (preparedId.isNotEmpty) prepared.add(preparedId);
        if (i % 8 == 0 || i == pendingTracks.length - 1) {
          await prefs.setStringList(
            _lyricsPreparedTracksKey,
            prepared.toList(growable: false),
          );
          await _persistAvailableLyricsKeys();
        }
      }
    } catch (e) {
      debugPrint('[MediaService] lyrics prewarm skipped: $e');
    } finally {
      _lyricsPrewarmRunning = false;
      _lyricsPrewarmFuture = null;
    }
  }

  Future<void> prewarmLyricsForCurrentLibrary() {
    return _prewarmLyricsForNewTracks(_audio);
  }

  Future<String> fetchAlbumArtUriForTrack(AudioTrack track) async {
    final trackId = track.id;
    final lookupKey = _albumArtLookupKey(track);
    final existing = _albumArtUriCache[lookupKey];
    if (existing != null) return existing;
    if (track.albumArtUri.isNotEmpty) {
      _albumArtUriCache[lookupKey] = track.albumArtUri;
      _albumArtLookupKeys[trackId] = lookupKey;
      return track.albumArtUri;
    }

    final pending = _pendingAlbumArtFetches[lookupKey];
    if (pending != null) return pending;

    final future = _commandChannel
        .invokeMethod<String>('getAudioArtwork', {
          'trackId': track.id,
          'albumId': track.albumId,
          'trackUri': track.uri,
          'path': track.path,
        })
        .then((value) => value?.toString() ?? '')
        .then((uri) {
          _albumArtUriCache[lookupKey] = uri;
          _albumArtLookupKeys[trackId] = lookupKey;
          if (uri.isNotEmpty) {
            notifyListeners();
          }
          _pendingAlbumArtFetches.remove(lookupKey);
          return uri;
        })
        .catchError((_) {
          _albumArtUriCache[lookupKey] = '';
          _albumArtLookupKeys[trackId] = lookupKey;
          _pendingAlbumArtFetches.remove(lookupKey);
          return '';
        });

    _pendingAlbumArtFetches[lookupKey] = future;
    return future;
  }

  String albumArtUriForTrack(AudioTrack track) {
    final lookupKey = _albumArtLookupKey(track);
    return _albumArtUriCache[lookupKey] ?? track.albumArtUri;
  }

  String _albumArtLookupKey(AudioTrack track) {
    final explicitKey = _albumArtLookupKeys[track.id];
    if (explicitKey != null && explicitKey.isNotEmpty) {
      return explicitKey;
    }

    final normalizedUri = track.uri.trim();
    final normalizedPath = track.path?.trim() ?? '';
    if (normalizedPath.isNotEmpty) {
      return normalizedPath.toLowerCase();
    }
    if (normalizedUri.isNotEmpty) {
      return normalizedUri.toLowerCase();
    }
    return track.id.toLowerCase();
  }

  Future<void> refreshLibrary({bool silent = false}) async {
    if (!silent) {
      _loadingAudio = true;
      notifyListeners();
    }
    await loadAudio(force: true);
  }

  // ─── أوامر التشغيل ────────────────────────────────────────────────────
  Future<void> playQueue(
    List<AudioTrack> queue, {
    int startIndex = 0,
    int startPositionMs = 0,
  }) async {
    if (queue.isEmpty) return;
    final items = queue.map((t) => t.toQueueItem()).toList();
    try {
      await _commandChannel.invokeMethod('loadQueue', {
        'items': items,
        'startIndex': startIndex,
        'startPositionMs': startPositionMs,
      });
      await _commandChannel.invokeMethod('play');
      // تسجيل عدّاد التشغيل لتبويبة "الشائعة"
      _bumpPlayCount(queue[startIndex].id);
    } catch (e) {
      debugPrint('[MediaService] playQueue failed: $e');
    }
  }

  Future<void> play() async {
    await _commandChannel.invokeMethod('play');
  }

  Future<void> pause() async {
    await _commandChannel.invokeMethod('pause');
  }

  Future<void> next() async {
    await _commandChannel.invokeMethod('next');
  }

  Future<void> previous() async {
    await _commandChannel.invokeMethod('previous');
  }

  Future<void> seekTo(int positionMs) async {
    await _commandChannel.invokeMethod('seekTo', {'positionMs': positionMs});
  }

  Future<bool> toggleFavoriteById(String id) async {
    try {
      final res = await _commandChannel
          .invokeMethod<bool>('toggleFavoriteById', {'id': id});
      final now = res ?? false;
      if (now) {
        _favoriteIds.add(id);
      } else {
        _favoriteIds.remove(id);
      }
      await _persistFavorites();
      notifyListeners();
      return now;
    } catch (e) {
      // fallback: محلياً فقط
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
      await _persistFavorites();
      notifyListeners();
      return _favoriteIds.contains(id);
    }
  }

  bool isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> toggleShuffle() async {
    final target = !_snapshot.shuffleMode;
    try {
      await _commandChannel.invokeMethod('setShuffleMode', {'on': target});
    } catch (e) {
      // Compatibility fallback for older native implementations.
      try {
        await _commandChannel.invokeMethod('toggleShuffle');
      } catch (_) {
        debugPrint('[MediaService] toggleShuffle failed: $e');
      }
    }
  }

  Future<void> toggleRepeat() async {
    final nextMode = (_snapshot.repeatMode + 1) % 3;
    try {
      await _commandChannel.invokeMethod('setRepeatMode', {'mode': nextMode});
    } catch (e) {
      // Compatibility fallback for older native implementations.
      try {
        await _commandChannel.invokeMethod('toggleRepeat');
      } catch (_) {
        debugPrint('[MediaService] toggleRepeat failed: $e');
      }
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _commandChannel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      debugPrint('[MediaService] setVolume failed: $e');
    }
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    try {
      await _commandChannel
          .invokeMethod('setEqualizerEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[MediaService] setEqualizerEnabled failed: $e');
    }
  }

  Future<void> setEqualizerBandLevel({
    required int bandIndex,
    required double levelDb,
  }) async {
    try {
      await _commandChannel.invokeMethod('setEqualizerBandLevel', {
        'bandIndex': bandIndex,
        'levelDb': levelDb,
      });
    } catch (e) {
      debugPrint('[MediaService] setEqualizerBandLevel failed: $e');
    }
  }

  Future<void> setBassBoostDb(double valueDb) async {
    try {
      await _commandChannel
          .invokeMethod('setBassBoostDb', {'valueDb': valueDb});
    } catch (e) {
      debugPrint('[MediaService] setBassBoostDb failed: $e');
    }
  }

  Future<void> setTrebleDb(double valueDb) async {
    try {
      await _commandChannel.invokeMethod('setTrebleDb', {'valueDb': valueDb});
    } catch (e) {
      debugPrint('[MediaService] setTrebleDb failed: $e');
    }
  }

  Future<void> setVirtualizerEnabled(bool enabled) async {
    try {
      await _commandChannel
          .invokeMethod('setVirtualizerEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('[MediaService] setVirtualizerEnabled failed: $e');
    }
  }

  Future<void> setVirtualizerStrength(double strength) async {
    try {
      await _commandChannel
          .invokeMethod('setVirtualizerStrength', {'strength': strength});
    } catch (e) {
      debugPrint('[MediaService] setVirtualizerStrength failed: $e');
    }
  }

  Future<bool> openNewSongNotificationChannelSettings() async {
    try {
      final result = await _commandChannel.invokeMethod<bool>(
        'openNewSongNotificationChannelSettings',
      );
      return result ?? false;
    } catch (e) {
      debugPrint(
        '[MediaService] openNewSongNotificationChannelSettings failed: $e',
      );
      return false;
    }
  }

  Future<void> shareCurrent() async {
    try {
      await _commandChannel.invokeMethod('shareCurrent');
    } catch (e) {
      debugPrint('[MediaService] shareCurrent failed: $e');
    }
  }

  Future<List<LyricLine>> loadLyrics({
    required String trackId,
    required String title,
    String? artist,
    int? durationMs,
    String? audioUri,
    String? audioPath,
    String? displayName,
  }) async {
    final custom = await loadCustomLyrics(trackId);
    if (custom.isNotEmpty) {
      _registerLyricsFound(trackId, title, artist: artist);
      return custom;
    }

    final local = await _loadLyricsLocal(
      trackId: trackId,
      title: title,
      audioUri: audioUri,
      audioPath: audioPath,
      displayName: displayName,
    );
    if (local.isNotEmpty) {
      _registerLyricsFound(trackId, title, artist: artist);
      return local;
    }

    final online = await _loadLyricsOnline(
      title: title,
      artist: artist,
      durationMs: durationMs,
      displayName: displayName,
    );
    if (online.isNotEmpty) {
      _registerLyricsFound(trackId, title, artist: artist);
      debugPrint(
          '[MediaService] lyrics found online title=$title artist=${artist ?? ''} lines=${online.length}');
    }
    return online;
  }

  Future<List<LyricLine>> loadCustomLyrics(String trackId) async {
    final key = _customLyricsStorageKey(trackId);
    final inMemory = _customLyricsCache[key];
    if (inMemory != null) return inMemory;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        _customLyricsCache[key] = const [];
        return const [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _customLyricsCache[key] = const [];
        return const [];
      }

      final parsed = decoded
          .map((e) {
            if (e is Map) {
              final text = (e['text']?.toString() ?? '').trim();
              final timeMs = _toInt(e['timeMs']) ?? -1;
              if (text.isNotEmpty) {
                return LyricLine(timeMs: timeMs, text: text);
              }
            }
            return const LyricLine(timeMs: -1, text: '');
          })
          .where((line) => line.text.isNotEmpty)
          .toList();

      _customLyricsCache[key] = parsed;
      if (parsed.isNotEmpty) {
        _registerLyricsFound(trackId, trackId);
      }
      return parsed;
    } catch (_) {
      _customLyricsCache[key] = const [];
      return const [];
    }
  }

  Future<void> saveCustomLyrics(String trackId, List<LyricLine> lines) async {
    final key = _customLyricsStorageKey(trackId);
    final sanitized = lines
        .map((line) => LyricLine(timeMs: line.timeMs, text: line.text.trim()))
        .where((line) => line.text.isNotEmpty)
        .toList();

    final payload = sanitized
        .map((line) => {'timeMs': line.timeMs, 'text': line.text})
        .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(payload));
    _customLyricsCache[key] = sanitized;
    if (sanitized.isNotEmpty) {
      _registerLyricsFound(trackId, trackId);
    }
  }

  Future<void> clearCustomLyrics(String trackId) async {
    final key = _customLyricsStorageKey(trackId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    _customLyricsCache.remove(key);
    _lyricsAvailableTrackKeys
        .removeWhere((entry) => entry == trackId.toLowerCase());
  }

  Future<bool> hasCustomLyrics(String trackId) async {
    final lines = await loadCustomLyrics(trackId);
    return lines.isNotEmpty;
  }

  String _customLyricsStorageKey(String trackId) =>
      '$_customLyricsKeyPrefix$trackId';

  void _registerLyricsFound(String trackId, String? fallbackTitle,
      {String? artist}) {
    final normalizedTrackId = trackId.trim().toLowerCase();
    if (normalizedTrackId.isNotEmpty) {
      debugPrint('[MediaService] registerLyricsFound by id=$normalizedTrackId');
      _lyricsAvailableTrackKeys.add(normalizedTrackId);
      unawaited(_persistAvailableLyricsKeys());
      return;
    }

    final normalizedTitle = (fallbackTitle ?? '').trim().toLowerCase();
    if (normalizedTitle.isEmpty) {
      return;
    }

    final normalizedArtist = (artist ?? '').trim().toLowerCase();
    final key = normalizedArtist.isEmpty
        ? normalizedTitle
        : '$normalizedTitle|$normalizedArtist';
    debugPrint('[MediaService] registerLyricsFound by title/composite=$key');
    _lyricsAvailableTrackKeys.add(key);
    unawaited(_persistAvailableLyricsKeys());
  }

  Future<List<LyricLine>> _loadLyricsLocal({
    required String trackId,
    required String title,
    String? audioUri,
    String? audioPath,
    String? displayName,
  }) async {
    try {
      final raw = await _commandChannel.invokeMethod<List<dynamic>>(
        'loadLyrics',
        {
          'trackId': trackId,
          'title': title,
          'audioUri': audioUri,
          'audioPath': audioPath,
          'displayName': displayName,
        },
      );

      return (raw ?? const [])
          .map(_toLyricLine)
          .where((line) => line.text.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[MediaService] loadLyrics failed: $e');
      return const [];
    }
  }

  Future<List<LyricLine>> _loadLyricsOnline({
    required String title,
    String? artist,
    int? durationMs,
    String? displayName,
  }) async {
    final queryTitle = _bestQueryTitle(title, displayName);
    if (queryTitle.isEmpty) return const [];

    final cacheKey =
        '${_normalizeForCompare(queryTitle)}|${_normalizeForCompare(artist ?? '')}|${(durationMs ?? 0) ~/ 1000}';
    final cached = _lyricsQueryCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    final uri = Uri.parse(_lyricsApi).replace(queryParameters: {
      'track_name': queryTitle,
      if ((artist ?? '').trim().isNotEmpty) 'artist_name': artist!.trim(),
    });

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 7);
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.userAgentHeader, 'native_media_app/1.0');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        client.close(force: true);
        return const [];
      }

      final body = await res.transform(utf8.decoder).join();
      client.close(force: true);

      final parsed = jsonDecode(body);
      if (parsed is! List) return const [];

      final bestLyrics = _pickBestLyrics(
        entries: parsed.whereType<Map>().toList(),
        title: queryTitle,
        artist: artist,
        durationMs: durationMs,
      );

      if (bestLyrics.isEmpty) return const [];
      _lyricsQueryCache[cacheKey] = bestLyrics;
      return bestLyrics;
    } catch (e) {
      debugPrint('[MediaService] online lyrics fetch failed: $e');
      return const [];
    }
  }

  List<LyricLine> _pickBestLyrics({
    required List<Map> entries,
    required String title,
    String? artist,
    int? durationMs,
  }) {
    if (entries.isEmpty) return const [];

    double bestScore = -1;
    List<LyricLine> bestLines = const [];

    for (final entry in entries) {
      final trackName = (entry['trackName'] ?? '').toString();
      final artistName = (entry['artistName'] ?? '').toString();
      final synced = (entry['syncedLyrics'] ?? '').toString();
      final plain = (entry['plainLyrics'] ?? '').toString();
      final durationSec = _toDouble(entry['duration']);

      final titleScore = _similarity(title, trackName);
      final artistScore = _similarity(artist ?? '', artistName);
      final durationScore = _durationScore(durationMs, durationSec);
      final qualityBoost = synced.trim().isNotEmpty ? 0.15 : 0.0;

      final score = (titleScore * 0.60) +
          (artistScore * 0.25) +
          (durationScore * 0.15) +
          qualityBoost;

      final candidateRaw = synced.trim().isNotEmpty ? synced : plain;
      final lines = _parseLyricLines(candidateRaw);
      if (lines.isEmpty) continue;

      if (score > bestScore) {
        bestScore = score;
        bestLines = lines;
      }
    }

    return bestLines;
  }

  List<LyricLine> _parseLyricLines(String raw) {
    if (raw.trim().isEmpty) return const [];

    final parsed = <LyricLine>[];
    final rows = raw.split(RegExp(r'\r?\n'));
    final timestampRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

    for (final row in rows) {
      final line = row.trim();
      if (line.isEmpty || line == '...') continue;

      final timeMatches = timestampRegex.allMatches(line).toList();
      final text = _sanitizeLyricText(
        line.replaceAll(timestampRegex, ' '),
      );
      if (text.isEmpty) continue;

      if (timeMatches.isEmpty) {
        parsed.add(LyricLine(timeMs: -1, text: text));
        continue;
      }

      for (final m in timeMatches) {
        final min = int.tryParse(m.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '0') ?? 0;
        final fracRaw = m.group(3) ?? '0';
        final fracMs = _fractionToMs(fracRaw);
        final timeMs = (min * 60 * 1000) + (sec * 1000) + fracMs;
        parsed.add(LyricLine(timeMs: timeMs, text: text));
      }
    }

    if (parsed.isEmpty) return const [];
    final hasSynced = parsed.any((line) => line.isSynced);
    if (!hasSynced) return parsed;

    parsed.sort((a, b) {
      if (a.timeMs < 0 && b.timeMs < 0) return 0;
      if (a.timeMs < 0) return 1;
      if (b.timeMs < 0) return -1;
      return a.timeMs.compareTo(b.timeMs);
    });
    return parsed;
  }

  String _sanitizeLyricText(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';

    // Drop common LRC metadata tags so users don't see bracket-only lines.
    text = text.replaceAll(
      RegExp(
        r'\[(?:ar|ti|al|by|offset|length|au|re|ve):[^\]]*\]',
        caseSensitive: false,
      ),
      ' ',
    );

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  int _fractionToMs(String value) {
    if (value.isEmpty) return 0;
    if (value.length == 1) return (int.tryParse(value) ?? 0) * 100;
    if (value.length == 2) return (int.tryParse(value) ?? 0) * 10;
    return int.tryParse(value.substring(0, 3)) ?? 0;
  }

  String _bestQueryTitle(String title, String? displayName) {
    final candidates = [title, displayName ?? '']
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return '';

    candidates.sort((a, b) => b.length.compareTo(a.length));
    return _cleanQueryTitle(candidates.first);
  }

  String _cleanQueryTitle(String value) {
    return value
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(
          RegExp(r'\b(أداء|اداء|by|feat\.?|ft\.?)\b.*$', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeForCompare(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll(RegExp(r'[\s_\-\[\](){}]+'), '')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
        .trim();
  }

  double _similarity(String a, String b) {
    final x = _normalizeForCompare(a);
    final y = _normalizeForCompare(b);
    if (x.isEmpty || y.isEmpty) return 0.0;
    if (x == y) return 1.0;
    if (x.contains(y) || y.contains(x)) return 0.82;

    final minLen = x.length < y.length ? x.length : y.length;
    var prefix = 0;
    while (prefix < minLen && x[prefix] == y[prefix]) {
      prefix++;
    }
    return (prefix / minLen).clamp(0.0, 1.0);
  }

  double _durationScore(int? durationMs, double? durationSec) {
    if (durationMs == null ||
        durationMs <= 0 ||
        durationSec == null ||
        durationSec <= 0) {
      return 0.0;
    }
    final localSec = durationMs / 1000.0;
    final diff = (localSec - durationSec).abs();
    if (diff <= 2) return 1.0;
    if (diff <= 6) return 0.75;
    if (diff <= 12) return 0.45;
    return 0.0;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  LyricLine _toLyricLine(dynamic value) {
    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((key, val) {
        map[key.toString().trim()] = val;
      });

      final text = _extractLyricTextFromMap(map);
      final timeMs =
          _toInt(map['timeMs'] ?? map['time'] ?? map['timestampMs']) ?? -1;
      if (text.isNotEmpty) {
        return LyricLine(timeMs: timeMs, text: text);
      }
    }

    final raw = (value?.toString() ?? '').trim();
    if (raw.isEmpty) return const LyricLine(timeMs: -1, text: '');

    final parsedMapLike = _parseMapLikeLyricString(raw);
    if (parsedMapLike != null) return parsedMapLike;

    // Prevent showing raw map payloads like {timeMs: ..., text: ...} to the user.
    if (raw.startsWith('{') && raw.contains('timeMs') && raw.contains('text')) {
      return const LyricLine(timeMs: -1, text: '');
    }

    return LyricLine(timeMs: -1, text: raw);
  }

  String _extractLyricTextFromMap(Map<String, dynamic> map) {
    const keys = ['text', 'lyric', 'lyrics', 'line', 'content'];
    for (final key in keys) {
      final value = map[key];
      final text = (value?.toString() ?? '').trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  LyricLine? _parseMapLikeLyricString(String raw) {
    final timeMatch = RegExp(r'timeMs\s*:\s*(-?\d+)').firstMatch(raw);
    final textMatch = RegExp(r'text\s*:\s*(.+?)(\}|$)').firstMatch(raw);
    if (textMatch == null) return null;

    var text = textMatch.group(1)!.trim();
    if (text.length >= 2) {
      final startsWithQuote = text.startsWith('"') || text.startsWith("'");
      final endsWithQuote = text.endsWith('"') || text.endsWith("'");
      if (startsWithQuote && endsWithQuote) {
        text = text.substring(1, text.length - 1).trim();
      }
    }
    if (text.isEmpty) return null;

    final timeMs =
        timeMatch != null ? int.tryParse(timeMatch.group(1)!) ?? -1 : -1;
    return LyricLine(timeMs: timeMs, text: text);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  // ─── تبويبة "الشائعة" ─────────────────────────────────────────────────
  /// الشائعة = المقاطع المشغّلة فقط، مرتبة بالأحدث تشغيلًا ثم الأكثر تشغيلًا.
  List<AudioTrack> get popularTracks {
    if (_audio.isEmpty) return const [];
    final list = _audio
        .where((t) => (_playCounts[t.id] ?? 0) > 0)
        .toList(growable: false);
    list.sort((a, b) {
      final ra = _lastPlayedAt[a.id] ?? 0;
      final rb = _lastPlayedAt[b.id] ?? 0;
      if (ra != rb) return rb.compareTo(ra); // الأحدث تشغيلًا أولاً

      final pa = _playCounts[a.id] ?? 0;
      final pb = _playCounts[b.id] ?? 0;
      if (pa != pb) return pb.compareTo(pa); // الأكثر تشغيلاً أولاً
      return b.dateAdded.compareTo(a.dateAdded); // ثم الأحدث إضافة
    });
    return list.take(50).toList();
  }

  /// أحدث الإضافات للمكتبة.
  List<AudioTrack> get recentTracks {
    final list = [..._audio];
    list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    return list;
  }

  List<AudioTrack> get favoriteTracks =>
      _audio.where((t) => _favoriteIds.contains(t.id)).toList();

  /// تجميع الأغاني حسب الفنان.
  Map<String, List<AudioTrack>> get tracksByArtist {
    final map = <String, List<AudioTrack>>{};
    for (final t in _audio) {
      map.putIfAbsent(t.displayArtist, () => []).add(t);
    }
    return map;
  }

  // ─── حفظ/استعادة المحلي ──────────────────────────────────────────────
  Future<void> _restoreLocalPrefs() async {
    final p = await SharedPreferences.getInstance();
    _favoriteIds = (p.getStringList('fav_ids') ?? const []).toSet();

    final raw = p.getStringList('play_counts') ?? const [];
    _playCounts = {
      for (final e in raw)
        if (e.contains('|'))
          e.split('|').first: int.tryParse(e.split('|').last) ?? 0
    };

    final rawLastPlayed = p.getStringList('last_played_at') ?? const [];
    _lastPlayedAt = {
      for (final e in rawLastPlayed)
        if (e.contains('|'))
          e.split('|').first: int.tryParse(e.split('|').last) ?? 0
    };

    _lyricsAvailableTrackKeys.addAll(
      p.getStringList(_lyricsAvailableTracksKey) ?? const <String>[],
    );
  }

  Future<void> _persistFavorites() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('fav_ids', _favoriteIds.toList());
  }

  Future<void> _persistAvailableLyricsKeys() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _lyricsAvailableTracksKey,
      _lyricsAvailableTrackKeys.toList(growable: false),
    );
  }

  Future<void> _bumpPlayCount(String id) async {
    _playCounts[id] = (_playCounts[id] ?? 0) + 1;
    _lastPlayedAt[id] = DateTime.now().millisecondsSinceEpoch;

    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      'play_counts',
      _playCounts.entries.map((e) => '${e.key}|${e.value}').toList(),
    );
    await p.setStringList(
      'last_played_at',
      _lastPlayedAt.entries.map((e) => '${e.key}|${e.value}').toList(),
    );

    notifyListeners();
  }
}
