import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'preferred_theme';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> initialize() async {
    try {
      final savedTheme = await _storage.read(key: _storageKey);
      _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      _themeMode = ThemeMode.dark;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;

    _themeMode = nextMode;
    notifyListeners();

    try {
      await _storage.write(key: _storageKey, value: enabled ? 'dark' : 'light');
    } catch (_) {
      // The visible preference still applies for this session if local storage
      // is temporarily unavailable.
    }
  }
}
