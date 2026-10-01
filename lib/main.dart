import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/enty_splash_screen.dart';
import 'services/app_background_service.dart';
import 'services/media_service.dart';
import 'services/sonva_theme_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // السماح بكل الاتجاهات - سيتم تقييد العمودي في الشاشات الأخرى.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ابدأ تهيئة الجسر مع الـ Native في الخلفية حتى لا تحجب أول إطار.
  unawaited(MediaService.instance.init());
  await AppBackgroundService.instance.initialize();
  await SonvaThemeService.instance.initialize();

  runApp(const NativeMediaApp());
}

class NativeMediaApp extends StatelessWidget {
  const NativeMediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppBackgroundService.instance,
        SonvaThemeService.instance,
      ]),
      builder: (context, _) {
        final background = AppBackgroundService.instance;
        final themeMode = SonvaThemeService.instance.mode;

        ThemeData theme;
        switch (themeMode) {
          case SonvaThemeMode.dark:
            theme = AppTheme.dark.copyWith(
              primaryColor: background.accentColor,
              colorScheme: AppTheme.dark.colorScheme.copyWith(
                primary: background.accentColor,
                secondary: background.accentColor,
              ),
            );
            break;
          case SonvaThemeMode.light:
            theme = AppTheme.light.copyWith(
              primaryColor: background.accentColor,
              colorScheme: AppTheme.light.colorScheme.copyWith(
                primary: background.accentColor,
                secondary: background.accentColor,
              ),
            );
            break;
          case SonvaThemeMode.colorful:
            theme = AppTheme.dark.copyWith(
              colorScheme: AppTheme.dark.colorScheme.copyWith(
                primary: background.accentColor,
                secondary: background.accentColor,
              ),
              primaryColor: background.accentColor,
              sliderTheme: AppTheme.dark.sliderTheme.copyWith(
                activeTrackColor: background.accentColor,
                thumbColor: background.accentColor,
              ),
              progressIndicatorTheme:
                  AppTheme.dark.progressIndicatorTheme.copyWith(
                color: background.accentColor,
              ),
            );
            break;
        }

        return MaterialApp(
          title: 'SONVA',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: const EntrySplashScreen(),
        );
      },
    );
  }
}
