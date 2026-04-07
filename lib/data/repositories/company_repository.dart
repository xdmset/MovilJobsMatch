// lib/data/repositories/company_repository.dart

import '../../core/services/api_service.dart';
import '../models/auth_models.dart';

class CompanyRepository {
  CompanyRepository._();
  static final CompanyRepository instance = CompanyRepository._();
  final _api = ApiService.instance;

  // ── Perfil empresa ────────────────────────────────────────────────────────
  Future<PerfilEmpresa> getPerfil(int userId) async {
    final raw = await _api.get('/perfil_empresa/$userId', auth: true);
    final map = (raw is Map<String, dynamic> ? raw['data'] : raw) as Map<String, dynamic>;
    return PerfilEmpresa.fromJson(map);
  }

  Future<PerfilEmpresa> updatePerfil(int userId, {
    required String nombreComercial,
    String? sector,
    String? descripcion,
    String? sitioWeb,
    String? ubicacionSede,
  }) async {
    final body = <String, dynamic>{
      'nombre_comercial': nombreComercial,
      if (sector        != null) 'sector':          sector,
      if (descripcion   != null) 'descripcion':     descripcion,
      if (sitioWeb      != null) 'sitio_web':       sitioWeb,
      if (ubicacionSede != null) 'ubicacion_sede':  ubicacionSede,
    };
    final raw = await _api.put('/perfil_empresa/$userId', body, auth: true);
    return PerfilEmpresa.fromJson(raw);
  }

  // ── Vacantes ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVacantes(int empresaId) async {
    final raw   = await _api.get('/vacante/', auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    return lista.cast<Map<String, dynamic>>()
        .where((v) => v['empresa_id'] == empresaId).toList();
  }

  // POST /vacante/{empresa_id}
  // empresa_id va en el PATH — el body es VacanteCreate
  // Requeridos: titulo, descripcion, modalidad
  Future<Map<String, dynamic>> crearVacante(
      int empresaId, Map<String, dynamic> body) async {
    final raw = await _api.post('/vacante/$empresaId', body, auth: true);
    return raw;
  }

  // PUT /vacante/{vacante_id}
  Future<Map<String, dynamic>> actualizarVacante(
      int vacanteId, Map<String, dynamic> body) async {
    final raw = await _api.put('/vacante/$vacanteId', body, auth: true);
    return raw;
  }

  // DELETE /vacante/{vacante_id}
  Future<void> eliminarVacante(int vacanteId) async {
    await _api.delete('/vacante/$vacanteId');
  }

  // ── Postulaciones ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPostulaciones(int empresaId) async {
    final raw   = await _api.get('/postulaciones/empresa/$empresaId', auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    return lista.cast<Map<String, dynamic>>();
  }

  // ── Historial de vacantes con estadísticas ────────────────────────────────
  Future<List<Map<String, dynamic>>> getHistorialVacantes(int empresaId) async {
    final raw   = await _api.get(
        '/vacante/historial/empresa/$empresaId', auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    return lista.cast<Map<String, dynamic>>();
  }
}