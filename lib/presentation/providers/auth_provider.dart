// lib/presentation/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../../core/errors/api_exceptions.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { inicial, cargando, autenticado, noAutenticado }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo = AuthRepository();

  AuthStatus _status = AuthStatus.inicial;
  UserModel? _usuario;
  String?    _error;

  AuthStatus get status       => _status;
  UserModel? get usuario      => _usuario;
  String?    get error        => _error;
  bool get cargando           => _status == AuthStatus.cargando;
  bool get autenticado        => _status == AuthStatus.autenticado;
  bool get esEstudiante       => _usuario?.esEstudiante ?? false;
  bool get esEmpresa          => _usuario?.esEmpresa    ?? false;
  bool get esPremium          => _usuario?.esPremium    ?? false;
  int? get userId             => _usuario?.id;

  Future<void> verificarSesion() async {
    _status = AuthStatus.cargando;
    notifyListeners();
    try {
      final user = await _repo.restaurarSesion();
      _usuario = user;
      _status  = user != null ? AuthStatus.autenticado : AuthStatus.noAutenticado;
    } catch (_) { _status = AuthStatus.noAutenticado; }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _iniciarCarga();
    try {
      _usuario = await _repo.login(email: email, password: password);
      _status  = AuthStatus.autenticado;
      _error   = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) { _setError(e.message); return false;
    } catch (_) { _setError('Error inesperado. Intenta de nuevo.'); return false; }
  }

  // ── Registro Estudiante — ahora requiere fechaNacimiento ──────────────────
  Future<bool> registrarEstudiante({
    required String email,
    required String password,
    required String nombreCompleto,
    required String institucionEducativa,
    required String nivelAcademico,
    required String fechaNacimiento,    // ← NUEVO requerido
    String? biografia,
    String? habilidades,
    String? ubicacion,
    String? modalidadPreferida,
  }) async {
    _iniciarCarga();
    try {
      _usuario = await _repo.registrarEstudiante(
        email:                email,
        password:             password,
        nombreCompleto:       nombreCompleto,
        institucionEducativa: institucionEducativa,
        nivelAcademico:       nivelAcademico,
        fechaNacimiento:      fechaNacimiento,
        biografia:            biografia,
        habilidades:          habilidades,
        ubicacion:            ubicacion,
        modalidadPreferida:   modalidadPreferida,
      );
      _status = AuthStatus.autenticado;
      _error  = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) { _setError(e.message); return false;
    } catch (_) { _setError('Error al crear la cuenta.'); return false; }
  }

  Future<bool> registrarEmpresa({
    required String email,
    required String password,
    required String nombreComercial,
    String? sector,
    String? descripcion,
    String? sitioWeb,
    String? ubicacionSede,
  }) async {
    _iniciarCarga();
    try {
      _usuario = await _repo.registrarEmpresa(
        email:           email,
        password:        password,
        nombreComercial: nombreComercial,
        sector:          sector,
        descripcion:     descripcion,
        sitioWeb:        sitioWeb,
        ubicacionSede:   ubicacionSede,
      );
      _status = AuthStatus.autenticado;
      _error  = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) { _setError(e.message); return false;
    } catch (_) { _setError('Error al crear la cuenta.'); return false; }
  }

  Future<void> logout() async {
    await _repo.logout();
    _usuario = null;
    _error   = null;
    _status  = AuthStatus.noAutenticado;
    notifyListeners();
  }

  void limpiarError() { _error = null; notifyListeners(); }

  void _iniciarCarga() {
    _status = AuthStatus.cargando;
    _error  = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AuthStatus.noAutenticado;
    _error  = msg;
    notifyListeners();
  }
}