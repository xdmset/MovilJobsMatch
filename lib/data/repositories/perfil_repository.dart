// lib/data/repositories/perfil_repository.dart

import '../../core/services/api_service.dart';
import '../models/auth_models.dart';

class PerfilRepository {
  PerfilRepository._();
  static final PerfilRepository instance = PerfilRepository._();

  final _api = ApiService.instance;

  static const _base = '/perfil_estudiante/';

  // ── GET /perfil_estudiante/{usuario_id} ───────────────────────────────────
  Future<PerfilEstudiante> getPerfil(int usuarioId) async {
    final raw = await _api.get('$_base$usuarioId', auth: true);
    final map = raw is Map<String, dynamic> ? raw : (raw['data'] as Map<String, dynamic>);
    return PerfilEstudiante.fromJson(map);
  }

  // ── POST /perfil_estudiante/{usuario_id} ──────────────────────────────────
  // Solo se usa si el perfil aún no existe (edge case — normalmente se crea
  // al registrarse). Lo dejamos por si acaso.
  Future<PerfilEstudiante> createPerfil(
    int usuarioId,
    PerfilEstudianteCreateDto dto,
  ) async {
    final raw = await _api.post('$_base$usuarioId', dto.toJson(), auth: true);
    return PerfilEstudiante.fromJson(raw);
  }

  // ── PUT /perfil_estudiante/{usuario_id} ───────────────────────────────────
  Future<PerfilEstudiante> updatePerfil(
    int usuarioId, {
    String? nombreCompleto,
    String? institucionEducativa,
    String? nivelAcademico,
    String? biografia,
    String? habilidades,
    String? ubicacion,
    String? modalidadPreferida,
  }) async {
    final body = <String, dynamic>{
      if (nombreCompleto != null) 'nombre_completo': nombreCompleto,
      if (institucionEducativa != null) 'institucion_educativa': institucionEducativa,
      if (nivelAcademico != null) 'nivel_academico': nivelAcademico,
      if (biografia != null) 'biografia': biografia,
      if (habilidades != null) 'habilidades': habilidades,
      if (ubicacion != null) 'ubicacion': ubicacion,
      if (modalidadPreferida != null) 'modalidad_preferida': modalidadPreferida,
    };

    final raw = await _api.put('$_base$usuarioId', body, auth: true);
    return PerfilEstudiante.fromJson(raw);
  }
}