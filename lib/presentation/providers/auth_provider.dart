import 'package:flutter/material.dart';
import '../../core/errors/api_exceptions.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';

enum AuthStatus { inicial, cargando, autenticado, noAutenticado }

class AuthProvider extends ChangeNotifier {
  // ← instanciación directa, sin paréntesis de llamada de método
  final AuthRepository _repo = AuthRepository();

  AuthStatus _status = AuthStatus.inicial;
  UserModel? _usuario;
  PerfilEstudiante? _perfilEstudiante;
  PerfilEmpresa? _perfilEmpresa;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────
  AuthStatus get status => _status;
  UserModel? get usuario => _usuario;
  PerfilEstudiante? get perfilEstudiante => _perfilEstudiante;
  PerfilEmpresa? get perfilEmpresa => _perfilEmpresa;
  String? get error => _error;

  bool get cargando => _status == AuthStatus.cargando;
  bool get autenticado => _status == AuthStatus.autenticado;
  bool get esEstudiante => _usuario?.esEstudiante ?? false;
  bool get esEmpresa => _usuario?.esEmpresa ?? false;
  bool get esPremium => _usuario?.esPremium ?? false;
  int? get userId => _usuario?.id;

  // ── Verificar sesión al arrancar la app ───────────────────────────────────
  Future<void> verificarSesion() async {
    _status = AuthStatus.cargando;
    notifyListeners();

    try {
      final user = await _repo.restaurarSesion();
      if (user != null) {
        _usuario = user;
        _status = AuthStatus.autenticado;
      } else {
        _status = AuthStatus.noAutenticado;
      }
    } catch (_) {
      _status = AuthStatus.noAutenticado;
    }

    notifyListeners();
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _iniciarCarga();

    try {
      _usuario = await _repo.login(email: email, password: password);
      _status = AuthStatus.autenticado;
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Error inesperado. Intenta de nuevo.');
      return false;
    }
  }

  // ── Registro Estudiante ───────────────────────────────────────────────────
  Future<bool> registrarEstudiante({
    required String email,
    required String password,
    required String nombreCompleto,
    required String institucionEducativa,
    required String nivelAcademico,
    String? biografia,
    String? habilidades,   // ← String, no List
    String? ubicacion,
    String? modalidadPreferida,
  }) async {
    _iniciarCarga();

    try {
      _usuario = await _repo.registrarEstudiante(
        email: email,
        password: password,
        nombreCompleto: nombreCompleto,
        institucionEducativa: institucionEducativa,
        nivelAcademico: nivelAcademico,
        biografia: biografia,
        habilidades: habilidades,
        ubicacion: ubicacion,
        modalidadPreferida: modalidadPreferida,
      );
      _status = AuthStatus.autenticado;
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Error al crear la cuenta. Intenta de nuevo.');
      return false;
    }
  }

  // ── Registro Empresa ──────────────────────────────────────────────────────
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
        email: email,
        password: password,
        nombreComercial: nombreComercial,
        sector: sector,
        descripcion: descripcion,
        sitioWeb: sitioWeb,
        ubicacionSede: ubicacionSede,
      );
      _status = AuthStatus.autenticado;
      _error = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Error al crear la cuenta. Intenta de nuevo.');
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _repo.logout();
    _usuario = null;
    _perfilEstudiante = null;
    _perfilEmpresa = null;
    _error = null;
    _status = AuthStatus.noAutenticado;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  void _iniciarCarga() {
    _status = AuthStatus.cargando;
    _error = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AuthStatus.noAutenticado;
    _error = msg;
    notifyListeners();
  }
}