import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeExoPlayerState {
  const NativeExoPlayerState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isReady = false,
    this.error,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isReady;
  final String? error;

  factory NativeExoPlayerState.fromMap(Map<dynamic, dynamic> map) {
    return NativeExoPlayerState(
      position:
          Duration(milliseconds: (map['positionMs'] as num? ?? 0).toInt()),
      duration:
          Duration(milliseconds: (map['durationMs'] as num? ?? 0).toInt()),
      isPlaying: map['isPlaying'] as bool? ?? false,
      isReady: map['isReady'] as bool? ?? false,
      error: map['error']?.toString(),
    );
  }
}

class NativeExoPlayerView extends StatefulWidget {
  const NativeExoPlayerView({
    super.key,
    required this.uri,
    required this.onStateChanged,
  });

  final String uri;
  final ValueChanged<NativeExoPlayerState> onStateChanged;

  @override
  State<NativeExoPlayerView> createState() => NativeExoPlayerViewState();
}

class NativeExoPlayerViewState extends State<NativeExoPlayerView> {
  MethodChannel? _channel;

  Future<void> play() async {
    await _channel?.invokeMethod('play');
  }

  Future<void> pause() async {
    await _channel?.invokeMethod('pause');
  }

  Future<void> seekTo(Duration position) async {
    await _channel
        ?.invokeMethod('seekTo', {'positionMs': position.inMilliseconds});
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _channel?.invokeMethod('setPlaybackSpeed', {'speed': speed});
  }

  Future<NativeExoPlayerState> getPlaybackState() async {
    final result = await _channel?.invokeMethod('getPlaybackState');
    if (result is Map) {
      return NativeExoPlayerState.fromMap(Map<dynamic, dynamic>.from(result));
    }
    return const NativeExoPlayerState();
  }

  Future<void> disposePlayer() async {
    await _channel?.invokeMethod('dispose');
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(
        child: Text('Android ExoPlayer only',
            style: TextStyle(color: Colors.white70)),
      );
    }

    return AndroidView(
      viewType: 'native_exo_player_view',
      creationParams: {'uri': widget.uri},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('app.native_exo_player/$id');
    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'onStateChanged') {
        final state = NativeExoPlayerState.fromMap(
          Map<dynamic, dynamic>.from(call.arguments as Map),
        );
        if (mounted) {
          widget.onStateChanged(state);
        }
      }
    });
  }

  @override
  void dispose() {
    disposePlayer();
    super.dispose();
  }
}
