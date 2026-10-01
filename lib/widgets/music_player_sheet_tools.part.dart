// ignore_for_file: deprecated_member_use

part of 'music_player_sheet.dart';

// صفحة إعدادات المعادل الصوتي.
class _EqualizerPage extends StatefulWidget {
  const _EqualizerPage();

  @override
  State<_EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<_EqualizerPage>
    with TickerProviderStateMixin {
  static const String _eqEnabledKey = 'eq_enabled';
  static const String _eqMasterVolumeKey = 'eq_master_volume';
  static const String _eqBassKey = 'eq_bass_db';
  static const String _eqTrebleKey = 'eq_treble_db';
  static const String _eqVirtualizerEnabledKey = 'eq_virtualizer_enabled';
  static const String _eqVirtualBassKey = 'eq_virtual_bass';
  static const String _eqSelectedPresetKey = 'eq_selected_preset';
  static const String _eqHasCustomPresetKey = 'eq_has_custom_preset';

  static const List<String> _bandOrder = [
    '32Hz',
    '64Hz',
    '125Hz',
    '250Hz',
    '500Hz',
    '1kHz',
    '2kHz',
    '4kHz',
    '8kHz',
    '16kHz',
  ];

  final MediaService _mediaService = MediaService.instance;

  final Map<String, double> bands = {
    '32Hz': 0,
    '64Hz': 0,
    '125Hz': 0,
    '250Hz': 0,
    '500Hz': 0,
    '1kHz': 0,
    '2kHz': 0,
    '4kHz': 0,
    '8kHz': 0,
    '16kHz': 0,
  };

  String selectedPreset = 'Flat';
  Map<String, double>? _savedCustomBands;
  bool isEnabled = true;
  double masterVolume = 0.7;
  double bass = 0;
  double treble = 0;

  double reverb = 0;
  double echo = 0;
  double surround = 0;
  double compressor = 0;
  double virtualBass = 0;
  double clarity = 0;
  bool spatialAudioEnabled = false;
  bool bassBoostEnabled = false;
  bool virtualizerEnabled = false;

  late AnimationController _waveController;
  late TabController _tabController;
  Timer? _bandSyncTimer;
  Timer? _controlsSyncTimer;
  Timer? _prefsSaveTimer;
  static const int _visualizerBarsCount = 32;

  String? _visualizerTrackId;
  List<double> _visualizerWaveform = const [];
  String? _queuedVisualizerTrackKey;

  // Flutter rendering only: receive precomputed visualizer band levels and peaks.

  AudioTrack? _currentTrackFromSnapshot(dynamic snapshot) {
    final currentIndex = snapshot.currentIndex;
    if (currentIndex < 0 || currentIndex >= _mediaService.audioTracks.length) {
      return null;
    }
    return _mediaService.audioTracks[currentIndex];
  }

  Future<void> _loadVisualizerWaveformFor(dynamic snapshot) async {
    final track = _currentTrackFromSnapshot(snapshot);
    if (track == null) {
      if (_visualizerTrackId != null || _visualizerWaveform.isNotEmpty) {
        setState(() {
          _visualizerTrackId = null;
          _visualizerWaveform = const [];
        });
      }
      return;
    }

    final source = WaveformPrewarmService.sourceForTrack(track);
    if (source.isEmpty) return;

    final trackKey = snapshot.currentTrackId ?? source;
    if (_visualizerTrackId == trackKey && _visualizerWaveform.isNotEmpty) {
      return;
    }

    _visualizerTrackId = trackKey;

    unawaited(WaveformPrewarmService.prewarmWaveform(source));
    final waveform = await WaveformPrewarmService.getWaveform(source);
    if (!mounted || _visualizerTrackId != trackKey) return;
    if (waveform != null && waveform.isNotEmpty) {
      setState(() {
        _visualizerWaveform = waveform;
      });
    }
  }

  void _scheduleVisualizerWaveformLoad(dynamic snapshot) {
    final trackKey = snapshot.currentTrackId ?? '${snapshot.currentIndex}';
    if (_queuedVisualizerTrackKey == trackKey) return;
    _queuedVisualizerTrackKey = trackKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_queuedVisualizerTrackKey != trackKey) return;
      _queuedVisualizerTrackKey = null;
      unawaited(_loadVisualizerWaveformFor(snapshot));
    });
  }

  final List<Map<String, dynamic>> presets = [
    {'name': 'Flat', 'icon': Icons.graphic_eq},
    {'name': 'Rock', 'icon': Icons.music_note},
    {'name': 'Pop', 'icon': Icons.star},
    {'name': 'Jazz', 'icon': Icons.piano},
    {'name': 'Classical', 'icon': Icons.theater_comedy},
    {'name': 'Electronic', 'icon': Icons.electric_bolt},
    {'name': 'Hip Hop', 'icon': Icons.headphones},
    {'name': 'Vocal', 'icon': Icons.mic},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    unawaited(_initializeEqualizerState());
  }

  @override
  void dispose() {
    _bandSyncTimer?.cancel();
    _controlsSyncTimer?.cancel();
    _prefsSaveTimer?.cancel();
    unawaited(_persistEqualizerState());
    _tabController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _initializeEqualizerState() async {
    await _restoreEqualizerState();
    if (!mounted) return;
    await _pushInitialAudioEffects();
  }

  Future<void> _restoreEqualizerState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCustomPreset = prefs.getBool(_eqHasCustomPresetKey) ?? false;

    setState(() {
      isEnabled = prefs.getBool(_eqEnabledKey) ?? isEnabled;
      masterVolume = prefs.getDouble(_eqMasterVolumeKey) ?? masterVolume;
      bass = prefs.getDouble(_eqBassKey) ?? bass;
      treble = prefs.getDouble(_eqTrebleKey) ?? treble;
      virtualizerEnabled =
          prefs.getBool(_eqVirtualizerEnabledKey) ?? virtualizerEnabled;
      virtualBass = prefs.getDouble(_eqVirtualBassKey) ?? virtualBass;
      selectedPreset = prefs.getString(_eqSelectedPresetKey) ?? selectedPreset;

      for (var i = 0; i < _bandOrder.length; i++) {
        final key = _bandOrder[i];
        final bandValue = prefs.getDouble('eq_band_$i');
        if (bandValue != null) {
          bands[key] = bandValue;
        }
      }

      if (hasCustomPreset) {
        _savedCustomBands = <String, double>{};
        for (var i = 0; i < _bandOrder.length; i++) {
          final key = _bandOrder[i];
          final customValue = prefs.getDouble('eq_custom_band_$i');
          _savedCustomBands![key] = customValue ?? bands[key] ?? 0;
        }
        if (!presets.any((preset) => preset['name'] == 'مخصص')) {
          presets.add({'name': 'مخصص', 'icon': Icons.bookmark_added_rounded});
        }
      }
    });
  }

  Future<void> _persistEqualizerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eqEnabledKey, isEnabled);
    await prefs.setDouble(_eqMasterVolumeKey, masterVolume);
    await prefs.setDouble(_eqBassKey, bass);
    await prefs.setDouble(_eqTrebleKey, treble);
    await prefs.setBool(_eqVirtualizerEnabledKey, virtualizerEnabled);
    await prefs.setDouble(_eqVirtualBassKey, virtualBass);
    await prefs.setString(_eqSelectedPresetKey, selectedPreset);

    for (var i = 0; i < _bandOrder.length; i++) {
      final key = _bandOrder[i];
      await prefs.setDouble('eq_band_$i', bands[key] ?? 0);
    }

    final hasCustomPreset = _savedCustomBands != null;
    await prefs.setBool(_eqHasCustomPresetKey, hasCustomPreset);
    if (hasCustomPreset) {
      for (var i = 0; i < _bandOrder.length; i++) {
        final key = _bandOrder[i];
        await prefs.setDouble(
            'eq_custom_band_$i', _savedCustomBands![key] ?? 0);
      }
    }
  }

  void _schedulePrefsSave() {
    _prefsSaveTimer?.cancel();
    _prefsSaveTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(_persistEqualizerState());
    });
  }

  Future<void> _pushInitialAudioEffects() async {
    await _mediaService.setVisualizerAnalysisConfig({
      'fftSize': 2048,
      'hopSize': 512,
      'internalBands': 64,
      'windowType': 'HANN',
      'frequencyScale': 'MEL',
      'minDb': -96.0,
      'maxDb': -12.0,
      'noiseFloorDb': -78.0,
      'compression': 0.32,
      'autoGainTargetDb': -24.0,
    });
    await _mediaService.setEqualizerEnabled(isEnabled);
    await _mediaService.setVolume(masterVolume);
    await _mediaService.setBassBoostDb(bass);
    await _mediaService.setTrebleDb(treble);
    await _mediaService.setVirtualizerEnabled(virtualizerEnabled);
    await _mediaService.setVirtualizerStrength(virtualBass.abs() / 10);
    await _syncAllBands();
  }

  Future<void> _syncAllBands() async {
    for (var i = 0; i < _bandOrder.length; i++) {
      final level = bands[_bandOrder[i]] ?? 0;
      await _mediaService.setEqualizerBandLevel(
        bandIndex: i,
        levelDb: level,
      );
    }
  }

  void _scheduleBandSync(String label, double level) {
    if (!isEnabled) return;
    _bandSyncTimer?.cancel();
    _bandSyncTimer = Timer(const Duration(milliseconds: 120), () {
      final index = _bandOrder.indexOf(label);
      if (index < 0) return;
      unawaited(_mediaService.setEqualizerBandLevel(
        bandIndex: index,
        levelDb: level,
      ));
    });
  }

  void _scheduleControlsSync() {
    if (!isEnabled) return;
    _controlsSyncTimer?.cancel();
    _controlsSyncTimer = Timer(const Duration(milliseconds: 140), () {
      unawaited(_mediaService.setVolume(masterVolume));
      unawaited(_mediaService.setBassBoostDb(bass));
      unawaited(_mediaService.setTrebleDb(treble));
      unawaited(_mediaService.setVirtualizerEnabled(virtualizerEnabled));
      unawaited(_mediaService.setVirtualizerStrength(virtualBass.abs() / 10));
    });
  }

  Future<void> _toggleAllTools(bool enabled) async {
    if (enabled) {
      await _pushInitialAudioEffects();
      return;
    }

    _bandSyncTimer?.cancel();
    _controlsSyncTimer?.cancel();
    await _mediaService.setEqualizerEnabled(false);
    await _mediaService.setBassBoostDb(0);
    await _mediaService.setTrebleDb(0);
    await _mediaService.setVirtualizerEnabled(false);
    await _mediaService.setVirtualizerStrength(0);
  }

  void applyPreset(String preset) {
    setState(() {
      selectedPreset = preset;
      switch (preset) {
        case 'مخصص':
          if (_savedCustomBands != null) {
            _setValues(
              _bandOrder
                  .map((band) => _savedCustomBands![band] ?? 0)
                  .toList(growable: false),
            );
          }
          break;
        case 'Rock':
          _setValues([5, 3, -2, -1, 1, 2, 3, 4, 3, 2]);
          break;
        case 'Pop':
          _setValues([2, 3, 4, 3, 0, -1, -2, -1, 2, 3]);
          break;
        case 'Jazz':
          _setValues([3, 2, 1, 2, -1, -2, 0, 1, 2, 3]);
          break;
        case 'Classical':
          _setValues([4, 3, 2, 0, -1, -1, 0, 2, 3, 4]);
          break;
        case 'Electronic':
          _setValues([6, 4, 2, 0, -2, 2, 0, 2, 4, 5]);
          break;
        case 'Hip Hop':
          _setValues([6, 5, 3, 1, -1, -1, 1, 2, 3, 4]);
          break;
        case 'Vocal':
          _setValues([0, -1, -2, 1, 3, 4, 4, 3, 1, 0]);
          break;
        default:
          _setValues([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      }
    });
    _schedulePrefsSave();
    unawaited(_syncAllBands());
  }

  void _setValues(List<double> values) {
    for (var i = 0; i < _bandOrder.length && i < values.length; i++) {
      bands[_bandOrder[i]] = values[i];
    }
  }

  void _saveCustomPreset() {
    setState(() {
      _savedCustomBands = Map<String, double>.from(bands);
      final customPresetIndex = presets.indexWhere(
        (preset) => preset['name'] == 'مخصص',
      );
      if (customPresetIndex == -1) {
        presets.add({'name': 'مخصص', 'icon': Icons.bookmark_added_rounded});
      }
      selectedPreset = 'مخصص';
    });
    _schedulePrefsSave();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم حفظ الترددات في تخصيصك'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF00D4FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F3A), Color(0xFF0D1226)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: IgnorePointer(
                  ignoring: !isEnabled,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isEnabled ? 1 : 0.45,
                    child: Column(
                      children: [
                        _buildVisualizerSection(),
                        _buildTabBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildEqualizerTab(),
                              _buildSoundEffectsTab()
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.5), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF00D4FF),
              size: 24,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.asset('assets/images/Circle.png', width: 40),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image(
                      width: 60,
                      image: AssetImage('assets/images/sonva_w.png'),
                    ),
                  ],
                ),
                Text(
                  'Professional Equalizer',
                  style: TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (val) {
              setState(() => isEnabled = val);
              unawaited(_toggleAllTools(val));
              _schedulePrefsSave();
            },
            activeColor: const Color(0xFF00D4FF),
            activeTrackColor: const Color(0xFF00D4FF).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _mediaService]),
      builder: (context, child) {
        final snapshot = _mediaService.snapshot;
        final trackKey = snapshot.currentTrackId ?? '${snapshot.currentIndex}';
        if (_visualizerTrackId != trackKey || _visualizerWaveform.isEmpty) {
          _scheduleVisualizerWaveformLoad(snapshot);
        }

        final isPlaying = isEnabled && snapshot.playing;
        final realtimeBins = _mediaService.visualizerBins;
        final realtimePeaks = _mediaService.visualizerPeaks;
        final hasRealtimeBins = realtimeBins.length == _visualizerBarsCount;
        final averageLevel = hasRealtimeBins
            ? realtimeBins.reduce((value, element) => value + element) /
                realtimeBins.length
            : 0.0;
        final borderPulse = (0.3 + (averageLevel * 0.55)).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          height: 108,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00E1FF).withOpacity(borderPulse),
              width: 1 + borderPulse * 0.9,
            ),
            boxShadow: borderPulse > 0.35
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF3D6E)
                          .withOpacity(borderPulse * 0.2),
                      blurRadius: 14 * borderPulse,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth = constraints.maxWidth / _visualizerBarsCount;
                final barWidth = slotWidth.clamp(3.5, 8.0);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(_visualizerBarsCount, (index) {
                    final barLevel = isPlaying && hasRealtimeBins
                        ? realtimeBins[index].clamp(0.0, 1.0)
                        : 0.0;
                    final peakLevel = hasRealtimeBins &&
                            realtimePeaks.length == realtimeBins.length
                        ? realtimePeaks[index].clamp(0.0, 1.0)
                        : 0.0;

                    const segmentCount = 12;
                    final activeSegments =
                        (barLevel * segmentCount).ceil().clamp(0, segmentCount);
                    final peakSegment = (peakLevel * segmentCount)
                        .ceil()
                        .clamp(1, segmentCount);
                    final glowIntensity = (barLevel * 0.85).clamp(0.0, 1.0);

                    // Thermal color gradient: cold (cyan) -> warm (yellow) -> hot (red)
                    Color getThermalColor(double t) {
                      final clampedT = t.clamp(0.0, 1.0);
                      const coldColor = Color(0xFF00C8FF);
                      const warmColor = Color(0xFFFFC247);
                      const hotColor = Color(0xFFFF3D2E);
                      if (clampedT < 0.55) {
                        return Color.lerp(
                            coldColor, warmColor, clampedT / 0.55)!;
                      }
                      return Color.lerp(
                          warmColor, hotColor, (clampedT - 0.55) / 0.45)!;
                    }

                    return SizedBox(
                      width: slotWidth,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: barWidth,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.bottomCenter,
                          child: LayoutBuilder(
                            builder: (context, barConstraints) {
                              const segmentGap = 1.2;
                              final rawHeight = (barConstraints.maxHeight -
                                      ((segmentCount - 1) * segmentGap)) /
                                  segmentCount;
                              final segmentHeight = rawHeight.clamp(3.0, 6.0);

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children:
                                    List.generate(segmentCount, (segmentIndex) {
                                  final fromBottom =
                                      segmentCount - segmentIndex;
                                  final isActive = fromBottom <= activeSegments;
                                  final isPeak = peakLevel > 0.02 &&
                                      fromBottom == peakSegment;
                                  final activeGradientT = activeSegments <= 1
                                      ? 0.0
                                      : ((fromBottom - 1) /
                                              (activeSegments - 1))
                                          .clamp(0.0, 1.0);

                                  Color segmentColor;
                                  if (isPeak) {
                                    segmentColor =
                                        Colors.white.withOpacity(0.95);
                                  } else if (isActive) {
                                    segmentColor =
                                        getThermalColor(activeGradientT);
                                  } else {
                                    segmentColor =
                                        Colors.white.withOpacity(0.15);
                                  }

                                  return Container(
                                    width: barWidth,
                                    height: segmentHeight,
                                    margin: EdgeInsets.only(
                                      bottom: segmentIndex == segmentCount - 1
                                          ? 0
                                          : segmentGap,
                                    ),
                                    decoration: BoxDecoration(
                                      color: segmentColor,
                                      borderRadius: BorderRadius.circular(1.5),
                                      boxShadow: (isActive || isPeak)
                                          ? (isPeak
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.white
                                                        .withOpacity(0.95),
                                                    blurRadius: 8,
                                                    spreadRadius: 0.6,
                                                  ),
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF8EDDFF,
                                                    ).withOpacity(0.6),
                                                    blurRadius: 14,
                                                    spreadRadius: 1.2,
                                                  ),
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: getThermalColor(
                                                      activeGradientT,
                                                    ).withOpacity(
                                                      (0.22 +
                                                              (glowIntensity *
                                                                  0.55))
                                                          .clamp(0.0, 0.95),
                                                    ),
                                                    blurRadius: 3.5,
                                                  ),
                                                ])
                                          : const [],
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA600FF), Color(0xFF00D4FF)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'المعادل'),
          Tab(text: 'تأثيرات الصوت'),
        ],
      ),
    );
  }

  Widget _buildEqualizerTab() {
    return Column(
      children: [
        _buildPresetsSection(),
        _buildEqualizerSection(),
      ],
    );
  }

  Widget _buildSoundEffectsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildControlsSection(),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildPresetsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 30,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                final isSelected = selectedPreset == preset['name'];
                return GestureDetector(
                  onTap: () => applyPreset(preset['name']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 12),
                    width: 70,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFA600FF), Color(0xFF263346)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00D4FF)
                            : Colors.white.withOpacity(0.2),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00D4FF).withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          preset['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizerSection() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1F3A).withOpacity(0.8),
              const Color(0xFF0D1226).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.03),
              offset: const Offset(-10, -10),
              blurRadius: 20,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              offset: const Offset(10, 10),
              blurRadius: 25,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D4FF).withOpacity(0.3),
                        const Color(0xFF00D4FF).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF00D4FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'نطاقات التردد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: bands.entries.map((entry) {
                return _buildNeumorphicFrequencySlider(entry.key, entry.value);
              }).toList(),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveCustomPreset,
                icon: const Icon(Icons.save_as_rounded),
                label: const Text('حفظ التخصيص الحالي'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: const Color(0xFF0D1226),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicFrequencySlider(String label, double value) {
    Color getFrequencyColor(String freq) {
      if (freq.contains('32') || freq.contains('64')) {
        return const Color(0xFFFF006E);
      } else if (freq.contains('125') ||
          freq.contains('250') ||
          freq.contains('500')) {
        return const Color(0xFFFF6B00);
      } else if (freq.contains('1k') || freq.contains('2k')) {
        return const Color(0xFF00D4FF);
      } else if (freq.contains('4k') || freq.contains('8k')) {
        return const Color(0xFF8B5CF6);
      } else {
        return const Color(0xFFA600FF);
      }
    }

    final accentColor = getFrequencyColor(label);
    final percentage = (value + 10) / 20;

    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                final delta = -details.delta.dy / 9;
                bands[label] = (bands[label]! + delta).clamp(-10.0, 10.0);
                selectedPreset = 'مخصص';
              });
              _scheduleBandSync(label, bands[label]!);
              _schedulePrefsSave();
            },
            child: Container(
              height: 200,
              width: 14,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0D1226),
                    Color(0xFF1A1F3A),
                    Color(0xFF0D1226),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.02),
                    offset: const Offset(0, -4),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    top: 99,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...List.generate(5, (index) {
                    final topPosition = 40.0 * index;
                    return Positioned(
                      top: topPosition,
                      left: 4,
                      right: 4,
                      child: Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    );
                  }),
                  Positioned(
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: percentage * 200,
                      width: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            accentColor.withOpacity(0.3),
                            accentColor.withOpacity(0.6),
                            accentColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: (1 - percentage) * 200 - 20,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFF1A1F3A), Color(0xFF0D1226)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.05),
                            offset: const Offset(-4, -4),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.8),
                            offset: const Offset(4, 4),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: accentColor.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accentColor,
                                accentColor.withOpacity(0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 7,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 25,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.25),
                  accentColor.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 4),
              ],
            ),
            child: Text(
              '${value.toStringAsFixed(0)}dB',
              style: TextStyle(
                color: accentColor,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      height: 450,
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1F3A).withOpacity(0.8),
            const Color(0xFF0D1226).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: _buildNeumorphicKnob(
              'مستوى الصوت الرئيسي',
              Icons.volume_up_rounded,
              masterVolume,
              0,
              1,
              (val) {
                setState(() => masterVolume = val);
                _scheduleControlsSync();
                _schedulePrefsSave();
              },
              '${(masterVolume * 100).toInt()}%',
              const Color(0xFF00D4FF),
              size: 120,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _buildNeumorphicKnob(
                  'الجهير',
                  Icons.graphic_eq_rounded,
                  bass,
                  -10,
                  10,
                  (val) {
                    setState(() => bass = val);
                    _scheduleControlsSync();
                    _schedulePrefsSave();
                  },
                  '${bass.toStringAsFixed(0)} dB',
                  const Color(0xFFFF006E),
                  size: 110,
                  compactHeader: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildNeumorphicKnob(
                  'الحادة',
                  Icons.show_chart_rounded,
                  treble,
                  -10,
                  10,
                  (val) {
                    setState(() => treble = val);
                    _scheduleControlsSync();
                    _schedulePrefsSave();
                  },
                  '${treble.toStringAsFixed(0)} dB',
                  const Color(0xFF8B5CF6),
                  size: 110,
                  compactHeader: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNeumorphicKnob(
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    String displayValue,
    Color accentColor, {
    double size = 160,
    bool compactHeader = false,
  }) {
    final percentage = (value - min) / (max - min);
    final angle = (percentage * 270) - 135;
    final center = Offset(size / 2, size / 2);

    final inner1 = size * 0.75;
    final inner2 = size * 0.56;
    final iconSize = size * 0.22;
    final needleH = size * 0.28;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(compactHeader ? 8 : 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.3),
                          accentColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: accentColor,
                      size: compactHeader ? 18 : 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compactHeader ? 13 : 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compactHeader ? 12 : 16,
                vertical: compactHeader ? 6 : 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.25),
                    accentColor.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 8),
                ],
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  color: accentColor,
                  fontSize: compactHeader ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onPanUpdate: (details) {
              final touchPoint = details.localPosition;
              final dx = touchPoint.dx - center.dx;
              final dy = touchPoint.dy - center.dy;
              var normalizedAngle = (math.atan2(dy, dx) * 180 / math.pi) + 90;
              if (normalizedAngle > 180) normalizedAngle -= 360;
              normalizedAngle = normalizedAngle.clamp(-135.0, 135.0);

              final newPercentage = (normalizedAngle + 135) / 270;
              final newValue = min + (newPercentage * (max - min));
              onChanged(newValue.clamp(min, max));
            },
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF1A1F3A), Color(0xFF0D1226)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    offset: const Offset(-8, -8),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: const Offset(8, 8),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(11, (index) {
                    final tickAngle = -135 + (index * 27);
                    final isActive = angle >= tickAngle;
                    return Transform.rotate(
                      angle: tickAngle * math.pi / 180,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: EdgeInsets.only(top: size * 0.06),
                          width: 3,
                          height: index % 2 == 0 ? size * 0.075 : size * 0.05,
                          decoration: BoxDecoration(
                            color: isActive
                                ? accentColor
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.6),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                      ),
                    );
                  }),
                  Container(
                    width: inner1,
                    height: inner1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D1226), Color(0xFF1A1F3A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.7),
                          offset: const Offset(4, 4),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.03),
                          offset: const Offset(-4, -4),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: inner2,
                        height: inner2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withOpacity(0.3),
                              accentColor.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(icon, color: accentColor, size: iconSize),
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: angle * math.pi / 180,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: EdgeInsets.only(top: size * 0.09),
                        width: 6,
                        height: needleH,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [accentColor, accentColor.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.8),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: size * 0.13,
                    height: size * 0.13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [accentColor, accentColor.withOpacity(0.7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.7),
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: size * 0.05,
                        height: size * 0.05,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// صفحة قص المقطع الصوتي.
class _AudioCutterPage extends StatefulWidget {
  final String title;
  final String artist;
  final int durationMs;
  final String? albumArtUri;
  final String source;

  const _AudioCutterPage({
    required this.title,
    required this.artist,
    required this.durationMs,
    this.albumArtUri,
    required this.source,
  });

  @override
  State<_AudioCutterPage> createState() => _AudioCutterPageState();
}

class _AudioCutterPageState extends State<_AudioCutterPage> {
  static const MethodChannel _channel = MethodChannel('sonva/media_store');
  static const double _minTrimSec = 2.0;
  static const double _previewStartupDelaySec = 5.0;
  static final Map<String, RangeValues> _rangeDrafts = <String, RangeValues>{};
  static String normalizeWaveformSource(String source) {
    return source;
  }

  static Future<void> prewarmWaveform(String source) {
    return Future.value();
  }

  double _start = 0;
  double _end = 0;
  double _movingIndicatorSec = 0;
  double _previewWindowStartSec = 0;
  double _previewWindowEndSec = 0;
  bool _isPreviewRunning = false;
  bool _isProcessing = false;
  bool _resumeOnExit = false;
  List<double> _waveformData = const [];
  Timer? _waveformIndicatorTimer;
  Timer? _previewIndicatorStopTimer;
  DateTime? _lastIndicatorTick;
  DateTime? _previewMotionStartAt;

  @override
  void initState() {
    super.initState();
    _resumeOnExit = MediaService.instance.snapshot.playing;
    unawaited(MediaService.instance.pause());
    _restoreDraftRange();
    _resetMovingIndicator();
    _prepareWaveform();
  }

  @override
  void dispose() {
    _waveformIndicatorTimer?.cancel();
    _previewIndicatorStopTimer?.cancel();
    _storeDraftRange(_start, _end);
    if (_resumeOnExit) {
      unawaited(MediaService.instance.play());
    }
    super.dispose();
  }

  String get _draftKey {
    final source = normalizeWaveformSource(widget.source).trim();
    return source.isEmpty ? '${widget.title}|${widget.artist}' : source;
  }

  void _restoreDraftRange() {
    final draft = _rangeDrafts[_draftKey];
    final max = _durationSec.toDouble();
    if (draft == null) {
      _start = 0;
      _end = max;
      return;
    }

    var start = draft.start.clamp(0.0, max).toDouble();
    var end = draft.end.clamp(0.0, max).toDouble();
    if (end <= start) {
      end = (start + _minTrimSec).clamp(0.0, max).toDouble();
      if (end <= start) {
        start = 0;
        end = max;
      }
    }

    if ((end - start) < _minTrimSec) {
      end = (start + _minTrimSec).clamp(0.0, max).toDouble();
      if ((end - start) < _minTrimSec) {
        start = (end - _minTrimSec).clamp(0.0, max).toDouble();
      }
    }

    _start = start;
    _end = end;
  }

  void _storeDraftRange(double start, double end) {
    _rangeDrafts[_draftKey] = RangeValues(start, end);
  }

  void _resetMovingIndicator() {
    _movingIndicatorSec = _indicatorWindowStartSec;
    _lastIndicatorTick = DateTime.now();
  }

  double get _indicatorWindowStartSec {
    return _isPreviewRunning ? _previewWindowStartSec : _start;
  }

  double get _indicatorWindowEndSec {
    return _isPreviewRunning ? _previewWindowEndSec : _end;
  }

  void _startMovingIndicator() {
    _waveformIndicatorTimer?.cancel();
    _lastIndicatorTick = DateTime.now();
    _waveformIndicatorTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        if (!mounted) return;

        final now = DateTime.now();
        final last = _lastIndicatorTick ?? now;
        _lastIndicatorTick = now;

        final motionStart = _previewMotionStartAt;
        if (motionStart != null && now.isBefore(motionStart)) {
          if (_movingIndicatorSec != _indicatorWindowStartSec) {
            setState(() {
              _movingIndicatorSec = _indicatorWindowStartSec;
            });
          }
          return;
        }

        final deltaSec = now.difference(last).inMilliseconds / 1000.0;
        final windowStart = _indicatorWindowStartSec;
        final windowEnd = _indicatorWindowEndSec;
        final rangeLen =
            (windowEnd - windowStart).clamp(0.0, _durationSec.toDouble());
        if (rangeLen <= 0) {
          if (_movingIndicatorSec != windowStart) {
            setState(() {
              _movingIndicatorSec = windowStart;
            });
          }
          return;
        }

        var next = _movingIndicatorSec + deltaSec;
        if (next > windowEnd) {
          final overflow = (next - windowStart) % rangeLen;
          next = windowStart + overflow;
        }
        if (next < windowStart) {
          next = windowStart;
        }

        setState(() {
          _movingIndicatorSec = next;
        });
      },
    );
  }

  void _startPreviewIndicatorSession({
    required int startSec,
    required int endSec,
  }) {
    _isPreviewRunning = true;
    _previewWindowStartSec = startSec.toDouble();
    _previewWindowEndSec = endSec.toDouble();
    _previewIndicatorStopTimer?.cancel();
    _previewMotionStartAt = DateTime.now().add(
      Duration(milliseconds: (_previewStartupDelaySec * 1000).toInt()),
    );
    _resetMovingIndicator();
    _startMovingIndicator();

    final rangeSec = (_previewWindowEndSec - _previewWindowStartSec)
        .clamp(_minTrimSec, _durationSec.toDouble());
    _previewIndicatorStopTimer = Timer(
      Duration(
          milliseconds: ((rangeSec + _previewStartupDelaySec) * 1000).round()),
      () {
        if (!mounted) return;
        _isPreviewRunning = false;
        _stopMovingIndicator(resetToStart: true);
      },
    );
  }

  void _stopMovingIndicator({bool resetToStart = false}) {
    _waveformIndicatorTimer?.cancel();
    _waveformIndicatorTimer = null;
    _previewIndicatorStopTimer?.cancel();
    _previewIndicatorStopTimer = null;
    _previewMotionStartAt = null;
    _lastIndicatorTick = null;
    if (resetToStart && mounted) {
      setState(() {
        _movingIndicatorSec = _start;
      });
    }
  }

  void _prepareWaveform() {
    final source = normalizeWaveformSource(widget.source);
    final seed =
        '${widget.title}|${widget.artist}|$source|${widget.durationMs}';
    _waveformData = _buildFakeWaveform(seed, count: 180);
  }

  List<double> _buildFakeWaveform(String seed, {int count = 180}) {
    var hash = 2166136261;
    for (final codeUnit in seed.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }

    var state = hash == 0 ? 1 : hash;
    final values = List<double>.filled(count, 0.2, growable: false);
    for (var i = 0; i < count; i++) {
      state = (1103515245 * state + 12345) & 0x7fffffff;
      final n = state / 0x7fffffff;
      final waveA = (i % 29) / 28.0;
      final waveB = ((i + (hash % 17)) % 11) / 10.0;
      final v = (0.18 + (n * 0.55) + (waveA * 0.2) + (waveB * 0.15))
          .clamp(0.08, 1.0)
          .toDouble();
      values[i] = v;
    }
    return values;
  }

  int get _durationSec {
    final sec = widget.durationMs ~/ 1000;
    return sec <= 0 ? 1 : sec;
  }

  bool get _isValidRange {
    final s = _start.round();
    final e = _end.round();
    if (e <= s) return false;
    if ((e - s) < _minTrimSec) return false;
    return true;
  }

  String _formatSec(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _runTrimAndAction(_TrimAction action) async {
    if (_isProcessing) return;

    if (!_isValidRange) {
      _showToast('⚠️ اختر نطاق صحيح للقص', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    final startSec = _start.round();
    final endSec = _end.round();

    if (action == _TrimAction.preview) {
      _startPreviewIndicatorSession(startSec: startSec, endSec: endSec);
    }

    try {
      final actionName =
          action == _TrimAction.preview ? 'preview' : action.name;
      final args = <String, dynamic>{
        'path': normalizeWaveformSource(widget.source),
        'title': widget.title,
        'artist': widget.artist,
        'startSec': startSec,
        'endSec': endSec,
        'action': actionName,
      };

      final Map result = await _channel.invokeMethod('trimAudio', args);

      final ok = result['ok'] == true;
      final msg = (result['message'] ?? '').toString();
      final outPath = (result['outputPath'] ?? '').toString();

      if (!mounted) return;

      if (ok) {
        HapticFeedback.lightImpact();
        if (action != _TrimAction.preview && msg.isNotEmpty) {
          _showToast(msg);
        }
        debugPrint('Trim output: $outPath');
      } else {
        if (action == _TrimAction.preview) {
          _isPreviewRunning = false;
          _stopMovingIndicator(resetToStart: true);
        }
        HapticFeedback.heavyImpact();
        _showToast(
          msg.isNotEmpty
              ? msg
              : (action == _TrimAction.preview
                  ? 'المعاينة غير مدعومة حاليًا'
                  : 'فشلت العملية'),
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('trimAudio error: $e');
      if (action == _TrimAction.preview) {
        _isPreviewRunning = false;
        _stopMovingIndicator(resetToStart: true);
      }
      HapticFeedback.heavyImpact();
      _showToast(
        action == _TrimAction.preview
            ? 'تعذر تشغيل المعاينة على هذا الجهاز'
            : 'حدث خطأ أثناء المعالجة',
        isError: true,
      );
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _stopPreviewForRangeUpdate() async {
    if (!_isPreviewRunning) return;

    _isPreviewRunning = false;
    _stopMovingIndicator(resetToStart: true);
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }

    try {
      await _channel.invokeMethod('stopPreview');
    } catch (e) {
      debugPrint('stopPreview error: $e');
    }
  }

  Future<void> _openSaveOptions() async {
    if (_isProcessing || !_isValidRange) return;

    final action = await showModalBottomSheet<_TrimAction>(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Text(
                  'اختر إجراء الحفظ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSaveOptionTile(
                  icon: Icons.save_alt,
                  title: 'حفظ فقط',
                  action: _TrimAction.save,
                ),
                _buildSaveOptionTile(
                  icon: Icons.phone,
                  title: 'تعيين كنغمة رنين',
                  action: _TrimAction.ringtone,
                ),
                _buildSaveOptionTile(
                  icon: Icons.notifications,
                  title: 'تعيين كنغمة للإشعارات',
                  action: _TrimAction.notification,
                ),
                _buildSaveOptionTile(
                  icon: Icons.alarm,
                  title: 'تعيين كنغمة منبه',
                  action: _TrimAction.alarm,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    await _runTrimAndAction(action);
  }

  Widget _buildSaveOptionTile({
    required IconData icon,
    required String title,
    required _TrimAction action,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.white.withOpacity(0.9)),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => Navigator.of(context).pop(action),
    );
  }

  void _showToast(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        backgroundColor:
            isError ? const Color(0xFFFF3B5C) : const Color(0xFF00D9A5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.trim().isEmpty ? 'Unknown' : widget.title;
    final artist = widget.artist.trim().isEmpty ? 'Unknown' : widget.artist;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).cardColor,
                Theme.of(context).cardColor,
                Colors.black.withOpacity(0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              _buildTopBarLikeScreenshot(),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artist,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: (widget.albumArtUri?.isNotEmpty ?? false)
                            ? AlbumArt(
                                uri: widget.albumArtUri,
                                size: 1200,
                                radius: 0,
                                lazyFetchUri: () {
                                  final track = MediaService
                                      .instance.audioTracks
                                      .firstWhere(
                                    (t) => t.albumArtUri == widget.albumArtUri,
                                    orElse: () => const AudioTrack(
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
                                    ),
                                  );
                                  if (track.id.isEmpty) return Future.value('');
                                  return MediaService.instance
                                      .fetchAlbumArtUriForTrack(track);
                                },
                              )
                            : Image.asset(
                                'assets/images/Sonva_album.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              _buildWaveformLikeScreenshot(),
              _buildBottomBarLikeScreenshot(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBarLikeScreenshot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const Spacer(),
          Text(
            'قص الأغنية',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWaveformLikeScreenshot() {
    final dur = _durationSec;
    final startRatio = (_start / dur).clamp(0.0, 1.0).toDouble();
    final endRatio = (_end / dur).clamp(0.0, 1.0).toDouble();
    final indicatorRelativeSec =
        (_movingIndicatorSec - _indicatorWindowStartSec).round().clamp(
            0,
            (_indicatorWindowEndSec - _indicatorWindowStartSec)
                .round()
                .clamp(0, dur));

    const orange = Color(0xFFFF842D);

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'تم تحديد: ${_formatSec((_end - _start).round())}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatSec(_end.round()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatSec(_start.round()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 92,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return CustomPaint(
                          size: Size(c.maxWidth, 92),
                          painter: _FakeWaveformPainter(
                            samples: _waveformData,
                            color: Colors.white.withOpacity(0.62),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final left = 16 + (startRatio * (c.maxWidth - 32));
                      final right = 16 + (endRatio * (c.maxWidth - 32));
                      final rangeLen =
                          (_end - _start).clamp(0.0, dur.toDouble());
                      final progressInRange = rangeLen > 0
                          ? ((_movingIndicatorSec - _start) / rangeLen)
                              .clamp(0.0, 1.0)
                              .toDouble()
                          : 0.0;
                      final center = (left + ((right - left) * progressInRange))
                          .clamp(16.0, c.maxWidth - 16.0);
                      final labelLeft =
                          (center - 26).clamp(4.0, c.maxWidth - 56.0);

                      return Stack(
                        children: [
                          Positioned(
                            left: left,
                            width: (right - left).clamp(0.0, c.maxWidth),
                            top: 0,
                            bottom: 0,
                            child: Container(color: orange.withOpacity(0.5)),
                          ),
                          Positioned(
                            left: center - 1,
                            top: 8,
                            bottom: 8,
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Positioned(
                            left: labelLeft,
                            top: 2,
                            child: Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                _formatSec(indicatorRelativeSec),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          _buildHandle(x: left, color: orange),
                          _buildHandle(x: right, color: orange),
                          _buildBottomDot(x: left, color: orange),
                          _buildBottomDot(x: right, color: orange),
                        ],
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.001,
                    child: RangeSlider(
                      min: 0,
                      max: _durationSec.toDouble(),
                      values: RangeValues(_start, _end),
                      onChangeStart: (_) {
                        if (_isPreviewRunning) {
                          unawaited(_stopPreviewForRangeUpdate());
                        }
                      },
                      onChanged: (_isProcessing && !_isPreviewRunning)
                          ? null
                          : (v) {
                              double start = v.start;
                              double end = v.end;

                              if ((end - start) < _minTrimSec) {
                                if (start != _start) {
                                  start = (end - _minTrimSec).clamp(
                                    0.0,
                                    _durationSec.toDouble(),
                                  );
                                } else {
                                  end = (start + _minTrimSec).clamp(
                                    0.0,
                                    _durationSec.toDouble(),
                                  );
                                }
                              }

                              setState(() {
                                _start = start;
                                _end = end;
                                _movingIndicatorSec = _start;
                              });
                              if (_isPreviewRunning) {
                                _resetMovingIndicator();
                              }
                              _storeDraftRange(start, end);
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle({required double x, required Color color}) {
    return Positioned(
      left: x - 1.5,
      top: 14,
      bottom: 14,
      child: Container(
        width: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildBottomDot({required double x, required Color color}) {
    return Positioned(
      left: x - 6,
      bottom: 10,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildBottomBarLikeScreenshot() {
    final items = [
      // هده ستبقى كماهي
      _BottomItem(
        icon: Icons.play_circle_fill,
        label: 'معاينة',
        onTap: () => _runTrimAndAction(_TrimAction.preview),
      ),
      _BottomItem(
        icon: Icons.save_alt,
        label: 'حفظ',
        onTap: _openSaveOptions,
      ),
    ];

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: items.map((e) {
          final enabled = !_isProcessing && _isValidRange;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.18),
                          Colors.white.withOpacity(0.08),
                        ],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: enabled ? e.onTap : null,
                      icon: Icon(e.icon, size: 20),
                      label: Text(
                        e.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.white.withOpacity(0.55),
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BottomItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _BottomItem({required this.icon, required this.label, required this.onTap});
}

enum _TrimAction { preview, save, ringtone, notification, alarm }

class _FakeWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  _FakeWaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    var maxAmp = 0.0;
    for (final s in samples) {
      final v = s.abs();
      if (v > maxAmp) maxAmp = v;
    }
    if (maxAmp <= 0) return;

    final barCount = samples.length;
    final step = size.width / barCount;
    final stroke = (step * 0.72).clamp(1.2, 2.8);
    final centerY = size.height / 2;

    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      final x = i * step + (step / 2);
      final amp = (samples[i].abs() / maxAmp).clamp(0.08, 1.0);
      final h = amp * size.height * 0.9;
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FakeWaveformPainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}
