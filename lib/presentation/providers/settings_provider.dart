// lib/presentation/providers/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/api_exceptions.dart';
import '../../data/repositories/user_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final _repo = UserRepository.instance;

  // ── Preferencias locales ──────────────────────────────────────────────────
  bool _pushNotifications   = true;
  bool _emailNotifications  = true;
  bool _matchNotifications  = true;
  bool _profileVisibility   = true;
  bool _showOnlineStatus    = false;
  String _language          = 'Español';
  String _theme             = 'Sistema';

  bool get pushNotifications   => _pushNotifications;
  bool get emailNotifications  => _emailNotifications;
  bool get matchNotifications  => _matchNotifications;
  bool get profileVisibility   => _profileVisibility;
  bool get showOnlineStatus    => _showOnlineStatus;
  String get language          => _language;
  String get theme             => _theme;

  // ── Estado de cuenta ──────────────────────────────────────────────────────
  bool _deletingAccount = false;
  String? _error;

  bool get deletingAccount => _deletingAccount;
  String? get error        => _error;

  // ── Cargar preferencias guardadas ─────────────────────────────────────────
  Future<void> cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    _pushNotifications  = prefs.getBool('jm_push_notif')   ?? true;
    _emailNotifications = prefs.getBool('jm_email_notif')  ?? true;
    _matchNotifications = prefs.getBool('jm_match_notif')  ?? true;
    _profileVisibility  = prefs.getBool('jm_profile_vis')  ?? true;
    _showOnlineStatus   = prefs.getBool('jm_online_status')  ?? false;
    _language           = prefs.getString('jm_language')   ?? 'Español';
    _theme              = prefs.getString('jm_theme')       ?? 'Sistema';
    notifyListeners();
  }

  // ── Setters con persistencia ──────────────────────────────────────────────
  Future<void> setPushNotifications(bool v) async {
    _pushNotifications = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('jm_push_notif', v);
  }

  Future<void> setEmailNotifications(bool v) async {
    _emailNotifications = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('jm_email_notif', v);
  }

  Future<void> setMatchNotifications(bool v) async {
    _matchNotifications = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('jm_match_notif', v);
  }

  Future<void> setProfileVisibility(bool v) async {
    _profileVisibility = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('jm_profile_vis', v);
  }

  Future<void> setShowOnlineStatus(bool v) async {
    _showOnlineStatus = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('jm_online_status', v);
  }

  Future<void> setLanguage(String v) async {
    _language = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('jm_language', v);
  }

  Future<void> setTheme(String v) async {
    _theme = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('jm_theme', v);
  }

  // ── Eliminar cuenta ───────────────────────────────────────────────────────
  Future<bool> eliminarCuenta(int userId) async {
    _deletingAccount = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.eliminarCuenta(userId);
      _deletingAccount = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _deletingAccount = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Error al eliminar la cuenta.';
      _deletingAccount = false;
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}