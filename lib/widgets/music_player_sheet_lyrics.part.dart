// ignore_for_file: deprecated_member_use

part of 'music_player_sheet.dart';

// ============================================================
// ثوابت تصميم صفحة الكلمات (لون واحد مرجعي لكل العناصر).
// ============================================================
class _LyricsTheme {
  const _LyricsTheme._();

  static const Color accent = Color(0xFFF4642B);
  static const Color accentSoft = Color(0xFFE8783C);
  static const Color background = Color(0xFF0A0709);

  static final Color panel = Colors.white.withOpacity(0.045);
  static final Color panelBorder = Colors.white.withOpacity(0.09);
  static final Color idleLine = Colors.white.withOpacity(0.38);
  static final Color chipIdleBorder = Colors.white.withOpacity(0.16);
}

// تبويبات الصفحة: الكلمات أو التفاصيل.
enum _LyricsTab { lyrics, details }

// صفحة كلمات الأغنية الكاملة.
class _LyricsPage extends StatefulWidget {
  final String trackId;
  final String trackTitle;
  final String trackArtist;
  final String? albumArtUri;
  final List<LyricLine> initialLines;

  const _LyricsPage({
    required this.trackId,
    required this.trackTitle,
    required this.trackArtist,
    required this.albumArtUri,
    required this.initialLines,
  });

  @override
  State<_LyricsPage> createState() => _LyricsPageState();
}

