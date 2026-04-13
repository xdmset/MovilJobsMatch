// lib/data/repositories/company_repository.dart
//
// NOTA IMPORTANTE SOBRE EL BACKEND:
// El endpoint GET /swipes/empresa/{id}/candidatos?vacante_id=X
// devuelve TODOS los estudiantes incluyendo los que ya_dio_like=false.
// Filtramos en el cliente con ya_dio_like == true para mostrar solo
// los que realmente dieron like a esa vacante.

import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../models/auth_models.dart';

class CompanyRepository {
  CompanyRepository._();
  static final CompanyRepository instance = CompanyRepository._();
  final _api = ApiService.instance;

  // ── Perfil empresa ────────────────────────────────────────────────────────
  Future<PerfilEmpresa> getPerfil(int userId) async {
    final raw = await _api.get('/perfil_empresa/$userId', auth: true);
    final map = raw is Map<String, dynamic>
        ? raw : (raw['data'] as Map<String, dynamic>);
    return PerfilEmpresa.fromJson(map);
  }

  Future<PerfilEmpresa> updatePerfil(int userId, {
    required String nombreComercial,
    String? sector, String? descripcion,
    String? sitioWeb, String? ubicacionSede,
  }) async {
    final body = <String, dynamic>{'nombre_comercial': nombreComercial};
    if (sector?.isNotEmpty == true)        body['sector']         = sector;
    if (descripcion?.isNotEmpty == true)   body['descripcion']    = descripcion;
    if (sitioWeb?.isNotEmpty == true)      body['sitio_web']      = sitioWeb;
    if (ubicacionSede?.isNotEmpty == true) body['ubicacion_sede'] = ubicacionSede;
    debugPrint('[CompanyRepo] PUT /perfil_empresa/$userId body: $body');
    final raw = await _api.put('/perfil_empresa/$userId', body, auth: true);
    return PerfilEmpresa.fromJson(
        raw is Map<String, dynamic> ? raw : raw['data']);
  }

  // ── Vacantes ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getVacantes(int empresaId) async {
    final raw   = await _api.get('/vacante/', auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    final filtradas = lista.cast<Map<String, dynamic>>()
        .where((v) => v['empresa_id'] == empresaId).toList();
    debugPrint('[CompanyRepo] vacantes: ${filtradas.length} de empresa $empresaId');
    return filtradas;
  }

  Future<Map<String, dynamic>> getVacante(int vacanteId) async {
    final raw = await _api.get('/vacante/$vacanteId', auth: true);
    return raw is Map<String, dynamic> ? raw : raw['data'];
  }

  Future<Map<String, dynamic>> crearVacante(
      int empresaId, Map<String, dynamic> body) async {
    debugPrint('[CompanyRepo] POST /vacante/$empresaId body: $body');
    final raw = await _api.post('/vacante/$empresaId', body, auth: true);
    return raw is Map<String, dynamic> ? raw : raw['data'];
  }

  Future<Map<String, dynamic>> actualizarVacante(
      int vacanteId, Map<String, dynamic> body) async {
    final raw = await _api.put('/vacante/$vacanteId', body, auth: true);
    return raw is Map<String, dynamic> ? raw : raw['data'];
  }

  Future<void> eliminarVacante(int vacanteId) async =>
      _api.delete('/vacante/$vacanteId');

