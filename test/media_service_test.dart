import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_media_app/models/audio_track.dart';
import 'package:native_media_app/services/media_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('app.media.commands'), null);
  });

  test('caches an empty artwork result so native lookup is not repeated',
      () async {
    var calls = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.media.commands'),
            (MethodCall call) async {
      calls += 1;
      expect(call.method, 'getAudioArtwork');
      return '';
    });

    const track = AudioTrack(
      id: '42',
      uri: 'content://media/external/audio/media/42',
      title: 'Demo track',
      artist: 'Demo artist',
      album: 'Demo album',
      albumId: '',
      albumArtUri: '',
      duration: 120000,
      displayName: 'Demo track',
      path: '/tmp/demo-empty.mp3',
      dateAdded: 0,
      size: 1024,
    );

    final first = await MediaService.instance.fetchAlbumArtUriForTrack(track);
    final second = await MediaService.instance.fetchAlbumArtUriForTrack(track);

    expect(first, isEmpty);
    expect(second, isEmpty);
    expect(calls, 1);
  });

  test('reuses the same artwork lookup for the same file even with a new id',
      () async {
    var calls = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.media.commands'),
            (MethodCall call) async {
      calls += 1;
      expect(call.method, 'getAudioArtwork');
      return '';
    });

    const originalTrack = AudioTrack(
      id: '42',
      uri: 'content://media/external/audio/media/42',
      title: 'Demo track',
      artist: 'Demo artist',
      album: 'Demo album',
      albumId: '',
      albumArtUri: '',
      duration: 120000,
      displayName: 'Demo track',
      path: '/tmp/demo.mp3',
      dateAdded: 0,
      size: 1024,
    );
    const replacementTrack = AudioTrack(
      id: '43',
      uri: 'content://media/external/audio/media/42',
      title: 'Demo track',
      artist: 'Demo artist',
      album: 'Demo album',
      albumId: '',
      albumArtUri: '',
      duration: 120000,
      displayName: 'Demo track',
      path: '/tmp/demo.mp3',
      dateAdded: 0,
      size: 1024,
    );

    await MediaService.instance.fetchAlbumArtUriForTrack(originalTrack);
    await MediaService.instance.fetchAlbumArtUriForTrack(replacementTrack);

    expect(calls, 1);
  });

  test('counts successfully loaded lyrics for the welcome screen', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('app.media.commands'),
            (MethodCall call) async {
      if (call.method == 'loadLyrics') {
        return [
          {'text': 'Hello world', 'timeMs': 0},
        ];
      }
      return null;
    });

    final lyrics = await MediaService.instance.loadLyrics(
      trackId: 'track-1',
      title: 'Demo track',
      artist: 'Demo artist',
      durationMs: 120000,
      displayName: 'Demo track',
    );

    expect(lyrics, isNotEmpty);
    expect(MediaService.instance.lyricsFilesCount, 1);
  });
}
