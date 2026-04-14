// lib/data/repositories/student_repository.dart
//
// ENDPOINTS:
// GET  /swipes/{estudiante_id}/vacantes     → feed (no vistas aún)
// POST /swipes/{estudiante_id}              → registrar swipe { vacante_id, interes_estudiante }
//      response: MatchResponse | null
// GET  /matches/estudiante/{id}             → matches reales
// GET  /vacante/historial/estudiante/{id}   → historial vistas
// POST /vacante/{vacante_id}/view           → registrar vista (solo analytics)
// GET  /perfil_empresa/{user_id}            → perfil de empresa
// GET  /media/empresas/{user_id}/foto       → URL prefirmada de foto empresa

import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class StudentRepository {
  StudentRepository._();
  static final StudentRepository instance = StudentRepository._();
  final _api = ApiService.instance;

  // Cache de perfiles de empresa para no repetir llamadas
  final Map<int, Map<String, dynamic>> _empresaCache = {};

  // ── Feed de vacantes (NO vistas aún), con filtros opcionales de backend ──────
  Future<List<Map<String, dynamic>>> getVacantesFeed(
    int estudianteId, {
    String? modalidad,
    String? ubicacion,
    double? sueldoMin,
  }) async {
    try {
      final query = <String, String>{
        'skip': '0', 'limit': '100',
        if (modalidad != null && modalidad.isNotEmpty) 'modalidad': modalidad,
        if (ubicacion != null && ubicacion.isNotEmpty) 'ubicacion': ubicacion,
        if (sueldoMin != null) 'sueldo_min': sueldoMin.toString(),
      };
      final raw = await _api.get(
        '/swipes/$estudianteId/vacantes',
        query: query,
        auth: true,
      );
      final lista = raw is List ? raw : (raw['data'] as List? ?? []);
      debugPrint('[StudentRepo] feed: ${lista.length} vacantes');
      final vacantes = lista.cast<Map<String, dynamic>>();
      // Enriquecer con datos de empresa en paralelo
      return await _enriquecerConEmpresa(vacantes);
    } catch (e) {
      debugPrint('[StudentRepo] getVacantesFeed error: $e');
      return [];
    }
  }

  // ── Todas las vacantes con filtros ────────────────────────────────────────
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
    final vacantes = lista.cast<Map<String, dynamic>>();
    return await _enriquecerConEmpresa(vacantes);
  }

  // ── Enriquecer vacantes con nombre y foto de empresa ─────────────────────
  // Agrupa por empresa_id y hace una sola llamada por empresa (con cache)
  Future<List<Map<String, dynamic>>> _enriquecerConEmpresa(
      List<Map<String, dynamic>> vacantes) async {
    if (vacantes.isEmpty) return vacantes;

    // Obtener IDs únicos de empresa que no están en caché
    final idsNecesarios = vacantes
        .map((v) => v['empresa_id'] as int?)
        .whereType<int>()
        .toSet()
        .where((id) => !_empresaCache.containsKey(id))
        .toList();

    // Cargar en paralelo los perfiles que faltan
    if (idsNecesarios.isNotEmpty) {
      await Future.wait(idsNecesarios.map((id) => _cargarPerfilEmpresa(id)));
    }

    // Inyectar datos de empresa en cada vacante
    return vacantes.map((v) {
      final empresaId = v['empresa_id'] as int?;
      if (empresaId == null) return v;
      final perfil = _empresaCache[empresaId];
      if (perfil == null) return v;
      return {
        ...v,
        'empresa_nombre': perfil['nombre_comercial'] as String? ?? 'Empresa',
        'empresa_sector': perfil['sector'] as String?,
        'empresa_foto_url': perfil['foto_url'] as String?,
        'empresa_descripcion': perfil['descripcion'] as String?,
        'empresa_sitio_web': perfil['sitio_web'] as String?,
        'empresa_ubicacion': perfil['ubicacion_sede'] as String?,
      };
    }).toList();
  }

  Future<void> _cargarPerfilEmpresa(int empresaId) async {
    try {
      // Cargar perfil y foto en paralelo
      final results = await Future.wait([
        _api.get('/perfil_empresa/$empresaId', auth: true)
            .catchError((_) => <String, dynamic>{}),
        _api.get('/media/empresas/$empresaId/foto', auth: true)
            .catchError((_) => <String, dynamic>{}),
      ]);

      final perfil = results[0] is Map<String, dynamic>
          ? results[0] as Map<String, dynamic> : <String, dynamic>{};
      final fotoRaw = results[1];

      // La foto puede venir como { url: "..." } o como string directo
      String? fotoUrl;
      if (fotoRaw is Map) {
        fotoUrl = fotoRaw['url'] as String?
            ?? fotoRaw['foto_url'] as String?
            ?? fotoRaw['presigned_url'] as String?;
      } else if (fotoRaw is String && fotoRaw.startsWith('http')) {
        fotoUrl = fotoRaw;
      }

      _empresaCache[empresaId] = {
        ...perfil,
        if (fotoUrl != null) 'foto_url': fotoUrl,
      };
      debugPrint('[StudentRepo] empresa $empresaId: '
          '${perfil['nombre_comercial']} | foto: ${fotoUrl != null}');
    } catch (e) {
      // Si falla, guardar vacío para no reintentar
      _empresaCache[empresaId] = {};
      debugPrint('[StudentRepo] _cargarPerfilEmpresa $empresaId error: $e');
    }
  }

  // ── Registrar swipe ───────────────────────────────────────────────────────
  // POST /swipes/{estudiante_id}
  // body: { vacante_id, interes_estudiante: bool }
  // response: MatchResponse | null
  //
  // FIX: El swipe ya registra la visualización internamente en el backend.
  // NO es necesario llamar registrarVista() además del swipe.
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

  // ── Registrar vista (solo analytics, no usar como señal de swipe) ─────────
  // POST /vacante/{vacante_id}/view
  // IMPORTANTE: Solo llamar para registrar que se VIO la tarjeta (analytics).
  // El swipe ya notifica al backend de forma completa.
  Future<void> registrarVista(int vacanteId) async {
    try {
      await _api.post('/vacante/$vacanteId/view', {}, auth: true);
    } catch (e) {
      debugPrint('[StudentRepo] registrarVista error: $e');
    }
  }

  // ── Historial del estudiante ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getHistorialEstudiante(
      int estudianteId) async {
    final raw = await _api.get(
        '/vacante/historial/estudiante/$estudianteId', auth: true);
    final lista = raw is List ? raw : (raw['data'] as List? ?? []);
    debugPrint('[StudentRepo] historial: ${lista.length} items');
    return lista.cast<Map<String, dynamic>>();
  }

  // ── Matches reales del servidor ───────────────────────────────────────────
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

  // ── Limpiar cache (llamar en logout) ──────────────────────────────────────
  void limpiarCache() => _empresaCache.clear();
}