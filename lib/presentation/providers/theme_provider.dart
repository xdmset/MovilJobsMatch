// lib/presentation/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // default: claro
  Locale    _locale    = const Locale('es');

  ThemeMode get themeMode => _themeMode;
  Locale    get locale    => _locale;

  static const _keyTheme  = 'jm_theme';
  static const _keyLocale = 'jm_language';

  // Llamar antes de runApp
  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_keyTheme) ?? 'Claro';
    _themeMode = _modeFromString(t);
    final l = prefs.getString(_keyLocale) ?? 'Español';
    _locale = l == 'English' ? const Locale('en') : const Locale('es');
  }

  Future<void> setTheme(String label) async {
    _themeMode = _modeFromString(label);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, label);
  }

  // Resetea a claro y guarda — se llama al hacer logout
  Future<void> resetToLight() async {
    _themeMode = ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, 'Claro');
  }

  Future<void> setLocale(String label) async {
    _locale = label == 'English' ? const Locale('en') : const Locale('es');
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, label);
  }

  ThemeMode _modeFromString(String s) {
    switch (s) {
      case 'Oscuro': return ThemeMode.dark;
      case 'Sistema': return ThemeMode.system;
      default:       return ThemeMode.light;
    }
  }
}