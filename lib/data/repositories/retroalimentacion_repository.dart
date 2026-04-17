// lib/data/repositories/retroalimentacion_repository.dart
//
// ENDPOINTS:
// GET  /retroalimentacion/postulacion/{postulacion_id}   → obtener feedback por postulación
// GET  /retroalimentacion/estudiante/{estudiante_id}      → todas las retros del estudiante
// POST /retroalimentacion/                               → crear feedback (empresa)
// POST /retroalimentacion/postulacion/{id}/generar-roadmap → forzar generación del roadmap
//
// LÓGICA:
// - Cache por postulacion_id para no repetir llamadas (lazy load).
// - Polling automático cuando roadmap_estado == "pendiente":
//   máx 5 intentos cada 3 segundos, luego resuelve con lo que haya.
// - getRetrosEstudiante() devuelve todas las retros e incluye postulacion_id,
//   usarlo para obtener postulacion_id dado un vacante_id (via postulación).

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

// ── Modelos ───────────────────────────────────────────────────────────────────

class RoadmapStep {
  final String semana;
  final String objetivo;
  final List<String> tareas;

  const RoadmapStep({
    required this.semana,
    required this.objetivo,
    this.tareas = const [],
  });

  factory RoadmapStep.fromJson(Map<String, dynamic> j) => RoadmapStep(
        semana:   j['semana']   as String? ?? '',
        objetivo: j['objetivo'] as String? ?? '',
        tareas:   (j['tareas'] as List? ?? []).cast<String>(),
      );
}

class RoadmapData {
  final List<String> habilidades;
  final List<String> acciones;
  final List<String> recursos;
  final String tiempoEstimado;
  final String prioridad; // "alta" | "media" | "baja"
  final List<RoadmapStep> roadmapDetallado;

  const RoadmapData({
    this.habilidades = const [],
    this.acciones    = const [],
    this.recursos    = const [],
    required this.tiempoEstimado,
    required this.prioridad,
    this.roadmapDetallado = const [],
  });

