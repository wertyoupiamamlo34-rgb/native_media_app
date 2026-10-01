// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_media_app/screens/home_screen.dart';
import 'package:native_media_app/screens/sonva_welcome_page.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/library_preparation_controller.dart';
import '../utils/permission_request_helper.dart';

class EntrySplashScreen extends StatefulWidget {
  const EntrySplashScreen({super.key});

  @override
  State<EntrySplashScreen> createState() => _EntrySplashScreenState();
}

class _EntrySplashScreenState extends State<EntrySplashScreen>
    with TickerProviderStateMixin {
  bool _hasNavigated = false;
  bool _controllerTransferred = false;

  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  late final LibraryPreparationController _libraryController;

  late final Animation<double> _fadeIn;
  late final Animation<double> _logoScale;
  late final Animation<double> _textSlide;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // ==========================================================
    // MAIN ANIMATION
    // ==========================================================

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeIn = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.0,
        0.65,
        curve: Curves.easeOut,
      ),
    );

    _logoScale = Tween<double>(
      begin: 0.65,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(
          0.0,
          0.7,
          curve: Curves.elasticOut,
        ),
      ),
    );

    _textSlide = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(
        0.35,
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );

    // ==========================================================
    // LOGO PULSE
    // ==========================================================

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 0.96,
      end: 1.06,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // ==========================================================
    // WAVE
    // ==========================================================

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _libraryController = LibraryPreparationController(
      initialState: const LibraryPreparationState(),
    );

    _mainController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(_initializeApp());
    });
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializeApp() async {
    final startedAt = DateTime.now();

    try {
      final permissions = <Permission>[
        Permission.audio,
        if (!kIsWeb && Platform.isAndroid) Permission.storage,
        if (!kIsWeb) Permission.notification,
      ];

      if (permissions.isNotEmpty) {
        await PermissionRequestHelper.requestPermissions(permissions);
      }

      if (!mounted) return;

      final preparationFuture = _libraryController.start();

      const minimumSplash = Duration(seconds: 3);
      final elapsed = DateTime.now().difference(startedAt);

      // Ensure a minimum splash duration but do not block navigation
      // on library preparation. Let preparation continue in background
      // while the user interacts with the onboarding steps.
      if (elapsed < minimumSplash) {
        await Future.delayed(minimumSplash - elapsed);
      }

      // Do not await preparationFuture here; run it unawaited so
      // lyrics prewarm continues while the welcome page is shown.
      unawaited(preparationFuture);

      if (!mounted || _hasNavigated) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('welcome_shown_v1') == true) {
        _openHome();
      } else {
        _openWelcome(_libraryController.current);
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[EntrySplashScreen] Initialization error: $error',
      );

      debugPrint('$stackTrace');

      if (!mounted || _hasNavigated) return;

      _openWelcome(_libraryController.current);
    }
  }

  // ============================================================
  // SPLASH → WELCOME
  // ============================================================

  void _openWelcome(LibraryPreparationState preparationState) {
    if (!mounted) return;

    if (_hasNavigated) return;

    _hasNavigated = true;
    _controllerTransferred = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(
          milliseconds: 600,
        ),
        reverseTransitionDuration: const Duration(
          milliseconds: 400,
        ),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return FadeTransition(
            opacity: animation,
            child: SonvaWelcomePage(
              preparationState: preparationState,
              preparationController: _libraryController,
              takePreparationControllerOwnership: true,
            ),
          );
        },
      ),
    );
  }

  void _openHome() {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    if (!_controllerTransferred) {
      _libraryController.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
            ),
          ),
          ..._buildParticles(size),
          Positioned(
            top: -100,
            right: -80,
            child: _buildGlowOrb(
              250,
              Colors.purpleAccent.withOpacity(0.15),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _buildGlowOrb(
              300,
              Colors.blueAccent.withOpacity(0.12),
            ),
          ),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ==================================================
                    // LOGO
                    // ==================================================

                    ScaleTransition(
                      scale: _logoScale,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulse.value,
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/images/Circle.png',
                          width: 110,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // SONVA
                    // ==================================================

                    AnimatedBuilder(
                      animation: _textSlide,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            20 * (1 - _textSlide.value),
                          ),
                          child: Opacity(
                            opacity: _textSlide.value,
                            child: child,
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/images/sonva_w.png',
                        width: 120,
                      ),
                    ),

                    const SizedBox(height: 34),

                    // ==================================================
                    // TAGLINE
                    // ==================================================

                    FadeTransition(
                      opacity: _textSlide,
                      child: Text(
                        'Where Sound Meets Vision',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // ==================================================
                    // LOADER
                    // ==================================================

                    FadeTransition(
                      opacity: _textSlide,
                      child: _buildWaveLoader(),
                    ),

                    const SizedBox(height: 24),

                    FadeTransition(
                      opacity: _textSlide,
                      child: Text(
                        'Preparing your experience...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    FadeTransition(
                      opacity: _textSlide,
                      child: Text(
                        '© ${DateTime.now().year} SONVA',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GLOW
  // ============================================================

  Widget _buildGlowOrb(
    double size,
    Color color,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PARTICLES
  // ============================================================

  List<Widget> _buildParticles(Size size) {
    final random = math.Random(42);
    final particles = <Widget>[];

    for (int i = 0; i < 20; i++) {
      final left = random.nextDouble() * size.width;
      final top = random.nextDouble() * size.height;
      final particleSize = random.nextDouble() * 3 + 1;
      final delay = random.nextDouble();

      particles.add(
        Positioned(
          left: left,
          top: top,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final progress = (_pulseController.value + delay) % 1.0;

              final opacity =
                  (math.sin(progress * math.pi) * 0.6).clamp(0.0, 1.0);

              return Opacity(
                opacity: opacity,
                child: Container(
                  width: particleSize,
                  height: particleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return particles;
  }

  // ============================================================
  // WAVE
  // ============================================================

  Widget _buildWaveLoader() {
    return SizedBox(
      width: 60,
      height: 30,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(
              5,
              (index) {
                final offset = index * 0.15;

                final value = math.sin(
                  (_waveController.value + offset) * 2 * math.pi,
                );

                final height = 8.0 + value.abs() * 18;

                return Container(
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(
                      0.7 + value.abs() * 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
