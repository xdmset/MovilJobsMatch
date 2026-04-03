// lib/data/repositories/perfil_repository.dart

import '../../core/services/api_service.dart';
import '../models/auth_models.dart';

class PerfilRepository {
  PerfilRepository._();
  static final PerfilRepository instance = PerfilRepository._();
  final _api = ApiService.instance;

  Future<PerfilEstudiante> getPerfil(int usuarioId) async {
    final raw = await _api.get('/perfil_estudiante/$usuarioId', auth: true);
    final map = raw is Map<String, dynamic> ? raw : (raw['data'] as Map<String, dynamic>);
    return PerfilEstudiante.fromJson(map);
  }

  Future<PerfilEstudiante> updatePerfil(int usuarioId, {
    required String nombreCompleto,
    required String institucionEducativa,
    required String nivelAcademico,
    String? fechaNacimiento,     
    String? biografia,
    String? habilidades,
    String? ubicacion,
    String? modalidadPreferida,
  }) async {
    final body = <String, dynamic>{
      'nombre_completo':       nombreCompleto,
      'institucion_educativa': institucionEducativa,
      'nivel_academico':       nivelAcademico,
      if (fechaNacimiento   != null) 'fecha_nacimiento':   fechaNacimiento,
      if (biografia         != null) 'biografia':          biografia,
      if (habilidades       != null) 'habilidades':         habilidades,
      if (ubicacion         != null) 'ubicacion':           ubicacion,
      if (modalidadPreferida!= null) 'modalidad_preferida': modalidadPreferida,
    };
    final raw = await _api.put('/perfil_estudiante/$usuarioId', body, auth: true);
    return PerfilEstudiante.fromJson(raw);
  }
}