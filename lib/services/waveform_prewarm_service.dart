import 'dart:async';
import 'dart:convert';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_track.dart';

class WaveformPrewarmService {
  WaveformPrewarmService._();

  static const int _sampleCount = 180;
  static const String _waveformCachePrefix = 'waveform_cache_v1_';
  static const String _preparedSourcesKey = 'waveform_prepared_sources_v1';

  static final Map<String, List<double>> _waveformMemoryCache =
      <String, List<double>>{};
  static final Map<String, Future<void>> _waveformPending =
      <String, Future<void>>{};

  static bool _backgroundJobRunning = false;

  static bool get supportsExtraction {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static String normalizeSource(String source) {
    if (source.startsWith('file://')) {
      final normalized = Uri.tryParse(source)?.toFilePath();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return source;
  }

  static String sourceForTrack(AudioTrack track) {
    final source = (track.path != null && track.path!.isNotEmpty)
        ? track.path!
        : track.uri;
    return normalizeSource(source);
  }

  static Future<List<double>?> getWaveform(String source) async {
    if (!supportsExtraction) return null;
    final normalized = normalizeSource(source);

    final inMemory = _waveformMemoryCache[normalized];
    if (inMemory != null && inMemory.isNotEmpty) return inMemory;

    final fromPrefs = await _loadCachedWaveformFor(normalized);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _waveformMemoryCache[normalized] = fromPrefs;
      return fromPrefs;
    }
    return null;
  }

  static Future<void> prewarmWaveform(String source) {
    if (!supportsExtraction) return Future.value();

    final normalizedSource = normalizeSource(source);
    final fromMemory = _waveformMemoryCache[normalizedSource];
    if (fromMemory != null && fromMemory.isNotEmpty) {
      return Future.value();
    }

    final pending = _waveformPending[normalizedSource];
    if (pending != null) return pending;

    final job = () async {
      final fromPrefs = await _loadCachedWaveformFor(normalizedSource);
      if (fromPrefs != null && fromPrefs.isNotEmpty) {
        _waveformMemoryCache[normalizedSource] = fromPrefs;
        return;
      }

      final controller = WaveformExtractionController();
      try {
        final data = await controller.extractWaveformData(
          path: normalizedSource,
          noOfSamples: _sampleCount,
        );
        if (data.isNotEmpty) {
          _waveformMemoryCache[normalizedSource] = data;
          unawaited(_saveCachedWaveformFor(normalizedSource, data));
        }
      } on PlatformException catch (e) {
        debugPrint(
            '[WaveformPrewarmService] extraction failed for $normalizedSource: ${e.message}');
      }
    }();

    _waveformPending[normalizedSource] = job;
    job.whenComplete(() => _waveformPending.remove(normalizedSource));
    return job;
  }

  static Future<void> prewarmForNewTracks(Iterable<AudioTrack> tracks) async {
    if (!supportsExtraction || _backgroundJobRunning) return;
    _backgroundJobRunning = true;

    try {
      final list = tracks.toList(growable: false);
      if (list.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final prepared =
          (prefs.getStringList(_preparedSourcesKey) ?? const <String>[])
              .toSet();

      final pendingSources = <String>[];
      for (final track in list) {
        final source = sourceForTrack(track);
        if (source.isEmpty || prepared.contains(source)) continue;
        pendingSources.add(source);
      }

      if (pendingSources.isEmpty) return;

      for (var i = 0; i < pendingSources.length; i++) {
        final source = pendingSources[i];
        await prewarmWaveform(source).timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        );
        final ready = await getWaveform(source);
        if (ready != null && ready.isNotEmpty) {
          prepared.add(source);
        }

        if (i % 8 == 0 || i == pendingSources.length - 1) {
          await prefs.setStringList(
            _preparedSourcesKey,
            prepared.toList(growable: false),
          );
        }
      }
    } catch (e) {
      debugPrint('[WaveformPrewarmService] prewarm skipped: $e');
    } finally {
      _backgroundJobRunning = false;
    }
  }

  static String _waveformCacheKeyFor(String source) {
    final normalized = source.trim();
    final encoded = base64UrlEncode(utf8.encode('$normalized|$_sampleCount'));
    return '$_waveformCachePrefix$encoded';
  }

  static Future<List<double>?> _loadCachedWaveformFor(String source) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_waveformCacheKeyFor(source));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final values = decoded
          .map((value) =>
              value is num ? value.toDouble() : double.tryParse('$value'))
          .whereType<double>()
          .toList(growable: false);
      return values.isEmpty ? null : values;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCachedWaveformFor(
    String source,
    List<double> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_waveformCacheKeyFor(source), jsonEncode(data));
    } catch (_) {
      // Ignore cache write failures; waveform data is still usable for this session.
    }
  }
}
