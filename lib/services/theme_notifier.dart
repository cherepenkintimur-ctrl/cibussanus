import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final useSystem = prefs.getBool('use_system_theme') ?? true;
    final darkMode = prefs.getBool('dark_mode') ?? false;

    if (useSystem) {
      _themeMode = ThemeMode.system;
    } else if (darkMode) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    if (_themeMode != ThemeMode.system) {
      _themeMode = value ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> setSystemTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_system_theme', value);
    if (value) {
      _themeMode = ThemeMode.system;
    } else {
      final darkMode = prefs.getBool('dark_mode') ?? false;
      _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light;
    }
    notifyListeners();
  }

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isSystem => _themeMode == ThemeMode.system;
}
