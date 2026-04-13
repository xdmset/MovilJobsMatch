// lib/data/repositories/paypal_repository.dart

import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class PaypalRepository {
  PaypalRepository._();
  static final PaypalRepository instance = PaypalRepository._();
  final _api = ApiService.instance;

  // ── Planes del usuario actual (filtrados por su rol) ──────────────────────
  Future<List<Map<String, dynamic>>> getPlanes() async {
    try {
      final raw = await _api.get('/payments/paypal/plans/me', auth: true);
      debugPrint('[PayPal] /plans/me raw response: $raw');
      final lista = _parseLista(raw);
      debugPrint('[PayPal] /plans/me parsed: ${lista.length} planes');
      if (lista.isNotEmpty) return lista;

      // Si /plans/me devolvió vacío, fallback a /plans
      debugPrint('[PayPal] /plans/me vacío, fallback a /plans');
      return await _getPlanesTodos();
    } catch (e) {
      debugPrint('[PayPal] /plans/me falló ($e), fallback a /plans');
      return await _getPlanesTodos();
    }
  }

  Future<List<Map<String, dynamic>>> _getPlanesTodos() async {
    final raw = await _api.get('/payments/paypal/plans', auth: true);
    debugPrint('[PayPal] /plans raw response: $raw');
    final lista = _parseLista(raw);
    debugPrint('[PayPal] /plans parsed: ${lista.length} planes');
    // Log de cada plan para diagnosticar campos
    for (final p in lista) {
      debugPrint('[PayPal] plan keys: ${p.keys.toList()} | rol_objetivo: ${p['rol_objetivo']} | periodicidad: ${p['periodicidad']} | codigo: ${p['codigo']}');
    }
    return lista;
  }

  // ── FIX PRINCIPAL: Parser robusto que maneja todas las estructuras posibles ──
  List<Map<String, dynamic>> _parseLista(dynamic raw) {
    // Caso 1: ya es una lista directamente
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }

    // Caso 2: es un Map — buscar la lista dentro de campos conocidos
    if (raw is Map) {
      final posiblesKeys = ['data', 'plans', 'results', 'items', 'planes'];
      for (final key in posiblesKeys) {
        final val = raw[key];
        if (val is List && val.isNotEmpty) {
          return val.whereType<Map<String, dynamic>>().toList();
        }
      }

      // Caso 3: el Map mismo es un plan único (edge case)
      if (raw.containsKey('id') && raw.containsKey('precio')) {
        return [Map<String, dynamic>.from(raw)];
      }
    }

    return [];
  }

  // POST /payments/paypal/subscriptions
  Future<Map<String, dynamic>> crearSuscripcion({
    required String billingCycle,
    required String returnUrl,
    required String cancelUrl,
  }) async {
    // El backend acepta billing_cycle: "mensual" | "semestral" | "anual"
    final body = {
      'billing_cycle': billingCycle,
      'return_url':    returnUrl,
      'cancel_url':    cancelUrl,
    };
    debugPrint('[PayPal] POST /subscriptions body: $body');
    return await _api.post('/payments/paypal/subscriptions', body, auth: true);
  }

  // POST /payments/paypal/subscriptions/{id}/sync
  Future<Map<String, dynamic>> sincronizar(String subscriptionId) async =>
      await _api.post(
          '/payments/paypal/subscriptions/$subscriptionId/sync', {},
          auth: true);

  // POST /payments/paypal/subscriptions/{id}/cancel
  Future<void> cancelar(String subscriptionId, {String? razon}) async =>
      await _api.post(
          '/payments/paypal/subscriptions/$subscriptionId/cancel',
          {'reason': razon ?? 'Cancelada por el usuario'},
          auth: true);

  // GET /suscripciones/usuario/{id}/actual
  Future<Map<String, dynamic>?> getSuscripcionActual(int userId) async {
    try {
      final raw = await _api.get(
          '/suscripciones/usuario/$userId/actual', auth: true);
      return raw is Map<String, dynamic> ? raw : null;
    } catch (_) {
      return null;
    }
  }
}