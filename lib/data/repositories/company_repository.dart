// lib/data/repositories/company_repository.dart

import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../models/auth_models.dart';

class CompanyRepository {
  CompanyRepository._();
  static final CompanyRepository instance = CompanyRepository._();

  final _api = ApiService.instance;

  // ── Perfil empresa ────────────────────────────────────────────────────────
  Future<PerfilEmpresa> getPerfil(int userId) async {
    final raw = await _api.get(ApiConstants.perfilEmpresa(userId), auth: true);
    final map = raw is Map<String, dynamic> ? raw : (raw['data'] as Map<String, dynamic>);
    return PerfilEmpresa.fromJson(map);
  }

  Future<PerfilEmpresa> updatePerfil(int userId, {
    String? nombreComercial,
    String? sector,
    String? descripcion,
    String? sitioWeb,
    String? ubicacionSede,
  }) async {
    final body = <String, dynamic>{
      if (nombreComercial != null) 'nombre_comercial': nombreComercial,
      if (sector != null) 'sector': sector,
      if (descripcion != null) 'descripcion': descripcion,
      if (sitioWeb != null) 'sitio_web': sitioWeb,
      if (ubicacionSede != null) 'ubicacion_sede': ubicacionSede,
    };
    final raw = await _api.put(ApiConstants.perfilEmpresa(userId), body, auth: true);
    return PerfilEmpresa.fromJson(raw);
  }

  // ── Vacantes — solo las de esta empresa ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getVacantes(int empresaId) async {
    final raw = await _api.get(ApiConstants.vacantes, auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    final todas = lista.cast<Map<String, dynamic>>();
    // Filtrar solo las vacantes que pertenecen a esta empresa
    return todas.where((v) => v['empresa_id'] == empresaId).toList();
  }

  // ── Postulaciones ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPostulaciones(int empresaId) async {
    final raw = await _api.get(ApiConstants.postulacionesEmpresa(empresaId), auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    return lista.cast<Map<String, dynamic>>();
  }
}