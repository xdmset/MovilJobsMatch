// lib/presentation/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale       = const Locale('es');

  ThemeMode get themeMode => _themeMode;
  Locale get locale       => _locale;

  /// Llamar en main() antes de runApp
  Future<void> cargar() async {
    final prefs  = await SharedPreferences.getInstance();
    final tema   = prefs.getString('jm_theme')    ?? 'Sistema';
    final idioma = prefs.getString('jm_language') ?? 'Español';
    _themeMode = _temaDesdeString(tema);
    _locale    = _localeDesdeString(idioma);
    // Sin notifyListeners — se llama antes de que haya listeners
  }

  Future<void> setTheme(String tema) async {
    _themeMode = _temaDesdeString(tema);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jm_theme', tema);
  }

  Future<void> setLocale(String idioma) async {
    _locale = _localeDesdeString(idioma);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jm_language', idioma);
  }

  ThemeMode _temaDesdeString(String t) {
    switch (t) {
      case 'Claro':  return ThemeMode.light;
      case 'Oscuro': return ThemeMode.dark;
      default:       return ThemeMode.system;
    }
  }

  Locale _localeDesdeString(String l) {
    switch (l) {
      case 'English': return const Locale('en');
      default:        return const Locale('es');
    }
  }
}