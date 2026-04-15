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
  List<Map<String, dynamic>> _vacantes        = [];
  List<Map<String, dynamic>> _postulaciones   = [];
  List<Map<String, dynamic>> _candidatosFeed  = [];
  String? _error;
  bool _accionando = false;

  CompanyStatus get status        => _status;
  PerfilEmpresa? get perfil       => _perfil;
  List<Map<String, dynamic>> get vacantes       => _vacantes;
  List<Map<String, dynamic>> get postulaciones  => _postulaciones;
  List<Map<String, dynamic>> get candidatosFeed => _candidatosFeed;
  String? get error               => _error;
  bool get cargando               =>
      _status == CompanyStatus.cargando || _accionando;

  // ── Getters derivados para métricas ───────────────────────────────────────
  int get totalCandidatos => _postulaciones.length + _candidatosFeed.length;
  int get pendientes  => _candidatosFeed.length;
  int get matches     => _postulaciones.where((p) => p['estado'] == 'match').length;
  int get aceptados   => _postulaciones.where((p) => p['estado'] == 'aceptado').length;
  int get rechazados  => _postulaciones.where((p) => p['estado'] == 'rechazado').length;

  // Extrae IDs de vacantes activas para pasarlos al repo
  List<int> get _vacanteIds => _vacantes
      .map((v) => v['id'] as int?)
      .whereType<int>()
      .toList();

  // ── Cargar perfil ─────────────────────────────────────────────────────────
  Future<void> cargarPerfil(int userId) async {
    try {
      _perfil = await _repo.getPerfil(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('[CompanyProvider] cargarPerfil: $e');
    }
  }

  // ── Dashboard completo ────────────────────────────────────────────────────
  Future<void> cargarDashboard(int userId) async {
    _status = CompanyStatus.cargando; _error = null;
    notifyListeners();
    try {
      // 1. Perfil y vacantes con métricas en paralelo
      final results = await Future.wait([
        _repo.getPerfil(userId),
        _repo.getHistorialVacantes(userId),
      ]);
      _perfil   = results[0] as PerfilEmpresa;
      _vacantes = results[1] as List<Map<String, dynamic>>;

      // 2. Postulaciones y candidatos en paralelo
      //    getCandidatosFeed necesita los IDs de vacantes (ya disponibles)
      final ids = _vacanteIds;
      debugPrint('[CompanyProvider] cargando candidatos para vacantes: $ids');

      final candidatosResults = await Future.wait([
        _repo.getPostulaciones(userId),
        _repo.getCandidatosFeed(userId, ids),
      ]);
      _postulaciones  = candidatosResults[0];
      _candidatosFeed = candidatosResults[1];

      _status = CompanyStatus.cargado;
      debugPrint('[CompanyProvider] Dashboard cargado: '
          '${_vacantes.length} vacantes, '
          '${_postulaciones.length} postulaciones, '
          '${_candidatosFeed.length} candidatos en feed');
    } on ApiException catch (e) {
      _error = e.message; _status = CompanyStatus.error;
    } catch (e) {
      _error = 'Error al cargar. Intenta de nuevo.';
      _status = CompanyStatus.error;
      debugPrint('[CompanyProvider] cargarDashboard error: $e');
    }
    notifyListeners();
  }

  // ── Recargar candidatos (postulaciones + feed) ────────────────────────────
  Future<void> recargarCandidatos(int userId) async {
    try {
      final ids = _vacanteIds;
      final results = await Future.wait([
        _repo.getPostulaciones(userId),
        _repo.getCandidatosFeed(userId, ids),
      ]);
      _postulaciones  = results[0];
      _candidatosFeed = results[1];
      debugPrint('[CompanyProvider] Candidatos recargados: '
          '${_postulaciones.length} postulaciones, '
          '${_candidatosFeed.length} en feed');
      notifyListeners();
    } catch (e) {
      debugPrint('[CompanyProvider] recargarCandidatos: $e');
    }
  }

  // Compatibilidad con código anterior
  Future<void> recargarPostulaciones(int userId) => recargarCandidatos(userId);

  Future<void> recargarVacantes(int userId) async {
    try {
      _vacantes = await _repo.getHistorialVacantes(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('[CompanyProvider] recargarVacantes: $e');
    }
  }

  // ── Vacante individual ────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getVacante(int vacanteId) async {
    final cached = _vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    if (cached.isNotEmpty) return cached;
    try { return await _repo.getVacante(vacanteId); }
    catch (e) { debugPrint('[CompanyProvider] getVacante: $e'); return null; }
  }

  // ── Actualizar perfil ─────────────────────────────────────────────────────
  Future<bool> actualizarPerfil(int userId, {
    required String nombreComercial,
    String? sector, String? descripcion,
    String? sitioWeb, String? ubicacionSede,
  }) async {
    _accionando = true; _error = null; notifyListeners();
    try {
      _perfil = await _repo.updatePerfil(userId,
          nombreComercial: nombreComercial, sector: sector,
          descripcion: descripcion, sitioWeb: sitioWeb,
          ubicacionSede: ubicacionSede);
      _accionando = false; notifyListeners(); return true;
    } on ApiException catch (e) {
      _error = e.message; _accionando = false; notifyListeners(); return false;
    } catch (e) {
      _error = 'Error al guardar el perfil.';
      _accionando = false; notifyListeners(); return false;
    }
  }

  // ── CRUD vacantes ─────────────────────────────────────────────────────────
  Future<bool> crearVacante(int empresaId, Map<String, dynamic> body) async {
    _accionando = true; _error = null; notifyListeners();
    try {
      final nueva = await _repo.crearVacante(empresaId, body);
      _vacantes.insert(0, nueva);
      _accionando = false; notifyListeners(); return true;
    } on ApiException catch (e) {
      _error = e.message; _accionando = false; notifyListeners(); return false;
    } catch (e) {
      _error = 'Error al publicar la vacante.';
      _accionando = false;
      debugPrint('[CompanyProvider] crearVacante: $e');
      notifyListeners(); return false;
    }
  }

  Future<bool> actualizarVacante(int vacanteId, Map<String, dynamic> body) async {
    _accionando = true; _error = null; notifyListeners();
    try {
      final act = await _repo.actualizarVacante(vacanteId, body);
      final idx = _vacantes.indexWhere((v) => v['id'] == vacanteId);
      if (idx >= 0) _vacantes[idx] = act;
      _accionando = false; notifyListeners(); return true;
    } on ApiException catch (e) {
      _error = e.message; _accionando = false; notifyListeners(); return false;
    } catch (e) {
      _error = 'Error al actualizar.'; _accionando = false; notifyListeners(); return false;
    }
  }

  Future<bool> eliminarVacante(int vacanteId) async {
    _accionando = true; _error = null; notifyListeners();
    try {
      await _repo.eliminarVacante(vacanteId);
      _vacantes.removeWhere((v) => v['id'] == vacanteId);
      _accionando = false; notifyListeners(); return true;
    } catch (e) {
      _error = 'Error al eliminar.'; _accionando = false; notifyListeners(); return false;
    }
  }

  // ── Swipe empresa → estudiante ────────────────────────────────────────────
  Future<bool> swipeEstudiante({
    required int empresaId,
    required int estudianteId,
    required int vacanteId,
    required bool interes,
  }) async {
    _accionando = true; _error = null; notifyListeners();
    try {
      final match = await _repo.swipeEstudiante(
        empresaId: empresaId, estudianteId: estudianteId,
        vacanteId: vacanteId, interes: interes,
      );

      // Remover del feed de pendientes
      _candidatosFeed.removeWhere((c) {
        final cEstId = c['estudiante_id'] as int? ?? c['usuario_id'] as int?;
        final cVacId = c['vacante_id'] as int?;
        return cEstId == estudianteId && cVacId == vacanteId;
      });

      // Agregar/actualizar en postulaciones para reflejo inmediato en tabs
      final estadoLocal = match != null ? 'match' : (interes ? 'aceptado' : 'rechazado');
      final idx = _postulaciones.indexWhere(
          (p) => p['estudiante_id'] == estudianteId && p['vacante_id'] == vacanteId);
      if (idx >= 0) {
        final updated = Map<String, dynamic>.from(_postulaciones[idx]);
        updated['estado'] = estadoLocal;
        _postulaciones[idx] = updated;
      } else {
        _postulaciones.insert(0, {
          'estudiante_id':  estudianteId,
          'vacante_id':     vacanteId,
          'empresa_id':     empresaId,
          'estado':         estadoLocal,
          'source':         'swipe',
          'fecha_creacion': DateTime.now().toIso8601String(),
        });
      }

      _accionando = false; notifyListeners();
      return match != null;
    } catch (e) {
      _error = 'Error al procesar.'; _accionando = false; notifyListeners();
      return false;
    }
  }

  // ── Cambiar estado postulación ────────────────────────────────────────────
  Future<bool> cambiarEstadoPostulacion(int postId, String nuevoEstado) async {
    try {
      await _repo.cambiarEstadoPostulacion(postId, nuevoEstado);
      final idx = _postulaciones.indexWhere((p) => p['id'] == postId);
      if (idx >= 0) {
        final updated = Map<String, dynamic>.from(_postulaciones[idx]);
        updated['estado'] = nuevoEstado;
        _postulaciones[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('[CompanyProvider] cambiarEstado: $e');
      return false;
    }
  }

  void limpiarError() { _error = null; notifyListeners(); }

  void limpiar() {
    _status = CompanyStatus.inicial; _perfil = null;
    _vacantes = []; _postulaciones = []; _candidatosFeed = [];
    _error = null; _accionando = false;
    notifyListeners();
  }
}