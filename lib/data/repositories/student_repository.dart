// lib/data/repositories/student_repository.dart
//
// ENDPOINTS ACTUALIZADOS (del documento del backend):
//
// GET  /swipes/{estudiante_id}/vacantes     → feed de vacantes (no vistas aún)
// POST /swipes/{estudiante_id}              → registrar swipe
//      body: { vacante_id, interes_estudiante: bool }
//      response: MatchResponse | null
//
// GET  /matches/estudiante/{estudiante_id}  → historial real de matches
//      response: [ { id, estudiante_id, vacante_id, fecha_match } ]
//
// GET  /vacante/historial/estudiante/{id}   → historial de vacantes vistas
//      response: [ VacanteHistorialEstudiante ]
//
// POST /vacante/{vacante_id}/view           → registrar vista

import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class StudentRepository {
  StudentRepository._();
  static final StudentRepository instance = StudentRepository._();
  final _api = ApiService.instance;

  // ── Feed de vacantes (NO vistas aún) ─────────────────────────────────────
  // GET /swipes/{estudiante_id}/vacantes
  // Devuelve vacantes que el estudiante NO ha visto todavía
  // (el backend filtra automáticamente las ya procesadas)
  Future<List<Map<String, dynamic>>> getVacantesFeed(int estudianteId) async {
    try {
      final raw = await _api.get(
          '/swipes/$estudianteId/vacantes', auth: true);
      final lista = raw is List ? raw : (raw['data'] as List? ?? []);
      debugPrint('[StudentRepo] feed: ${lista.length} vacantes');
      return lista.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[StudentRepo] getVacantesFeed error: $e');
      // Fallback: cargar todas las vacantes
      return getVacantes();
    }
  }

  // ── Todas las vacantes con filtros ────────────────────────────────────────
  // GET /vacante/?modalidad=&ubicacion=&sueldo_min=
  Future<List<Map<String, dynamic>>> getVacantes({
    String? modalidad, String? ubicacion, double? sueldoMin,
    int skip = 0, int limit = 100,
  }) async {
    final query = <String, String>{
      'skip': skip.toString(), 'limit': limit.toString(),
      if (modalidad != null && modalidad.isNotEmpty) 'modalidad': modalidad,
      if (ubicacion != null && ubicacion.isNotEmpty) 'ubicacion': ubicacion,
      if (sueldoMin != null) 'sueldo_min': sueldoMin.toString(),
    };
    final raw = await _api.get('/vacante/', query: query, auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    return lista.cast<Map<String, dynamic>>();
  }

  // ── Registrar swipe ───────────────────────────────────────────────────────
  // POST /swipes/{estudiante_id}
  // body: { vacante_id, interes_estudiante: bool }
  // response: MatchResponse | null
  Future<Map<String, dynamic>?> registrarSwipe(
      int estudianteId, int vacanteId, bool interes) async {
    try {
      final body = {'vacante_id': vacanteId, 'interes_estudiante': interes};
      debugPrint('[StudentRepo] swipe body: $body');
      final res = await _api.post('/swipes/$estudianteId', body, auth: true);
      debugPrint('[StudentRepo] swipe response: $res');
      if (res is Map<String, dynamic> && res.containsKey('id')) return res;
      return null;
    } catch (e) {
      debugPrint('[StudentRepo] registrarSwipe error: $e');
      return null;
    }
  }

  // ── Registrar vista ───────────────────────────────────────────────────────
  // POST /vacante/{vacante_id}/view
  Future<void> registrarVista(int vacanteId) async {
    try {
      await _api.post('/vacante/$vacanteId/view', {}, auth: true);
    } catch (e) {
      debugPrint('[StudentRepo] registrarVista error: $e');
    }
  }

  // ── Historial del estudiante ──────────────────────────────────────────────
  // GET /vacante/historial/estudiante/{estudiante_id}
  // Vacantes vistas con: le_dio_like, fecha_like, total_visualizaciones
  Future<List<Map<String, dynamic>>> getHistorialEstudiante(
      int estudianteId) async {
    final raw = await _api.get(
        '/vacante/historial/estudiante/$estudianteId', auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    debugPrint('[StudentRepo] historial: ${lista.length} items');
    return lista.cast<Map<String, dynamic>>();
  }

  // ── Matches reales del servidor ───────────────────────────────────────────
  // GET /matches/estudiante/{estudiante_id}
  // response: [ { id, estudiante_id, vacante_id, fecha_match } ]
  Future<List<Map<String, dynamic>>> getMatches(int estudianteId) async {
    try {
      final raw = await _api.get(
          '/matches/estudiante/$estudianteId', auth: true);
      final lista = raw is List ? raw : (raw['data'] as List? ?? []);
      debugPrint('[StudentRepo] matches del servidor: ${lista.length}');
      return lista.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[StudentRepo] getMatches error: $e');
      return [];
    }
  }
}