  // ── Historial de vacantes con métricas ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHistorialVacantes(int empresaId) async {
    try {
      final raw = await _api.get(
          '/vacante/historial/empresa/$empresaId', auth: true);
      final lista = raw is List ? raw : (raw['data'] as List? ?? []);
      debugPrint('[CompanyRepo] historial vacantes: ${lista.length} con métricas');
      return lista.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[CompanyRepo] getHistorialVacantes error: $e — fallback');
      return getVacantes(empresaId);
    }
  }

  // ── Feed de candidatos ────────────────────────────────────────────────────
  // GET /swipes/empresa/{empresa_id}/candidatos?vacante_id={vacante_id}
  //
  // FIX CRÍTICO: el backend devuelve TODOS los estudiantes con ya_dio_like
  // tanto true como false. Filtramos en cliente solo los que ya_dio_like==true
  // para mostrar únicamente los que realmente dieron like a esa vacante.
  Future<List<Map<String, dynamic>>> getCandidatosFeed(
      int empresaId, List<int> vacanteIds) async {
    if (vacanteIds.isEmpty) {
      debugPrint('[CompanyRepo] getCandidatosFeed: sin vacantes');
      return [];
    }

    try {
      final resultados = await Future.wait(
        vacanteIds.map((id) => _getCandidatosPorVacante(empresaId, id)),
      );

      // Aplanar — ya vienen filtrados por ya_dio_like=true
      final todos = resultados.expand((lista) => lista).toList();

      // Deduplicar por estudiante_id+vacante_id
      final vistos = <String>{};
      final unicos = todos.where((c) {
        final key = '${c['estudiante_id']}_${c['vacante_id']}';
        return vistos.add(key);
      }).toList();

      debugPrint('[CompanyRepo] candidatos feed total: ${unicos.length} '
          '(solo con ya_dio_like=true)');
      return unicos;
    } catch (e) {
      debugPrint('[CompanyRepo] getCandidatosFeed error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getCandidatosPorVacante(
      int empresaId, int vacanteId) async {
    try {
      final raw = await _api.get(
        '/swipes/empresa/$empresaId/candidatos',
        query: {'vacante_id': vacanteId.toString()},
        auth: true,
      );
      final lista = raw is List ? raw : (raw['data'] as List? ?? []);
      debugPrint('[CompanyRepo] candidatos vacante $vacanteId: ${lista.length} total del backend');

      final normalizados = lista.cast<Map<String, dynamic>>().map((c) {
        final n = Map<String, dynamic>.from(c);

        // El API devuelve 'usuario_id', la UI espera 'estudiante_id'
        if (!n.containsKey('estudiante_id') && n.containsKey('usuario_id')) {
          n['estudiante_id'] = n['usuario_id'];
        }

        // Siempre inyectar el vacante_id
        n['vacante_id'] = vacanteId;

        // Aplanar perfil_estudiante al nivel raíz para acceso directo en la UI
        final perfil = n['perfil_estudiante'];
        if (perfil is Map<String, dynamic>) {
          n['nombre_completo']       = perfil['nombre_completo'];
          n['nivel_academico']       = perfil['nivel_academico'];
          n['institucion_educativa'] = perfil['institucion_educativa'];
          n['ubicacion']             = perfil['ubicacion'];
          n['modalidad_preferida']   = perfil['modalidad_preferida'];
          n['foto_perfil_url']       = perfil['foto_perfil_url'];
          // FIX: incluir cv_url y cv_tipo_archivo para poder abrirlos
          n['cv_url']                = perfil['cv_url'];
          n['cv_tipo_archivo']       = perfil['cv_tipo_archivo'];
          n['biografia']             = perfil['biografia'];
          n['habilidades']           = perfil['habilidades'];
          n['fecha_nacimiento']      = perfil['fecha_nacimiento'];
        }
        return n;
      }).toList();

      // FIX: filtrar solo candidatos que realmente dieron like
      // El backend devuelve ya_dio_like=false para estudiantes que NO dieron like
      final conLike = normalizados.where((c) {
        final yaDioLike = c['ya_dio_like'];
        // Si el campo no existe asumir true para no perder datos
        if (yaDioLike == null) return true;
        return yaDioLike == true;
      }).toList();

      debugPrint('[CompanyRepo] candidatos vacante $vacanteId: '
          '${conLike.length} con like (de ${normalizados.length} total)');
      return conLike;
    } catch (e) {
      debugPrint('[CompanyRepo] _getCandidatosPorVacante '
          'vacante=$vacanteId: $e');
      return [];
    }
  }

  // ── Postulaciones ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPostulaciones(int empresaId, {
    String? estado,
    String? institucionEducativa,
    String? nivelAcademico,
    String? ubicacion,
  }) async {
    final query = <String, String>{};
    if (estado?.isNotEmpty == true)
      query['estado'] = estado!;
    if (institucionEducativa?.isNotEmpty == true)
      query['institucion_educativa'] = institucionEducativa!;
    if (nivelAcademico?.isNotEmpty == true)
      query['nivel_academico'] = nivelAcademico!;
    if (ubicacion?.isNotEmpty == true)
      query['ubicacion'] = ubicacion!;

    final raw = await _api.get(
        '/postulaciones/empresa/$empresaId',
        query: query.isEmpty ? null : query,
        auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    debugPrint('[CompanyRepo] postulaciones: ${lista.length} '
        '(estado=${estado ?? "todas"})');
    return lista.cast<Map<String, dynamic>>();
  }

  // ── Swipe empresa → estudiante ────────────────────────────────────────────
  Future<Map<String, dynamic>?> swipeEstudiante({
    required int empresaId,
    required int estudianteId,
    required int vacanteId,
    required bool interes,
  }) async {
    final body = {
      'estudiante_id':   estudianteId,
      'vacante_id':      vacanteId,
      'interes_empresa': interes,
    };
    debugPrint('[CompanyRepo] swipe empresa body: $body');
    try {
      final res = await _api.post(
          '/swipes/empresa/$empresaId', body, auth: true);
      debugPrint('[CompanyRepo] swipe response: $res');
      if (res is Map<String, dynamic> && res.containsKey('id')) return res;
      return null;
    } catch (e) {
      debugPrint('[CompanyRepo] swipeEstudiante error: $e');
      return null;
    }
  }

  // ── Cambiar estado postulación ────────────────────────────────────────────
  Future<void> cambiarEstadoPostulacion(int postId, String estado) async {
    await _api.put('/postulaciones/$postId/estado',
        {'nuevo_estado': estado}, auth: true);
  }
}