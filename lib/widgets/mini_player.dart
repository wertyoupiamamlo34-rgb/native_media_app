// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:native_media_app/widgets/music_player_sheet.dart';

import '../models/audio_track.dart';
import '../services/media_service.dart';
import 'album_art.dart';

/// مشغّل مصغّر في أسفل الشاشة بتصميم زجاجي (Glassmorphism)،
/// يظهر فقط عند وجود مسار قيد التشغيل، ويدعم السحب للأعلى لفتح المشغّل الكامل.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  // ── متغيرات السحب ──────────────────────────────────────────
  double _dragStartY = 0;
  double _dragCurrentY = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MediaService.instance,
      builder: (context, _) {
        final svc = MediaService.instance;
        final snap = svc.snapshot;
        final track = snap.track is AudioTrack
            ? snap.track as AudioTrack
            : snap.track is Map
                ? AudioTrack.fromMap(snap.track as Map<dynamic, dynamic>)
                : null;

        if (track == null || (snap.currentTitle ?? '').isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildFullMiniPlayer(context, svc, snap, track);
      },
    );
  }

  // ── MiniPlayer الكامل مع دعم السحب للأعلى ─────────────────────
  Widget _buildFullMiniPlayer(
    BuildContext context,
    MediaService svc,
    dynamic snap,
    AudioTrack? track,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (details) {
          _dragStartY = details.globalPosition.dy;
          _dragCurrentY = _dragStartY;
        },
        onVerticalDragUpdate: (details) {
          _dragCurrentY = details.globalPosition.dy;
        },
        onVerticalDragEnd: (details) {
          final dragDistance = _dragStartY - _dragCurrentY;
          final velocity = -(details.primaryVelocity ?? 0);

          if (dragDistance > 60 || velocity > 400) {
            _openFullPlayer(context);
          }
        },
        child: _buildMiniPlayer(context, svc, snap, track),
      ),
    );
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    MediaService svc,
    dynamic snap,
    AudioTrack? track,
  ) {
    Theme.of(context);

    final title = (snap.currentTitle ?? '').toString().trim().isNotEmpty
        ? snap.currentTitle as String
        : 'Unknown Track';

    final artist = (snap.currentArtist ?? '').toString().trim().isNotEmpty
        ? snap.currentArtist as String
        : 'Unknown Artist';

    final progress = snap.durationMs > 0
        ? (snap.positionMs / snap.durationMs).clamp(0.0, 1.0)
        : 0.0;

    final resolvedArtUri = (snap.currentAlbumArt?.isNotEmpty ?? false)
        ? snap.currentAlbumArt as String
        : svc.albumArtUriForTrack(track ??
            const AudioTrack(
              id: '',
              uri: '',
              title: '',
              artist: '',
              album: '',
              albumId: '',
              albumArtUri: '',
              duration: 0,
              displayName: '',
              path: null,
              dateAdded: 0,
              size: 0,
            ));

    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 2, color: Colors.grey.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.black.withOpacity(0.25),
                ],
              ),
            ),
            child: Stack(
              children: [
                // ── مقبض السحب العلوي ─────────────────────
                const Positioned(
                  top: 2,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: 36,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── المحتوى الرئيسي ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    // vertical: 2,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openFullPlayer(context),
                        child: _buildAlbumArt(
                            context, svc, snap, track, resolvedArtUri),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openFullPlayer(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MarqueeText(
                                text: title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              if (artist.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                _MarqueeText(
                                  text: artist,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _buildControls(context, svc, snap),
                    ],
                  ),
                ),

                // ── شريط التقدم السفلي ─────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(
    BuildContext context,
    MediaService svc,
    dynamic snap,
    AudioTrack? track,
    String resolvedArtUri,
  ) {
    final hasResolvedArt = resolvedArtUri.trim().isNotEmpty;

    return Hero(
      tag: 'player_album_art_placeholder',
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: hasResolvedArt || track != null
              ? AlbumArt(
                  uri: resolvedArtUri,
                  size: 54,
                  radius: 12,
                  lazyFetchUri: track != null
                      ? () => svc.fetchAlbumArtUriForTrack(track)
                      : null,
                )
              : Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/Sonva_album.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    MediaService svc,
    dynamic snap,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: svc.previous,
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
        ),
        // ✅ Play / Pause
        _buildPlayPauseButton(context, svc, snap),

        // ✅ Next
        IconButton(
          onPressed: svc.next,
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton(
    BuildContext context,
    MediaService svc,
    dynamic snap,
  ) {
    final isPlaying = snap.playing as bool;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.4),
            Theme.of(context).primaryColor.withOpacity(0.7),
            Theme.of(context).primaryColor.withOpacity(1),
          ],
        ),
        border: Border.all(
          width: 2,
          color: isDark
              ? Colors.black.withOpacity(0.5)
              : Colors.grey.withOpacity(0.8),
        ),
      ),
      child: IconButton(
        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        color: Colors.white,
        iconSize: 20,
        onPressed: () {
          if (isPlaying) {
            svc.pause();
          } else {
            svc.play();
          }
        },
      ),
    );
  }

  // ── فتح المشغّل الكامل بانتقال Slide-Up ─────────────────────────
  void _openFullPlayer(BuildContext context) {
    if (!mounted) return;

    // عند جاهزية الشاشة الكاملة، استبدل ما سبق بهذا:
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const MusicPlayerSheet();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  static const double _gap = 24;
  static const Duration _duration = Duration(seconds: 7);

  late final AnimationController _controller;
  double _textWidth = 0;
  double _availableWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureText());
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureText());
    }
  }

  void _measureText() {
    if (!mounted) return;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final available = context.size?.width ?? 0;
    final textWidth = painter.width;

    if (_availableWidth == available && _textWidth == textWidth) return;

    setState(() {
      _availableWidth = available;
      _textWidth = textWidth;
    });

    if (_textWidth > _availableWidth && _availableWidth > 0) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final shouldScroll = _textWidth > width && width > 0;

          if (!shouldScroll) {
            return Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            );
          }

          final totalDistance = _textWidth + _gap;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final offset = -totalDistance * progress;
              return SizedBox(
                width: width,
                height: _textWidth > 0 ? widget.style.fontSize! * 1.35 : 0,
                child: ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: offset,
                        top: 0,
                        width: _textWidth,
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: widget.style,
                        ),
                      ),
                      Positioned(
                        left: offset + totalDistance,
                        top: 0,
                        width: _textWidth,
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: widget.style,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
