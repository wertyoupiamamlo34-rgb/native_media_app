// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/app_background_service.dart';
import '../services/sonva_theme_service.dart';

class AppBackgroundLayer extends StatelessWidget {
  /// إذا تم تمرير صورة هنا فستُستخدم بدلاً من الصورة المحفوظة.
  const AppBackgroundLayer({
    super.key,
    required this.child,
    this.overrideBackgroundFile,
  });

  final Widget child;
  final File? overrideBackgroundFile;

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

        final File? fileToShow =
            overrideBackgroundFile ?? background.backgroundFile;

        // في الوضعين الفاتح والداكن لا نرسم أي خلفية خاصة.
        // يعتمد التطبيق بالكامل على AppTheme.
        if (themeMode != SonvaThemeMode.colorful) {
          return child;
        }

        // الوضع الملون فقط
        return Stack(
          fit: StackFit.expand,
          children: [
            if (fileToShow != null)
              Image.file(
                fileToShow,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/Sonva_background.jpg',
                    fit: BoxFit.cover,
                  );
                },
              )
            else
              Image.asset(
                'assets/images/Sonva_background.jpg',
                fit: BoxFit.cover,
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: background.blur,
                  sigmaY: background.blur,
                ),
                child: ColoredBox(
                  color: Colors.black.withOpacity(background.opacity),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
