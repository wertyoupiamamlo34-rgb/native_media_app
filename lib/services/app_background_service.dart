// ignore_for_file: deprecated_member_use, depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBackgroundService extends ChangeNotifier {
  AppBackgroundService._();

  static final AppBackgroundService instance = AppBackgroundService._();

  static const String _imagePathKey = 'background_image_path';
  static const String _opacityKey = 'background_opacity';
  static const String _blurKey = 'background_blur';
  static const String _accentColorKey = 'accent_color';

  File? _backgroundFile;
  double _opacity = 0.28;
  double _blur = 0.0;
  Color _accentColor = const Color(0xFFFF9D2E);
  bool _isInitialized = false;

  File? get backgroundFile => _backgroundFile;
  double get opacity => _opacity;
  double get blur => _blur;
  Color get accentColor => _accentColor;
  bool get hasCustomBackground =>
      _backgroundFile != null && _backgroundFile!.existsSync();

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final storedPath = prefs.getString(_imagePathKey);
    if (storedPath != null && storedPath.isNotEmpty) {
      final file = File(storedPath);
      _backgroundFile = file.existsSync() ? file : null;
    } else {
      _backgroundFile = null;
    }

    _opacity = prefs.getDouble(_opacityKey) ?? 0.28;
    _blur = prefs.getDouble(_blurKey) ?? 0.0;
    _accentColor = _colorFromInt(prefs.getInt(_accentColorKey));
    notifyListeners();
  }

  Future<void> saveSettings({
    String? imagePath,
    required double opacity,
    required double blur,
    required Color accentColor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final hasExistingBackground =
        _backgroundFile != null && _backgroundFile!.existsSync();

    if (imagePath != null && imagePath.isNotEmpty) {
      final sourceFile = File(imagePath);
      if (sourceFile.existsSync()) {
        final directory = await getApplicationDocumentsDirectory();
        await directory.create(recursive: true);

        final extension = p.extension(sourceFile.path);
        final targetPath = p.join(directory.path,
            'background${extension.isEmpty ? '.jpg' : extension}');
        final targetFile = File(targetPath);

        if (sourceFile.path == targetFile.path) {
          _backgroundFile = targetFile;
          await prefs.setString(_imagePathKey, targetFile.path);
        } else {
          if (targetFile.existsSync()) {
            await targetFile.delete();
          }
          await sourceFile.copy(targetPath);
          _backgroundFile = targetFile;
          await prefs.setString(_imagePathKey, targetFile.path);
        }
      } else if (hasExistingBackground) {
        await prefs.setString(_imagePathKey, _backgroundFile!.path);
      } else {
        _backgroundFile = null;
        await prefs.remove(_imagePathKey);
      }
    } else if (hasExistingBackground) {
      await prefs.setString(_imagePathKey, _backgroundFile!.path);
    } else {
      _backgroundFile = null;
      await prefs.remove(_imagePathKey);
    }

    _opacity = opacity;
    _blur = blur;
    _accentColor = accentColor;

    await prefs.setDouble(_opacityKey, opacity);
    await prefs.setDouble(_blurKey, blur);
    await prefs.setInt(_accentColorKey, accentColor.value);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    _accentColor = color;
    await prefs.setInt(_accentColorKey, color.value);
    notifyListeners();
  }

  Future<void> removeBackground() async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundFile = null;
    _opacity = 0.28;
    _blur = 0.0;
    _accentColor = const Color(0xFFFF9D2E);

    await prefs.remove(_imagePathKey);
    await prefs.setDouble(_opacityKey, _opacity);
    await prefs.setDouble(_blurKey, _blur);
    await prefs.setInt(_accentColorKey, _accentColor.value);
    notifyListeners();
  }

  Color _colorFromInt(int? value) {
    return value == null ? const Color(0xFFFF9D2E) : Color(value);
  }
}
