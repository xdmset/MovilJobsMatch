// lib/data/repositories/notification_repository.dart
//
// ENDPOINTS:
// GET  /notificaciones/              → lista de notificaciones del usuario
// GET  /notificaciones/resumen       → {total, no_leidas}
// PUT  /notificaciones/{id}/leer     → marcar una como leída
// PUT  /notificaciones/leer-todas    → marcar todas como leídas

import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';

class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  final _api = ApiService.instance;

  Future<List<Map<String, dynamic>>> getNotificaciones() async {
    try {
      final raw = await _api.get(ApiConstants.notificaciones, auth: true);
      final lista = raw is List ? raw : (raw['data'] as List? ?? []);
      debugPrint('[NotifRepo] notificaciones: ${lista.length}');
      return lista.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[NotifRepo] getNotificaciones error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getResumen() async {
    try {
      final raw = await _api.get(ApiConstants.notificacionesResumen, auth: true);
      if (raw is Map<String, dynamic>) return raw;
      return {'total': 0, 'no_leidas': 0};
    } catch (e) {
      debugPrint('[NotifRepo] getResumen error: $e');
      return {'total': 0, 'no_leidas': 0};
    }
  }

  Future<void> marcarLeida(int id) async {
    try {
      await _api.put(ApiConstants.notificacionLeer(id), {}, auth: true);
    } catch (e) {
      debugPrint('[NotifRepo] marcarLeida $id error: $e');
    }
  }

  Future<void> marcarTodasLeidas() async {
    try {
      await _api.put(ApiConstants.notificacionesLeerTodas, {}, auth: true);
    } catch (e) {
      debugPrint('[NotifRepo] marcarTodasLeidas error: $e');
    }
  }
}
