import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SonvaThemeMode { dark, light, colorful }

class SonvaThemeService extends ChangeNotifier {
  SonvaThemeService._();

  static final SonvaThemeService instance = SonvaThemeService._();

  static const String _modeKey = 'sonva_theme_mode';

  SonvaThemeMode _mode = SonvaThemeMode.colorful;
  bool _isInitialized = false;

  SonvaThemeMode get mode => _mode;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_modeKey);
    _mode = SonvaThemeMode.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => SonvaThemeMode.colorful,
    );
    notifyListeners();
  }

  Future<void> setMode(SonvaThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
    notifyListeners();
  }
}
