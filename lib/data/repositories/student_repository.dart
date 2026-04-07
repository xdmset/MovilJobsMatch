// lib/data/repositories/student_repository.dart

import '../../core/services/api_service.dart';

class StudentRepository {
  StudentRepository._();
  static final StudentRepository instance = StudentRepository._();
  final _api = ApiService.instance;

  // ── Vacantes ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVacantes({
    String? modalidad, String? ubicacion, double? sueldoMin,
    int skip = 0, int limit = 100,
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

  // ── Registrar vista de vacante ────────────────────────────────────────────
  // POST /vacante/{vacante_id}/view — sin body
  Future<void> registrarVista(int vacanteId) async {
    try {
      await _api.post('/vacante/$vacanteId/view', {}, auth: true);
    } catch (_) {} // falla silencioso
  }

  // ── Historial del estudiante desde el servidor ────────────────────────────
  // GET /vacante/historial/estudiante/{estudiante_id}
  // Respuesta: List<VacanteHistorialEstudiante>
  // { titulo, descripcion, modalidad, ubicacion, sueldo_minimo, sueldo_maximo,
  //   moneda, estado, id, empresa_id, fecha_publicacion,
  //   primera_visualizacion, ultima_visualizacion, total_visualizaciones,
  //   le_dio_like (bool), fecha_like }
  Future<List<Map<String, dynamic>>> getHistorialEstudiante(
      int estudianteId) async {
    final raw = await _api.get(
        '/vacante/historial/estudiante/$estudianteId', auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    return lista.cast<Map<String, dynamic>>();
  }

  // ── Swipe ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> registrarSwipe(
      int estudianteId, int vacanteId, bool interes) async {
    try {
      final res = await _api.post('/swipes/$estudianteId',
          {'vacante_id': vacanteId, 'interes_estudiante': interes},
          auth: true);
      if (res.containsKey('id')) {
        return res;
      }
      return null;
    } catch (_) { return null; }
  }

  // ── Crear postulación manual ──────────────────────────────────────────────
  Future<Map<String, dynamic>?> crearPostulacion(
      int estudianteId, int vacanteId) async {
    try {
      final res = await _api.post('/postulaciones/web',
          {'estudiante_id': estudianteId, 'vacante_id': vacanteId},
          auth: true);
      return res;
    } catch (_) { return null; }
  }
}