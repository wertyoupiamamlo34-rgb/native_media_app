class LyricLine {
  final int timeMs;
  final String text;

  const LyricLine({
    required this.timeMs,
    required this.text,
  });

  bool get isSynced => timeMs >= 0;
}