// إدارة حالة صفحة الكلمات: تزامن، تمرير، وتحديث.
class _LyricsPageState extends State<_LyricsPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  List<LyricLine> _lines = const [];
  List<GlobalKey> _lineKeys = const [];

  bool _changed = false;
  int _active = -1;

  _LyricsTab _tab = _LyricsTab.lyrics;

  // حالة مرآة من المشغل، للتحديث الانتقائي فقط.
  int _lastPositionMs = -1;
  bool _lastPlaying = false;

  // قيمة السحب اليدوي لشريط التقدم (null = يتبع المشغل).
  double? _dragValue;

  // نبض الموجة الصوتية بجانب السطر النشط.
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _setLines(List<LyricLine>.from(widget.initialLines));

    final snapshot = MediaService.instance.snapshot;
    _lastPlaying = snapshot.playing;
    _active = _resolveActiveIndex(snapshot.positionMs, snapshot.durationMs);
    if (_lastPlaying) _waveController.repeat();

    MediaService.instance.addListener(_onTick);

    // أول تمركز يحتاج انتهاء أول إطار حتى تتكوّن مفاتيح الأسطر.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActiveLine());
  }

  @override
  void dispose() {
    MediaService.instance.removeListener(_onTick);
    _waveController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // كل سطر يحتاج مفتاحًا خاصًا لتتمكن الصفحة من تمركزه بدقة.
  void _setLines(List<LyricLine> value) {
    _lines = value;
    _lineKeys = List<GlobalKey>.generate(value.length, (_) => GlobalKey());
  }

  // ============================================================
  // التزامن مع المشغل
  // ============================================================

  void _onTick() {
    if (!mounted) return;
    final s = MediaService.instance.snapshot;

    final nextActive = _resolveActiveIndex(s.positionMs, s.durationMs);
    final activeChanged = nextActive != _active;
    final playingChanged = s.playing != _lastPlaying;
    // إعادة البناء عند كل إطار للموضع مكلفة بلا داعٍ؛ عتبة 200ms تكفي
    // لسلاسة شريط التقدم مع تقليل الإطارات المهدورة.
    final positionMoved = (s.positionMs - _lastPositionMs).abs() >= 200;

    if (!activeChanged && !playingChanged && !positionMoved) return;

    if (playingChanged) {
      if (s.playing) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }

    _lastPositionMs = s.positionMs;
    _lastPlaying = s.playing;

    setState(() => _active = nextActive);

    if (activeChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerActiveLine());
    }
  }

  /// تحديد السطر النشط.
  ///
  /// الكلمات المُوقّتة تُحسم بالطابع الزمني. أما غير المُوقّتة فتُوزّع على
  /// طول الأغنية بالتناسب، فيبقى هناك سطر نشط يتحرك بدل تجميد كل الأسطر.
  int _resolveActiveIndex(int positionMs, int durationMs) {
    if (_lines.isEmpty) return -1;

    final hasSynced = _lines.any((l) => l.timeMs >= 0);
    if (!hasSynced) {
      if (durationMs <= 0) return 0;
      final ratio = (positionMs / durationMs).clamp(0.0, 1.0);
      // num.clamp() نوعها الساكن num، لذا toInt() ضرورية وإلا فشل التصريف.
      return (ratio * (_lines.length - 1))
          .round()
          .clamp(0, _lines.length - 1)
          .toInt();
    }

    var active = -1;
    for (var i = 0; i < _lines.length; i++) {
      final t = _lines[i].timeMs;
      if (t < 0) continue;
      if (positionMs >= t) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  /// تمركز السطر النشط في منتصف الصندوق.
  ///
  /// الطريقة السابقة كانت تربط إزاحة التمرير بنسبة التقدّم الكلية، وهي تنحرف
  /// كلما اختلفت أطوال الأسطر (سطر يلتف لسطرين يفسد الحساب). التمركز عبر
  /// مفتاح السطر نفسه دقيق دائمًا، ويعمل لأن القائمة مبنية بالكامل
  /// (SingleChildScrollView) فسياق كل سطر متاح حتى خارج الشاشة.
  void _centerActiveLine() {
    if (!mounted || _tab != _LyricsTab.lyrics) return;
    if (_active < 0 || _active >= _lineKeys.length) return;

    final ctx = _lineKeys[_active].currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  String _fmt(int ms) {
    if (ms <= 0) return '00:00';
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  AudioTrack? _resolveTrack() {
    for (final t in MediaService.instance.audioTracks) {
      if (t.id == widget.trackId) return t;
    }
    return null;
  }

  AudioTrack _fallbackTrack() => AudioTrack(
        id: widget.trackId,
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
      );

  Future<String?> _lazyArt() async {
    final track = _resolveTrack() ?? _fallbackTrack();
    return MediaService.instance.fetchAlbumArtUriForTrack(track);
  }

  // ============================================================
  // إجراءات
  // ============================================================

  Future<void> _showSearchOptions() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF120D10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              _providerTile('Chrome', 'assets/icons/google.png', 'google'),
              _providerTile('Genius', 'assets/icons/genius.jpeg', 'genius'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLyricsSearch(String provider) async {
    final title = _cleanQueryText(widget.trackTitle);
    final artist = _cleanQueryText(widget.trackArtist);
    final encoded = Uri.encodeComponent('$title $artist lyrics'.trim());

    Uri url;
    switch (provider) {
      case 'google':
        url = Uri.parse('https://www.google.com/search?q=$encoded');
        break;
      case 'genius':
        url = Uri.parse('https://genius.com/search?q=$encoded');
        break;
      default:
        url = Uri.parse('https://www.google.com/search?q=$encoded');
    }

    await const MethodChannel('app.media.commands').invokeMethod<bool>(
      'openExternalUrl',
      {
        'url': url.toString(),
        'preferChrome': provider == 'google',
      },
    );
  }

  /// ترجمة الكلمات عبر Google Translate.
  ///
  /// النص يُقتطع لأن الروابط الطويلة جدًا تُرفض من بعض المتصفحات؛ الاقتطاع
  /// عند حدّ آمن أفضل من فتح رابط مكسور.
  Future<void> _openTranslate() async {
    if (_lines.isEmpty) {
      _toast('لا توجد كلمات لترجمتها');
      return;
    }

    var text = _lines.map((e) => e.text).join('\n');
    const limit = 1200;
    if (text.length > limit) text = '${text.substring(0, limit)}…';

    final url = Uri.parse(
      'https://translate.google.com/?sl=auto&tl=ar&op=translate'
      '&text=${Uri.encodeComponent(text)}',
    );

    await const MethodChannel('app.media.commands').invokeMethod<bool>(
      'openExternalUrl',
      {'url': url.toString(), 'preferChrome': true},
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1B1216),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _providerTile(String title, String assetPath, String provider) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          assetPath,
          width: 30,
          height: 30,
          fit: BoxFit.contain,
        ),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        _openLyricsSearch(provider);
      },
    );
  }

  String _cleanQueryText(String value) {
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

  Future<void> _openEditLyrics() async {
    final edited = await Navigator.of(context).push<List<LyricLine>>(
      MaterialPageRoute(
        builder: (_) => _EditLyricsPage(initialLines: _lines),
      ),
    );
    if (!mounted || edited == null) return;

    await MediaService.instance.saveCustomLyrics(widget.trackId, edited);
    if (!mounted) return;
    setState(() {
      _setLines(edited);
      _changed = true;
      _active = -1;
    });
  }

  Future<void> _deleteLyrics() async {
    await MediaService.instance.clearCustomLyrics(widget.trackId);
    if (!mounted) return;
    setState(() {
      _setLines(const []);
      _changed = true;
      _active = -1;
    });
  }

  Future<void> _openEqualizer() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _EqualizerPage()),
    );
  }

  Future<void> _togglePlayPause() async {
    final s = MediaService.instance.snapshot;
    if (s.playing) {
      await MediaService.instance.pause();
    } else {
      await MediaService.instance.play();
    }
  }

  // ============================================================
  // البناء
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final snapshot = MediaService.instance.snapshot;
    final track = _resolveTrack();

    final durationMs =
        snapshot.durationMs > 0 ? snapshot.durationMs : (track?.duration ?? 0);
    final positionMs =
        snapshot.positionMs.clamp(0, math.max(durationMs, 0)).toInt();

    return Scaffold(
      backgroundColor: _LyricsTheme.background,
      body: Stack(
        children: [
          // الخلفية: غلاف الألبوم مموّه، ثم توهج دافئ يوحّد مزاج الصفحة.
          Positioned.fill(
            child: AlbumArt(
              uri: widget.albumArtUri,
              size: 1200,
              radius: 0,
              lazyFetchUri: _lazyArt,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
              child: Container(color: Colors.black.withOpacity(0.72)),
            ),
          ),
          Positioned.fill(child: _buildGlow()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTrackCard(durationMs),
                const SizedBox(height: 4),
                Expanded(
                  child: _tab == _LyricsTab.lyrics
                      ? _buildLyricsPanel(snapshot.playing)
                      : _buildDetailsPanel(track, durationMs),
                ),
                _buildPlayerBar(positionMs, durationMs, snapshot.playing),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // توهج برتقالي ناعم: من الزاوية العلوية ومن مركز الصفحة.
  Widget _buildGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.85, -0.85),
                  radius: 1.05,
                  colors: [
                    _LyricsTheme.accent.withOpacity(0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.15, 0.15),
                  radius: 0.95,
                  colors: [
                    _LyricsTheme.accentSoft.withOpacity(0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
            // نُرجع _changed كما كان، فالصفحة الأم تعتمد عليه لإعادة التحميل.
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          const Expanded(
            child: Text(
              'كلمات الأغنية',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF161013),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _openEditLyrics();
                  break;
                case 'search':
                  _showSearchOptions();
                  break;
                case 'delete':
                  _deleteLyrics();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('تعديل الكلمات',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem<String>(
                value: 'search',
                child: Text('بحث عبر الإنترنت',
                    style: TextStyle(color: Colors.white)),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child:
                    Text('حذف الكلمات', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(int durationMs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildArtWithBadge(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trackTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.trackArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _LyricsTheme.accentSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(durationMs),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _tabChip(
                        label: 'الكلمات',
                        icon: Icons.subject_rounded,
                        tab: _LyricsTab.lyrics,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _tabChip(
                        label: 'التفاصيل',
                        icon: Icons.music_note_rounded,
                        tab: _LyricsTab.details,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtWithBadge() {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AlbumArt(
                uri: widget.albumArtUri,
                size: 220,
                radius: 16,
                fallbackImage: 'assets/images/Sonva_album.png',
                lazyFetchUri: _lazyArt,
              ),
            ),
          ),
          // شارة المعادل: مختصر مرئي وزر وظيفي في الوقت نفسه.
          Positioned(
            right: 6,
            bottom: 6,
            child: GestureDetector(
              onTap: _openEqualizer,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required IconData icon,
    required _LyricsTab tab,
  }) {
    final selected = _tab == tab;
    return InkWell(
      onTap: () {
        if (_tab == tab) return;
        setState(() => _tab = tab);
        if (tab == _LyricsTab.lyrics) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _centerActiveLine());
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected
              ? _LyricsTheme.accent.withOpacity(0.13)
              : Colors.transparent,
          border: Border.all(
            color: selected ? _LyricsTheme.accent : _LyricsTheme.chipIdleBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? _LyricsTheme.accent : Colors.white70,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? _LyricsTheme.accent : Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // لوحة الكلمات
  // ============================================================

  Widget _buildLyricsPanel(bool playing) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _LyricsTheme.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _LyricsTheme.panelBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: _lines.isEmpty ? _buildEmptyState() : _buildLyricsList(playing),
    );
  }

  Widget _buildLyricsList(bool playing) {
    return RawScrollbar(
      controller: _scrollController,
      thumbColor: _LyricsTheme.accent,
      trackColor: Colors.white.withOpacity(0.10),
      trackBorderColor: Colors.transparent,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 3.5,
      radius: const Radius.circular(4),
      child: SingleChildScrollView(
        controller: _scrollController,
        // حشوة رأسية كبيرة تسمح للسطر الأول والأخير بالوصول إلى المنتصف.
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 120),
        child: Column(
          children: [
            for (var i = 0; i < _lines.length; i++)
              _buildLyricLine(i, i == _active, playing),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricLine(int index, bool active, bool playing) {
    final text = Text(
      _lines[index].text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: active ? Colors.white : _LyricsTheme.idleLine,
        fontSize: active ? 25 : 17.5,
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        height: 1.32,
      ),
    );

    return Padding(
      key: _lineKeys[index],
      padding: EdgeInsets.symmetric(vertical: active ? 14 : 11),
      child: active
          ? Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildWave(playing, false),
                    Expanded(child: text),
                    _buildWave(playing, true),
                  ],
                ),
                const SizedBox(height: 10),
                _buildDots(),
              ],
            )
          : text,
    );
  }

  // موجة صوتية صغيرة تحفّ السطر النشط، تنبض فقط أثناء التشغيل.
  Widget _buildWave(bool playing, bool mirrored) {
    return Padding(
      padding:
          EdgeInsets.only(left: mirrored ? 10 : 0, right: mirrored ? 0 : 10),
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (_, __) => CustomPaint(
          size: const Size(30, 22),
          painter: _LyricsWavePainter(
            phase: _waveController.value,
            mirrored: mirrored,
            active: playing,
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(3, (i) {
        final on = i == 1;
        return Container(
          width: on ? 7 : 6,
          height: on ? 7 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? _LyricsTheme.accent : Colors.white.withOpacity(0.22),
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 54,
              color: Colors.white.withOpacity(0.28),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد كلمات لهذه الأغنية',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            _lyricsActionButton(
              icon: Icons.search,
              title: 'بحث عبر الإنترنت',
              onTap: _showSearchOptions,
              filled: true,
            ),
            const SizedBox(height: 12),
            _lyricsActionButton(
              icon: Icons.edit_outlined,
              title: 'إضافة الكلمات يدويًا',
              onTap: _openEditLyrics,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // لوحة التفاصيل
  // ============================================================

  Widget _buildDetailsPanel(AudioTrack? track, int durationMs) {
    final rows = <List<String>>[
      ['العنوان', widget.trackTitle],
      ['الفنان', widget.trackArtist.isEmpty ? '—' : widget.trackArtist],
      ['الألبوم', (track?.album.isNotEmpty ?? false) ? track!.album : '—'],
      ['المدة', _fmt(durationMs)],
      [
        'اسم الملف',
        (track?.displayName.isNotEmpty ?? false) ? track!.displayName : '—',
      ],
      ['الحجم', _formatSize(track?.size ?? 0)],
      ['أُضيف في', _formatDate(track?.dateAdded ?? 0)],
      ['المسار', (track?.path?.isNotEmpty ?? false) ? track!.path! : '—'],
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: _LyricsTheme.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _LyricsTheme.panelBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        itemCount: rows.length,
        separatorBuilder: (_, __) => Divider(
          height: 22,
          color: Colors.white.withOpacity(0.06),
        ),
        itemBuilder: (_, i) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  rows[i][0],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13.5,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  rows[i][1],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '—';
    const mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _formatDate(int value) {
    if (value <= 0) return '—';
    // MediaStore يخزّن DATE_ADDED بالثواني، لكن بعض المصادر ترسل ميلي ثانية.
    final ms = value < 100000000000 ? value * 1000 : value;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  // ============================================================
  // شريط التشغيل السفلي
  // ============================================================

  Widget _buildPlayerBar(int positionMs, int durationMs, bool playing) {
    final hasDuration = durationMs > 0;
    final progress = hasDuration
        ? (positionMs / durationMs).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final value = _dragValue ?? progress;
    final shownMs = hasDuration && _dragValue != null
        ? (_dragValue! * durationMs).round()
        : positionMs;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(_fmt(shownMs), style: _timeStyle()),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: _LyricsTheme.accent,
                    inactiveTrackColor: Colors.white.withOpacity(0.18),
                    thumbColor: _LyricsTheme.accent,
                    overlayColor: _LyricsTheme.accent.withOpacity(0.16),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 15),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: value,
                    // تعطيل السحب بلا مدة معروفة يمنع قفزات وهمية.
                    onChanged: hasDuration
                        ? (v) => setState(() => _dragValue = v)
                        : null,
                    onChangeEnd: hasDuration
                        ? (v) async {
                            await MediaService.instance
                                .seekTo((v * durationMs).round());
                            if (mounted) setState(() => _dragValue = null);
                          }
                        : null,
                  ),
                ),
              ),
              Text(_fmt(durationMs), style: _timeStyle()),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleButton(
                icon: Icons.translate_rounded,
                onTap: _openTranslate,
              ),
              _plainButton(
                icon: Icons.skip_previous_rounded,
                onTap: MediaService.instance.previous,
              ),
              _buildPlayPause(playing),
              _plainButton(
                icon: Icons.skip_next_rounded,
                onTap: MediaService.instance.next,
              ),
              _circleButton(
                icon: Icons.ios_share_rounded,
                onTap: MediaService.instance.shareCurrent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _timeStyle() => TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      );

  Widget _buildPlayPause(bool playing) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _LyricsTheme.accent,
          boxShadow: [
            BoxShadow(
              color: _LyricsTheme.accent.withOpacity(0.42),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _plainButton({required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 36),
    );
  }

  Widget _lyricsActionButton({
    String? iconAsset,
    IconData? icon,
    required String title,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  filled ? _LyricsTheme.accent : Colors.white.withOpacity(0.18),
            ),
            color: filled
                ? _LyricsTheme.accent.withOpacity(0.14)
                : Colors.white.withOpacity(0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconAsset != null)
                Image.asset(iconAsset, width: 22, height: 22)
              else if (icon != null)
                Icon(
                  icon,
                  color: filled ? _LyricsTheme.accent : Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: filled ? _LyricsTheme.accent : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// رسّام الموجة الصوتية المصغّرة بجانب السطر النشط.
// الاسم مُسبَّق بـ Lyrics لتجنّب أي تعارض مع رسّامات الموجة في أجزاء المكتبة
// الأخرى (صفحة القص تحتوي رسّام موجة خاصًا بها).
class _LyricsWavePainter extends CustomPainter {
  final double phase;
  final bool mirrored;
  final bool active;

  const _LyricsWavePainter({
    required this.phase,
    required this.mirrored,
    required this.active,
  });

  static const List<double> _weights = [0.45, 0.75, 1.0, 0.62, 0.34];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _LyricsTheme.accent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    const count = 5;
    final gap = size.width / count;
    final centerY = size.height / 2;

    for (var i = 0; i < count; i++) {
      final idx = mirrored ? count - 1 - i : i;
      // أثناء التوقف تُجمّد الأعمدة على أطوالها الأساسية بدل الاهتزاز.
      final wobble = active
          ? 0.55 + 0.45 * math.sin((phase * 2 * math.pi) + idx * 0.9)
          : 0.6;
      final h = size.height * _weights[idx] * wobble;
      final x = gap * i + gap / 2;
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LyricsWavePainter old) =>
      old.phase != phase || old.active != active || old.mirrored != mirrored;
}

// صفحة تحرير الكلمات يدويًا.
class _EditLyricsPage extends StatefulWidget {
  final List<LyricLine> initialLines;

  const _EditLyricsPage({required this.initialLines});

  @override
  State<_EditLyricsPage> createState() => _EditLyricsPageState();
}

// منطق إدخال وتحليل وحفظ الكلمات من صفحة التحرير.
class _EditLyricsPageState extends State<_EditLyricsPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialLines.map((e) => e.text).join('\n'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LyricLine> _parseLines(String raw) {
    final out = <LyricLine>[];
    for (final row in raw.split(RegExp(r'\r?\n'))) {
      final line = row.trim();
      if (line.isEmpty) continue;

      final matches = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]')
          .allMatches(line)
          .toList();
      final text = line
          .replaceAll(RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]'), '')
          .trim();
      if (text.isEmpty) continue;

      if (matches.isEmpty) {
        out.add(LyricLine(timeMs: -1, text: text));
        continue;
      }

      for (final m in matches) {
        final min = int.tryParse(m.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '0') ?? 0;
        final frac = m.group(3) ?? '0';
        final ms = frac.length == 1
            ? (int.tryParse(frac) ?? 0) * 100
            : frac.length == 2
                ? (int.tryParse(frac) ?? 0) * 10
                : int.tryParse(frac.substring(0, 3)) ?? 0;
        out.add(
            LyricLine(timeMs: (min * 60000) + (sec * 1000) + ms, text: text));
      }
    }

    final hasSynced = out.any((e) => e.timeMs >= 0);
    if (hasSynced) {
      out.sort((a, b) {
        if (a.timeMs < 0 && b.timeMs < 0) return 0;
        if (a.timeMs < 0) return 1;
        if (b.timeMs < 0) return -1;
        return a.timeMs.compareTo(b.timeMs);
      });
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LyricsTheme.background,
      appBar: AppBar(
        backgroundColor: _LyricsTheme.background,
        title: const Text('تعديل الكلمات'),
        actions: [
          TextButton(
            onPressed: () {
              final lines = _parseLines(_controller.text);
              Navigator.of(context).pop(lines);
            },
            child: const Text(
              'حفظ',
              style: TextStyle(
                color: _LyricsTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          cursorColor: _LyricsTheme.accent,
          style: const TextStyle(color: Colors.white, height: 1.45),
          decoration: InputDecoration(
            hintText:
                'اكتب الكلمات...\nصيغة التزامن الاختيارية: [00:15.20] نص السطر',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: _LyricsTheme.accent),
            ),
          ),
        ),
      ),
    );
  }
}
