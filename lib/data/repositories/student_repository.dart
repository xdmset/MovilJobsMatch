// lib/data/repositories/student_repository.dart

import '../../core/services/api_service.dart';

class StudentRepository {
  StudentRepository._();
  static final StudentRepository instance = StudentRepository._();
  final _api = ApiService.instance;

  // ── Vacantes ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVacantes({
    String? modalidad,
    String? ubicacion,
    double? sueldoMin,
    int skip = 0,
    int limit = 100,
  }) async {
    final query = <String, String>{
      'skip': skip.toString(), 'limit': limit.toString(),
      if (modalidad != null) 'modalidad': modalidad,
      if (ubicacion != null) 'ubicacion': ubicacion,
      if (sueldoMin != null) 'sueldo_min': sueldoMin.toString(),
    };
    final raw = await _api.get('/vacante/', query: query, auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    return lista.cast<Map<String, dynamic>>();
  }

  // ── Registrar swipe ───────────────────────────────────────────────────────
  // Devuelve MatchResponse si hay match, null si no
  // { id, estudiante_id, vacante_id, fecha_match }
  Future<Map<String, dynamic>?> registrarSwipe(
      int estudianteId, int vacanteId, bool interes) async {
    try {
      final res = await _api.post(
        '/swipes/$estudianteId',
        {'vacante_id': vacanteId, 'interes_estudiante': interes},
        auth: true,
      );
      // Si el backend devuelve un match, res tendrá { id, estudiante_id, vacante_id, fecha_match }
      if (res != null && res is Map<String, dynamic> && res.containsKey('id')) {
        return res;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Postulación manual (después de match) ─────────────────────────────────
  // POST /postulaciones/web — { estudiante_id, vacante_id }
  Future<Map<String, dynamic>?> crearPostulacion(
      int estudianteId, int vacanteId) async {
    try {
      final res = await _api.post('/postulaciones/web',
          {'estudiante_id': estudianteId, 'vacante_id': vacanteId},
          auth: true);
      return res is Map<String, dynamic> ? res : null;
    } catch (_) {
      return null;
    }
  }

  // ── Vacante por ID (para mostrar detalles en postulación) ─────────────────
  Future<Map<String, dynamic>?> getVacante(int vacanteId) async {
    try {
      final raw = await _api.get('/vacante/$vacanteId', auth: true);
      return raw is Map<String, dynamic> ? raw : null;
    } catch (_) {
      return null;
    }
  }
}