// ignore_for_file: deprecated_member_use

part of 'music_player_sheet.dart';

// واجهة المشغل في الوضع الأفقي.
class _LandscapePlayer extends StatelessWidget {
  final AudioTrack track;
  final int positionMs;
  final int durationMs;
  final bool playing;
  final bool isFavorite;
  final int repeatMode;
  final bool shuffleMode;
  final double progressValue;
  final String Function(int ms) formatDuration;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekEnd;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onShuffle;
  final Future<void> Function() onRepeat;
  final Future<void> Function() onFavorite;
  final Future<void> Function() onShare;
  final Future<void> Function() onQueue;
  final Future<void> Function() onSearch;
  final Future<void> Function() onOpenLyrics;
  final Future<void> Function(int index) onQueueItemTap;
  final List<LyricLine> lyrics;
  final int activeLyricsIndex;

  const _LandscapePlayer({
    required this.track,
    required this.positionMs,
    required this.durationMs,
    required this.playing,
    required this.isFavorite,
    required this.repeatMode,
    required this.shuffleMode,
    required this.progressValue,
    required this.formatDuration,
    required this.onSeekStart,
    required this.onSeekEnd,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
    required this.onFavorite,
    required this.onShare,
    required this.onQueue,
    required this.onSearch,
    required this.onOpenLyrics,
    required this.onQueueItemTap,
    required this.lyrics,
    required this.activeLyricsIndex,
  });

  List<Map<String, String>> _queuePreviewItems() {
    final tracks = MediaService.instance.audioTracks;
    if (tracks.isEmpty) {
      return const [
        {'title': 'No tracks', 'duration': '--:--', 'albumArtUri': ''},
      ];
    }

    return tracks.map((track) {
      return {
        'title': track.displayTitle,
        'duration': formatDuration(track.duration),
        'albumArtUri': track.albumArtUri,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 230,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AlbumArt(
                            uri: track.albumArtUri,
                            size: 200,
                            radius: 16,
                            lazyFetchUri: () => MediaService.instance
                                .fetchAlbumArtUriForTrack(track),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: onPrevious,
                                  icon: const Icon(
                                    Icons.skip_previous_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                InkWell(
                                  onTap: onPlayPause,
                                  borderRadius: BorderRadius.circular(26),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFE7B86B),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: const Color(0xFFE7B86B),
                                      size: 28,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: onNext,
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _LandscapeMarqueeText(
                            text: track.displayArtist,
                            style: const TextStyle(
                              color: Color(0xFFE7B86B),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          _LandscapeMarqueeText(
                            text: track.displayTitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 240,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: _CurvedQueueList(
                      queue: _queuePreviewItems(),
                      onItemTap: onQueueItemTap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenLyrics,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: _LandscapeLyricsView(
                        lines: lyrics,
                        activeIndex: activeLyricsIndex,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    activeTrackColor: const Color(0xFFE7B86B),
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: const Color(0xFFE7B86B),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: progressValue,
                    min: 0,
                    max: 1,
                    onChanged: onSeekStart,
                    onChangeEnd: onSeekEnd,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      formatDuration(positionMs),
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const Spacer(),
                    Text(
                      formatDuration(durationMs),
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      onPressed: onRepeat,
                      icon: Icon(
                        repeatMode == 1
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: repeatMode == 0
                            ? Colors.white60
                            : const Color(0xFFE7B86B),
                      ),
                    ),
                    IconButton(
                      onPressed: onFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? const Color(0xFFE65E69)
                            : Colors.white60,
                      ),
                    ),
                    IconButton(
                      onPressed: onShuffle,
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: shuffleMode
                            ? const Color(0xFFE7B86B)
                            : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CurvedQueueList extends StatelessWidget {
  final List<Map<String, String>> queue;
  final ValueChanged<int> onItemTap;

  const _CurvedQueueList({required this.queue, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: CustomPaint(
                size: Size(20, height),
                painter: _ArcPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final item = queue[index];
                  final isCurrent = index == 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onItemTap(index),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFFE7B86B).withOpacity(0.18)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFFE7B86B)
                                  : Colors.white.withOpacity(0.06),
                              width: isCurrent ? 1 : 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              AlbumArt(
                                uri: item['albumArtUri'],
                                size: 38,
                                radius: 6,
                                fallbackImage: 'assets/images/Sonva_album.png',
                                lazyFetchUri: () {
                                  AudioTrack? queueTrack;
                                  for (final candidate
                                      in MediaService.instance.audioTracks) {
                                    if (candidate.id == item['trackId']) {
                                      queueTrack = candidate;
                                      break;
                                    }
                                  }
                                  return queueTrack != null
                                      ? MediaService.instance
                                          .fetchAlbumArtUriForTrack(queueTrack)
                                      : Future.value('');
                                },
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      item['title'] ?? 'Unknown',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: isCurrent
                                            ? const Color(0xFFE7B86B)
                                            : Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['duration'] ?? '--:--',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00E7B86B), Color(0xFFE7B86B), Color(0x00E7B86B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.quadraticBezierTo(
      size.width * 2.5,
      size.height / 2,
      size.width / 2,
      size.height,
    );
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = const Color(0xFFE7B86B);
    canvas.drawCircle(
      Offset(size.width / 2 + 20, size.height / 2),
      3,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// عرض مختصر لكلمات الأغنية داخل واجهة الوضع الأفقي.
class _LandscapeLyricsView extends StatelessWidget {
  final List<LyricLine> lines;
  final int activeIndex;

  const _LandscapeLyricsView({required this.lines, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Center(
        child: Text('No lyrics found', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final active = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            lines[i].text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? const Color(0xFFE7B86B) : Colors.white,
              fontSize: active ? 24 : 20,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              height: 1.6,
            ),
          ),
        );
      },
    );
  }
}

class _LandscapeMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const _LandscapeMarqueeText({
    required this.text,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  State<_LandscapeMarqueeText> createState() => _LandscapeMarqueeTextState();
}

class _LandscapeMarqueeTextState extends State<_LandscapeMarqueeText>
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
  void didUpdateWidget(covariant _LandscapeMarqueeText oldWidget) {
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
              textAlign: widget.textAlign,
              style: widget.style,
            );
          }

          final lineHeight = (widget.style.fontSize ?? 13) * 1.35;
          final totalDistance = _textWidth + _gap;
          final alignOffset = switch (widget.textAlign) {
            TextAlign.center => (width - _textWidth) / 2,
            TextAlign.end || TextAlign.right => width - _textWidth,
            _ => 0.0,
          };

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final offset = alignOffset - (totalDistance * progress);
              return SizedBox(
                width: width,
                height: lineHeight,
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
                        textAlign: widget.textAlign,
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
                        textAlign: widget.textAlign,
                        style: widget.style,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
