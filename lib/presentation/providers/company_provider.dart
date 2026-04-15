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
  final Map<String, Map<String, dynamic>> _candidateSnapshots = {};
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
  int get matches     => _postulaciones.where((p) => _esMatch(p)).length;
  int get aceptados   => _postulaciones.where((p) => _esAceptada(p)).length;
  int get rechazados  => _postulaciones.where((p) => _esRechazada(p)).length;

  // Extrae IDs de vacantes activas para pasarlos al repo
  List<int> get _vacanteIds => _vacantes
      .map((v) => v['id'] as int?)
      .whereType<int>()
      .toList();

  // ── Helpers de estado (espejo de candidates_screen) ───────────────────────
  // El backend devuelve: "pendiente" | "aceptada" | "rechazada" | "entrevista"
  // Localmente el provider puede marcar: "match" | "aceptado" | "rechazado"
  bool _esMatch(Map<String, dynamic> post) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    if (estado == 'match') return true;
    final matchId = post['match_id'];
    return matchId != null && matchId != 0 && estado == 'pendiente';
  }

  bool _esAceptada(Map<String, dynamic> post) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    return estado == 'aceptada' || estado == 'aceptado';
  }

  bool _esRechazada(Map<String, dynamic> post) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    return estado == 'rechazada' || estado == 'rechazado';
  }

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
      final ids = _vacanteIds;
      debugPrint('[CompanyProvider] cargando candidatos para vacantes: $ids');

      final candidatosResults = await Future.wait([
        _repo.getPostulaciones(userId),
        _repo.getCandidatosFeed(userId, ids),
      ]);
      _candidatosFeed = candidatosResults[1];
      _guardarSnapshots(_candidatosFeed);
      // FIX: postulaciones ya vienen normalizadas desde el repo;
      // solo enriquecer con snapshot si faltan datos de perfil.
      _postulaciones  = _enriquecerPostulaciones(candidatosResults[0]);

      _status = CompanyStatus.cargado;
      debugPrint('[CompanyProvider] Dashboard cargado: '
          '${_vacantes.length} vacantes, '
          '${_postulaciones.length} postulaciones '
          '(matches=$matches aceptados=$aceptados rechazados=$rechazados), '
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
  Future<void> recargarCandidatos(int userId, {int? vacanteId}) async {
    try {
      final ids = _vacanteIds;
      final results = await Future.wait([
        _repo.getPostulaciones(userId),
        _repo.getCandidatosFeed(userId, ids, vacanteId: vacanteId),
      ]);
      _candidatosFeed = results[1];
      _guardarSnapshots(_candidatosFeed);
      _postulaciones  = _enriquecerPostulaciones(results[0]);
      debugPrint('[CompanyProvider] Candidatos recargados: '
          '${_postulaciones.length} postulaciones '
          '(matches=$matches aceptados=$aceptados rechazados=$rechazados), '
          '${_candidatosFeed.length} en feed'
          '${vacanteId != null ? " (vacante $vacanteId)" : ""}');
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
      final candidatoSnapshot = _candidatosFeed.cast<Map<String, dynamic>?>()
          .firstWhere(
            (c) {
              if (c == null) return false;
              return _normalizarInt(c['estudiante_id'] ?? c['usuario_id']) == estudianteId &&
                  _normalizarInt(c['vacante_id']) == vacanteId;
            },
            orElse: () => null,
          );
      if (candidatoSnapshot != null) {
        _candidateSnapshots[_candidateKey(estudianteId, vacanteId)] =
            Map<String, dynamic>.from(candidatoSnapshot);
      }

      final match = await _repo.swipeEstudiante(
        empresaId: empresaId, estudianteId: estudianteId,
        vacanteId: vacanteId, interes: interes,
      );

      // Remover del feed de pendientes
      _candidatosFeed.removeWhere((c) {
        final cEstId = _normalizarInt(c['estudiante_id'] ?? c['usuario_id']);
        final cVacId = _normalizarInt(c['vacante_id']);
        return cEstId == estudianteId && cVacId == vacanteId;
      });

      // Agregar/actualizar en postulaciones para reflejo inmediato en tabs
      // FIX: usar estados que coincidan con los que el API devuelve para
      // que _esMatch/_esAceptada/_esRechazada los reconozcan correctamente.
      final estadoLocal = match != null ? 'match' : (interes ? 'aceptada' : 'rechazada');
      final idx = _postulaciones.indexWhere(
          (p) => _normalizarInt(p['estudiante_id']) == estudianteId
              && _normalizarInt(p['vacante_id']) == vacanteId);
      if (idx >= 0) {
        final updated = Map<String, dynamic>.from(_postulaciones[idx]);
        updated['estado'] = estadoLocal;
        _postulaciones[idx] = updated;
      } else {
        final snapshot =
            _candidateSnapshots[_candidateKey(estudianteId, vacanteId)] ?? const {};
        _postulaciones.insert(0, {
          ...snapshot,
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

  // ── Retroalimentación ─────────────────────────────────────────────────────
  Future<bool> crearRetroalimentacion({
    required int postulacionId,
    required String camposMejora,
    String? sugerenciasPerfil,
  }) async {
    try {
      await _repo.crearRetroalimentacion(
        postulacionId:    postulacionId,
        camposMejora:     camposMejora,
        sugerenciasPerfil: sugerenciasPerfil,
      );
      debugPrint('[CompanyProvider] retroalimentación enviada ✓ '
          'postulacion=$postulacionId');
      return true;
    } catch (e) {
      debugPrint('[CompanyProvider] crearRetroalimentacion error: $e');
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
    _candidateSnapshots.clear();
    _error = null; _accionando = false;
    notifyListeners();
  }

  void _guardarSnapshots(Iterable<Map<String, dynamic>> candidatos) {
    for (final candidato in candidatos) {
      final estudianteId =
          _normalizarInt(candidato['estudiante_id'] ?? candidato['usuario_id']);
      final vacanteId = _normalizarInt(candidato['vacante_id']);
      if (estudianteId == null || vacanteId == null) continue;
      _candidateSnapshots[_candidateKey(estudianteId, vacanteId)] =
          Map<String, dynamic>.from(candidato);
    }
  }

  // FIX: _enriquecerPostulaciones ya NO sobreescribe el 'estado' ni los
  // datos de perfil que el repo ya aplana. El snapshot solo rellena
  // campos que falten (p.ej. foto_perfil_url si el endpoint de postulaciones
  // no trae perfil_estudiante), usando post como fuente de verdad.
  List<Map<String, dynamic>> _enriquecerPostulaciones(
      List<Map<String, dynamic>> postulaciones) {
    return postulaciones.map((post) {
      final estudianteId = _normalizarInt(post['estudiante_id']);
      final vacanteId = _normalizarInt(post['vacante_id']);
      if (estudianteId == null || vacanteId == null) {
        return Map<String, dynamic>.from(post);
      }

      final snapshot = _candidateSnapshots[_candidateKey(estudianteId, vacanteId)];
      if (snapshot == null) return Map<String, dynamic>.from(post);

      // IMPORTANTE: post va DESPUÉS del snapshot para que sus valores
      // (especialmente 'estado', 'id', 'match_id') tengan prioridad.
      return {
        ...snapshot,
        ...post,
      };
    }).toList();
  }

  int? _normalizarInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _candidateKey(int estudianteId, int vacanteId) =>
      '$estudianteId-$vacanteId';
}