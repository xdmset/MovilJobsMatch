// lib/data/repositories/paypal_repository.dart

import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';

class PaypalRepository {
  PaypalRepository._();
  static final PaypalRepository instance = PaypalRepository._();
  final _api = ApiService.instance;

  // GET /payments/paypal/plans
  // Puede devolver: [ {plan_code, name, price, ...}, ... ]
  Future<List<Map<String, dynamic>>> getPlanes() async {
    final raw = await _api.get('/payments/paypal/plans', auth: true);
    debugPrint('[PayPal] /plans raw response: $raw');
    List lista;
    if (raw is List) {
      lista = raw;
    } else if (raw is Map) {
      // Algunos backends envuelven en { data: [...] } o { plans: [...] }
      lista = raw['data'] as List? ??
          raw['plans'] as List? ??
          raw['results'] as List? ??
          [];
    } else {
      lista = [];
    }
    return lista.cast<Map<String, dynamic>>();
  }

  // POST /payments/paypal/subscriptions
  // Body REQUERIDO: { plan_code, billing_cycle, return_url, cancel_url }
  Future<Map<String, dynamic>> crearSuscripcion({
    required String planCode,
    required String billingCycle,
    required String returnUrl,
    required String cancelUrl,
  }) async {
    final body = {
      'plan_code': planCode,
      'billing_cycle': billingCycle,
      'return_url': returnUrl,
      'cancel_url': cancelUrl,
    };
    debugPrint('[PayPal] POST /subscriptions body: $body');
    return await _api.post('/payments/paypal/subscriptions', body, auth: true);
  }

  // POST /payments/paypal/subscriptions/{id}/sync
  Future<Map<String, dynamic>> sincronizar(String subscriptionId) async =>
      await _api.post('/payments/paypal/subscriptions/$subscriptionId/sync', {},
          auth: true);

  // POST /payments/paypal/subscriptions/{id}/cancel
  Future<void> cancelar(String subscriptionId, {String? razon}) async =>
      await _api.post('/payments/paypal/subscriptions/$subscriptionId/cancel',
          {'reason': razon ?? 'Cancelada por el usuario'},
          auth: true);

  // GET /suscripciones/usuario/{id}/actual
  Future<Map<String, dynamic>?> getSuscripcionActual(int userId) async {
    try {
      final raw =
          await _api.get('/suscripciones/usuario/$userId/actual', auth: true);
      return raw is Map<String, dynamic> ? raw : null;
    } catch (_) {
      return null;
    }
  }
}
