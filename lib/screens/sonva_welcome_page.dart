// ignore_for_file: prefer_interpolation_to_compose_strings, deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_media_app/screens/home_screen.dart';
import 'package:native_media_app/services/app_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_media_app/services/library_preparation_controller.dart';
import 'package:native_media_app/widgets/accent_color_section.dart';

// ============================================================
// ONBOARDING STATE MODEL
// ============================================================
class SonvaOnboardingState {
  final String name;
  final String language;
  final Color accentColor;

  final double libraryProgress;
  final LibraryPreparationStatus preparationStatus;

  final int songsCount;
  final int artistsCount;
  final int videosCount;
  final int lyricsFilesCount;

  const SonvaOnboardingState({
    this.name = '',
    this.language = 'العربية',
    this.accentColor = const Color(0xFFFF9D2E),
    this.libraryProgress = 0.0,
    this.preparationStatus = LibraryPreparationStatus.scanning,
    this.songsCount = 0,
    this.artistsCount = 0,
    this.videosCount = 0,
    this.lyricsFilesCount = 0,
  });

  SonvaOnboardingState copyWith({
    String? name,
    String? language,
    Color? accentColor,
    double? libraryProgress,
    LibraryPreparationStatus? preparationStatus,
    int? songsCount,
    int? artistsCount,
    int? videosCount,
    int? lyricsFilesCount,
  }) {
    return SonvaOnboardingState(
      name: name ?? this.name,
      language: language ?? this.language,
      accentColor: accentColor ?? this.accentColor,
      libraryProgress: libraryProgress ?? this.libraryProgress,
      preparationStatus: preparationStatus ?? this.preparationStatus,
      songsCount: songsCount ?? this.songsCount,
      artistsCount: artistsCount ?? this.artistsCount,
      videosCount: videosCount ?? this.videosCount,
      lyricsFilesCount: lyricsFilesCount ?? this.lyricsFilesCount,
    );
  }
}

// (LibraryPreparationState is defined in the controller file)

// Use app-wide theme from lib/theme/app_theme.dart via Theme.of(context)

// ============================================================
// STEP NUMBER + VERTICAL LINE WIDGET
// ============================================================

class _StepConnector extends StatelessWidget {
  final int stepNumber;
  final Color accent;
  final Widget child;