  factory RoadmapData.fromJson(Map<String, dynamic> j) => RoadmapData(
        habilidades:      (j['habilidades']  as List? ?? []).cast<String>(),
        acciones:         (j['acciones']     as List? ?? []).cast<String>(),
        recursos:         (j['recursos']     as List? ?? []).cast<String>(),
        tiempoEstimado:   j['tiempo_estimado'] as String? ?? '',
        prioridad:        j['prioridad']       as String? ?? 'media',
        roadmapDetallado: (j['roadmap_detallado'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(RoadmapStep.fromJson)
            .toList(),
      );
}

class RetroalimentacionRead {
  final int     id;
  final int     postulacionId;
  final String? camposMejora;
  final String? sugerenciasPerfil;
  final String? fechaEnvio;
  final String? roadmapEstado; // "generado" | "pendiente" | null
  final RoadmapData? roadmap;

  const RetroalimentacionRead({
    required this.id,
    required this.postulacionId,
    this.camposMejora,
    this.sugerenciasPerfil,
    this.fechaEnvio,
    this.roadmapEstado,
    this.roadmap,
  });

  bool get tieneContenido =>
      (camposMejora != null && camposMejora!.isNotEmpty) ||
      (sugerenciasPerfil != null && sugerenciasPerfil!.isNotEmpty) ||
      roadmap != null;

  bool get roadmapListo => roadmapEstado == 'generado' && roadmap != null;
  bool get roadmapPendiente => roadmapEstado == 'pendiente';
  bool get roadmapError => roadmapEstado == 'error';

  factory RetroalimentacionRead.fromJson(Map<String, dynamic> j) {
    final roadmapRaw = j['roadmap'];
    return RetroalimentacionRead(
      id:                j['id']                as int,
      postulacionId:     j['postulacion_id']    as int,
      camposMejora:      j['campos_mejora']     as String?,
      sugerenciasPerfil: j['sugerencias_perfil'] as String?,
      fechaEnvio:        j['fecha_envio']       as String?,
      roadmapEstado:     j['roadmap_estado']    as String?,
      roadmap: roadmapRaw is Map<String, dynamic>
          ? RoadmapData.fromJson(roadmapRaw)
          : null,
    );
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class RetroalimentacionRepository {
  RetroalimentacionRepository._();
  static final RetroalimentacionRepository instance =
      RetroalimentacionRepository._();

  final _api = ApiService.instance;

  // Cache: postulacion_id → resultado
  final Map<int, RetroalimentacionRead> _cache = {};

  // ── Obtener retroalimentación del estudiante (con polling si pendiente) ───
  // Llamar al abrir el detalle de una postulación rechazada.
  // [postulacionId] es el id de la postulacion (PostulacionRead.id).
  Future<RetroalimentacionRead?> getRetroalimentacion(
    int postulacionId, {
    bool forceRefresh = false,
  }) async {
    // Retornar cache si existe y no está pendiente
    if (!forceRefresh && _cache.containsKey(postulacionId)) {
      final cached = _cache[postulacionId]!;
      if (!cached.roadmapPendiente) return cached;
    }

    try {
      final raw = await _api.get(
        '/retroalimentacion/postulacion/$postulacionId',
        auth: true,
      );

      if (raw is! Map<String, dynamic>) return null;

      var retro = RetroalimentacionRead.fromJson(raw);
      _cache[postulacionId] = retro;
      debugPrint('[RetroRepo] postulacion $postulacionId — '
          'estado: ${retro.roadmapEstado} | roadmap: ${retro.roadmap != null}');

      // Si el roadmap está pendiente, hacer polling
      if (retro.roadmapPendiente) {
        retro = await _pollHastaGenerado(postulacionId, retro);
      }

      return retro;
    } catch (e) {
      debugPrint('[RetroRepo] getRetroalimentacion $postulacionId error: $e');
      return null;
    }
  }

  // ── Polling: máx 5 intentos cada 3s ──────────────────────────────────────
  Future<RetroalimentacionRead> _pollHastaGenerado(
    int postulacionId,
    RetroalimentacionRead inicial,
  ) async {
    const maxIntentos = 5;
    const delay = Duration(seconds: 3);
    var current = inicial;

    for (var i = 0; i < maxIntentos; i++) {
      await Future.delayed(delay);
      debugPrint('[RetroRepo] polling intento ${i + 1}/$maxIntentos '
          'para postulacion $postulacionId...');
      try {
        final raw = await _api.get(
          '/retroalimentacion/postulacion/$postulacionId',
          auth: true,
        );
        if (raw is Map<String, dynamic>) {
          current = RetroalimentacionRead.fromJson(raw);
          _cache[postulacionId] = current;
          if (current.roadmapListo) {
            debugPrint('[RetroRepo] roadmap generado en intento ${i + 1}');
            return current;
          }
        }
      } catch (e) {
        debugPrint('[RetroRepo] poll error intento ${i + 1}: $e');
      }
    }

    debugPrint('[RetroRepo] polling agotado — devolviendo sin roadmap');
    return current;
  }

  // ── Forzar generación del roadmap (endpoint adicional) ───────────────────
  Future<RetroalimentacionRead?> generarRoadmap(int postulacionId) async {
    debugPrint('[RetroRepo] generarRoadmap → POST /retroalimentacion/postulacion/$postulacionId/generar-roadmap');
    try {
      final raw = await _api.post(
        '/retroalimentacion/postulacion/$postulacionId/generar-roadmap',
        {},
        auth: true,
      );
      debugPrint('[RetroRepo] generarRoadmap respuesta raw: $raw');
      final retro = RetroalimentacionRead.fromJson(raw);
      _cache[postulacionId] = retro;
      debugPrint('[RetroRepo] generarRoadmap → roadmap_estado: ${retro.roadmapEstado} | listo: ${retro.roadmapListo} | pendiente: ${retro.roadmapPendiente}');
      return retro;
    } catch (e, st) {
      debugPrint('[RetroRepo] generarRoadmap $postulacionId error: $e');
      debugPrint('[RetroRepo] generarRoadmap stacktrace: $st');
      return null;
    }
  }

  // ── Crear retroalimentación (empresa — después del PUT /estado) ───────────
  Future<RetroalimentacionRead?> crearRetroalimentacion({
    required int postulacionId,
    String? camposMejora,
    String? sugerenciasPerfil,
  }) async {
    final body = <String, dynamic>{
      'postulacion_id': postulacionId,
      if (camposMejora != null && camposMejora.isNotEmpty)
        'campos_mejora': camposMejora,
      if (sugerenciasPerfil != null && sugerenciasPerfil.isNotEmpty)
        'sugerencias_perfil': sugerenciasPerfil,
    };
    try {
      final raw = await _api.post('/retroalimentacion/', body, auth: true);
      final retro = RetroalimentacionRead.fromJson(raw);
      _cache[postulacionId] = retro;
      debugPrint('[RetroRepo] retroalimentacion creada id: ${retro.id}');
      return retro;
    } catch (e) {
      debugPrint('[RetroRepo] crearRetroalimentacion error: $e');
      return null;
    }
  }

  // ── Listar todas las retroalimentaciones de un estudiante ────────────────
  // GET /retroalimentacion/estudiante/{estudiante_id}
  // Devuelve lista con postulacion_id incluido — úsalo para encontrar el
  // postulacion_id correspondiente a una vacante rechazada.
  Future<List<RetroalimentacionRead>> getRetrosEstudiante(
    int estudianteId, {
    bool forceRefresh = false,
  }) async {
    try {
      final raw = await _api.get(
        '/retroalimentacion/estudiante/$estudianteId',
        auth: true,
      );
      final lista = raw is List ? raw : (raw['data'] as List? ?? []);
      final retros = lista
          .whereType<Map<String, dynamic>>()
          .map(RetroalimentacionRead.fromJson)
          .toList();
      // Poblar cache de paso
      for (final r in retros) {
        _cache[r.postulacionId] = r;
      }
      debugPrint('[RetroRepo] retros estudiante $estudianteId: ${retros.length}');
      return retros;
    } catch (e) {
      debugPrint('[RetroRepo] getRetrosEstudiante $estudianteId error: $e');
      return [];
    }
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────
  void invalidar(int postulacionId) => _cache.remove(postulacionId);
  void limpiarCache() => _cache.clear();

  /// Devuelve el resultado cacheado sin llamar a la red.
  RetroalimentacionRead? getCached(int postulacionId) => _cache[postulacionId];
}