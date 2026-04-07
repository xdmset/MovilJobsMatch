// lib/presentation/providers/company_provider.dart

import 'package:flutter/material.dart';
import '../../core/errors/api_exceptions.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/company_repository.dart';

enum CompanyStatus { inicial, cargando, cargado, error }

class CompanyProvider extends ChangeNotifier {
  final _repo = CompanyRepository.instance;

  CompanyStatus _status = CompanyStatus.inicial;
  PerfilEmpresa? _perfil;
  List<Map<String, dynamic>> _vacantes      = [];
  List<Map<String, dynamic>> _postulaciones = [];
  String? _error;
  bool _cargandoAccion = false; // para crear/editar/eliminar vacante

  CompanyStatus get status       => _status;
  PerfilEmpresa? get perfil      => _perfil;
  List<Map<String, dynamic>> get vacantes      => _vacantes;
  List<Map<String, dynamic>> get postulaciones => _postulaciones;
  String? get error              => _error;
  bool get cargando              =>
      _status == CompanyStatus.cargando || _cargandoAccion;

  // ── Cargar perfil individual (para edit profile) ──────────────────────────
  Future<void> cargarPerfil(int userId) async {
    try {
      _perfil = await _repo.getPerfil(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('[CompanyProvider] cargarPerfil error: $e');
    }
  }

  // ── Cargar dashboard completo ─────────────────────────────────────────────
  Future<void> cargarDashboard(int userId) async {
    _status = CompanyStatus.cargando;
    _error  = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getPerfil(userId),
        _repo.getVacantes(userId),
        _repo.getPostulaciones(userId),
      ]);
      _perfil        = results[0] as PerfilEmpresa;
      _vacantes      = results[1] as List<Map<String, dynamic>>;
      _postulaciones = results[2] as List<Map<String, dynamic>>;
      _status = CompanyStatus.cargado;
    } on ApiException catch (e) {
      _error = e.message; _status = CompanyStatus.error;
    } catch (e) {
      _error = 'Error al cargar el dashboard.'; _status = CompanyStatus.error;
      debugPrint('[CompanyProvider] cargarDashboard error: $e');
    }
    notifyListeners();
  }

  // ── Crear vacante ─────────────────────────────────────────────────────────
  // POST /vacante/{empresa_id}
  // empresa_id va en el PATH, el body es VacanteCreate
  // Requeridos: titulo, descripcion, modalidad
  Future<bool> crearVacante(int empresaId, Map<String, dynamic> body) async {
    _cargandoAccion = true;
    _error          = null;
    notifyListeners();
    try {
      final nueva = await _repo.crearVacante(empresaId, body);
      _vacantes.insert(0, nueva);
      _cargandoAccion = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _cargandoAccion = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[CompanyProvider] crearVacante error: $e');
      _error = 'Error al publicar la vacante. Intenta de nuevo.';
      _cargandoAccion = false;
      notifyListeners();
      return false;
    }
  }

  // ── Actualizar vacante ────────────────────────────────────────────────────
  Future<bool> actualizarVacante(
      int vacanteId, Map<String, dynamic> body) async {
    _cargandoAccion = true;
    _error          = null;
    notifyListeners();
    try {
      final actualizada = await _repo.actualizarVacante(vacanteId, body);
      final idx = _vacantes.indexWhere((v) => v['id'] == vacanteId);
      if (idx >= 0) _vacantes[idx] = actualizada;
      _cargandoAccion = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _cargandoAccion = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error al actualizar la vacante.';
      _cargandoAccion = false;
      notifyListeners();
      return false;
    }
  }

  // ── Eliminar vacante ──────────────────────────────────────────────────────
  Future<bool> eliminarVacante(int vacanteId) async {
    _cargandoAccion = true;
    _error          = null;
    notifyListeners();
    try {
      await _repo.eliminarVacante(vacanteId);
      _vacantes.removeWhere((v) => v['id'] == vacanteId);
      _cargandoAccion = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al eliminar la vacante.';
      _cargandoAccion = false;
      notifyListeners();
      return false;
    }
  }

  // ── Actualizar perfil empresa ─────────────────────────────────────────────
  Future<bool> actualizarPerfil(int userId, {
    required String nombreComercial,
    String? sector, String? descripcion,
    String? sitioWeb, String? ubicacionSede,
  }) async {
    _cargandoAccion = true;
    _error          = null;
    notifyListeners();
    try {
      _perfil = await _repo.updatePerfil(userId,
        nombreComercial: nombreComercial,
        sector: sector, descripcion: descripcion,
        sitioWeb: sitioWeb, ubicacionSede: ubicacionSede,
      );
      _cargandoAccion = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _cargandoAccion = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error al actualizar el perfil.';
      _cargandoAccion = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> recargarPostulaciones(int userId) async {
    try {
      _postulaciones = await _repo.getPostulaciones(userId);
      notifyListeners();
    } catch (_) {}
  }

  void limpiarError() { _error = null; notifyListeners(); }

  void limpiar() {
    _status = CompanyStatus.inicial;
    _perfil = null;
    _vacantes = []; _postulaciones = [];
    _error = null;
    notifyListeners();
  }
}