  const _StepConnector({
    required this.stepNumber,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: number + line
          SizedBox(
            width: 20,
            child: Column(
              children: [
                // Circle with number
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.18),
                    border:
                        Border.all(color: accent.withOpacity(0.5), width: 1.2),
                  ),
                  child: Center(
                    child: Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 1.5,
                      color: accent.withOpacity(0.18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Right: content
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ============================================================
// SONVA WELCOME PAGE
// ============================================================

class SonvaWelcomePage extends StatefulWidget {
  final LibraryPreparationState preparationState;
  final LibraryPreparationController? preparationController;
  final bool takePreparationControllerOwnership;

  const SonvaWelcomePage({
    super.key,
    required this.preparationState,
    this.preparationController,
    this.takePreparationControllerOwnership = false,
  });

  @override
  State<SonvaWelcomePage> createState() => _SonvaWelcomePageState();
}

class _SonvaWelcomePageState extends State<SonvaWelcomePage>
    with TickerProviderStateMixin {
  static const _userNameKey = 'sonva_user_name';
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  String _selectedLanguage = 'العربية';
  Color _accentColor = const Color(0xFFFF9D2E);
  bool _accentInitialized = false;

  late final AnimationController _entryController;
  late final AnimationController _particlesController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  late final LibraryPreparationController _libraryController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _libraryController = widget.preparationController ??
        LibraryPreparationController(initialState: widget.preparationState);
    _ownsController = widget.preparationController == null ||
        widget.takePreparationControllerOwnership;

    _libraryController.state.addListener(_handlePreparationChanged);

    if (_ownsController) {
      unawaited(_libraryController.start());
    }

    _nameController.addListener(() {
      if (mounted) setState(() {});
    });

    _nameFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_accentInitialized) {
      final theme = Theme.of(context);
      final themeAccent = theme.colorScheme.secondary;
      if (AccentColorSection.paletteColors
          .any((color) => color.value == themeAccent.value)) {
        _accentColor = themeAccent;
      }
      _accentInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _entryController.dispose();
    _particlesController.dispose();
    _pulseController.dispose();
    if (_ownsController) _libraryController.dispose();
    super.dispose();
  }

  bool get _canComplete => _nameController.text.trim().isNotEmpty;

  void _handlePreparationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleComplete() async {
    if (!_canComplete) return;
    HapticFeedback.mediumImpact();

    final preparation = _libraryController.current;
    final state = SonvaOnboardingState(
      name: _nameController.text.trim(),
      language: _selectedLanguage,
      accentColor: _accentColor,
      libraryProgress: preparation.progress,
      preparationStatus: preparation.currentStatus,
      songsCount: preparation.songsCount,
      videosCount: preparation.videosCount,
      lyricsFilesCount: preparation.lyricsFilesCount,
    );

    debugPrint('👤 User: ${state.name}');
    debugPrint('🌐 Language: ${state.language}');
    // mark welcome as shown
    await _markWelcomeShown();
    _openHome();
  }

  Future<void> _markWelcomeShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('welcome_shown_v1', true);
      await prefs.setString(_userNameKey, _nameController.text.trim());
    } catch (_) {
      // ignore
    }
  }

  void _openHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: const HomeScreen(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Background
            _SonvaBackground(
              accent: _accentColor,
              particlesController: _particlesController,
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _entryController,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _entryController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header ──
                        _WelcomeHeader(
                          accent: _accentColor,
                          pulse: _pulse,
                        ),
                        const SizedBox(height: 28),

                        // ── Step 1: Language ──
                        _StepConnector(
                          stepNumber: 1,
                          accent: _accentColor,
                          child: _LanguageSelectorSection(
                            selected: _selectedLanguage,
                            accent: _accentColor,
                            onChanged: (lang) =>
                                setState(() => _selectedLanguage = lang),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Step 2: Name ──
                        _StepConnector(
                          stepNumber: 2,
                          accent: _accentColor,
                          child: _NameInputSection(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            accent: _accentColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Step 3: Color ──
                        _StepConnector(
                          stepNumber: 3,
                          accent: _accentColor,
                          child: AccentColorSection(
                            selected: _accentColor,
                            accent: _accentColor,
                            onChanged: (c) => setState(() {
                              _accentColor = c;
                              unawaited(
                                AppBackgroundService.instance.setAccentColor(c),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Button ──
                        _ContinueButton(
                          accent: _accentColor,
                          enabled: _canComplete,
                          onPressed: _handleComplete,
                        ),
                        const SizedBox(height: 16),

                        // ── Footer note ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: _accentColor,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'بعد إكمال هذه الخطوات، سيتم تحسين تجربتك في Sonva وتخصيصها لتناسب مكتبتك',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color ??
                                        Colors.white70,
                                    fontSize: 12.5,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color ??
                                    Colors.white60,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// ============================================================

class _SonvaBackground extends StatelessWidget {
  final Color accent;
  final AnimationController particlesController;

  const _SonvaBackground({
    required this.accent,
    required this.particlesController,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
              child:
                  ColoredBox(color: Theme.of(context).scaffoldBackgroundColor)),
          Positioned(
            top: -200,
            right: -140,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 440,
              height: 440,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withOpacity(0.20),
                    accent.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -240,
            left: -160,
            child: Container(
              width: 480,
              height: 480,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x28143F9B),
                    Color(0x0A143F9B),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: particlesController,
              builder: (context, _) => CustomPaint(
                painter: _StarDustPainter(
                  progress: particlesController.value,
                  accent: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDustPainter extends CustomPainter {
  final double progress;
  final Color accent;

  _StarDustPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(42);
    for (int i = 0; i < 42; i++) {
      final bx = rand.nextDouble() * size.width;
      final by = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.4 + 0.3;
      final phase = rand.nextDouble();
      final twinkle = (math.sin((progress + phase) * math.pi * 2) + 1) / 2;
      final opacity = 0.15 + twinkle * 0.5;
      final isAccent = i % 7 == 0;
      final color = isAccent
          ? accent.withOpacity(opacity * 0.7)
          : Colors.white.withOpacity(opacity * 0.55);
      canvas.drawCircle(Offset(bx, by), r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _StarDustPainter old) =>
      old.progress != progress || old.accent != accent;
}

// ============================================================
// WELCOME HEADER
// ============================================================

class _WelcomeHeader extends StatelessWidget {
  final Color accent;
  final Animation<double> pulse;

  const _WelcomeHeader({required this.accent, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo
        AnimatedBuilder(
          animation: pulse,
          builder: (context, child) => Transform.scale(
            scale: pulse.value,
            child: child,
          ),
          child: Image.asset('assets/images/Circle.png', width: 72),
        ),
        const SizedBox(height: 16),

        // Title
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color:
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
              height: 1.2,
            ),
            children: [
              const TextSpan(text: 'مرحباً بك في '),
              TextSpan(
                text: 'Sonva',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ستحتاج هذه الخطوات لبضع دقائق فقط',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.white60,
                    fontSize: 13)),
            const Text(' ⏱️', style: TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('لنجهز كل شيء لتجربة مثالية',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.white60,
                    fontSize: 13)),
            const Text(' ✨', style: TextStyle(fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// STEP CARD WRAPPER (shared card style)
// ============================================================

class _StepCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget body;

  const _StepCard({
    required this.title,
    required this.icon,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(icon,
                  color: Theme.of(context).textTheme.bodySmall?.color ??
                      Colors.white60,
                  size: 20),
            ],
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

// ============================================================
// STEP 1: LANGUAGE SELECTOR
// ============================================================

class _LanguageSelectorSection extends StatelessWidget {
  final String selected;
  final Color accent;
  final ValueChanged<String> onChanged;

  static const languages = [
    'العربية',
    'English',
    'Español',
    'Français',
  ];

  const _LanguageSelectorSection({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      title: 'اختر لغتك المفضلة',
      icon: Icons.language_rounded,
      body: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: languages.map((lang) {
          final isSelected = lang == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(lang);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withOpacity(0.15)
                    : Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected ? accent : Theme.of(context).dividerColor,
                  width: isSelected ? 1.4 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accent.withOpacity(0.20),
                          blurRadius: 12,
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang,
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded, size: 15, color: accent),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// STEP 2: ACCENT COLOR SELECTOR
// ============================================================

// ============================================================
// STEP 3: NAME INPUT
// ============================================================

class _NameInputSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;

  const _NameInputSection({
    required this.controller,
    required this.focusNode,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;

    return _StepCard(
      title: 'ما الاسم الذي تود أن نناديك به؟',
      icon: Icons.person_outline_rounded,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFocused ? accent : Theme.of(context).dividerColor,
            width: isFocused ? 1.4 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.16),
                    blurRadius: 16,
                  )
                ]
              : null,
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          cursorColor: accent,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'اكتب اسمك هنا..',
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Icon(
                Icons.sentiment_satisfied_alt_outlined,
                color: isFocused
                    ? accent
                    : Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.white60,
                size: 20,
              ),
            ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CONTINUE BUTTON
// ============================================================

class _ContinueButton extends StatefulWidget {
  final Color accent;
  final bool enabled;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.accent,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: widget.enabled
                ? LinearGradient(
                    colors: [
                      widget.accent,
                      Color.lerp(widget.accent, Colors.white, 0.10) ??
                          widget.accent,
                    ],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF16162A), Color(0xFF16162A)]),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: widget.accent.withOpacity(0.38),
                      blurRadius: 24,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
            border: widget.enabled
                ? null
                : Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'متابعة إلى Sonva',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: widget.enabled
                      ? Colors.white
                      : Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_back_rounded, // RTL → shows as forward arrow
                color:
                    widget.enabled ? Colors.white : Theme.of(context).hintColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
