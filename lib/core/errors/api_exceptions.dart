// lib/core/errors/api_exceptions.dart

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';

  // ── Desde código HTTP ─────────────────────────────────────────────────────
  factory ApiException.fromStatusCode(int code, Map<String, dynamic>? body) {
    final detail = _extractDetail(body);

    switch (code) {
      case 400:
        return ApiException(
          message: detail ?? 'Datos inválidos. Verifica los campos.',
          statusCode: 400,
        );

      case 401:
        // FastAPI devuelve mensajes distintos según el motivo
        if (detail != null) {
          final d = detail.toLowerCase();
          if (d.contains('incorrect') || d.contains('password') ||
              d.contains('contraseña') || d.contains('credentials')) {
            return const ApiException(
              message: 'Correo o contraseña incorrectos.',
              statusCode: 401,
            );
          }
          if (d.contains('not active') || d.contains('inactiv')) {
            return const ApiException(
              message: 'Tu cuenta está inactiva. Contacta soporte.',
              statusCode: 401,
            );
          }
          if (d.contains('not verified') || d.contains('verif')) {
            return const ApiException(
              message: 'Tu cuenta no está verificada.',
              statusCode: 401,
            );
          }
        }
        return const ApiException(
          message: 'Correo o contraseña incorrectos.',
          statusCode: 401,
        );

      case 403:
        if (detail != null) {
          final d = detail.toLowerCase();
          if (d.contains('premium') || d.contains('límite') ||
              d.contains('limite') || d.contains('swipe')) {
            return ApiException(message: detail, statusCode: 403);
          }
        }
        return const ApiException(
          message: 'No tienes permisos para realizar esta acción.',
          statusCode: 403,
        );

      case 404:
        return ApiException(
          message: detail ?? 'El recurso solicitado no existe.',
          statusCode: 404,
        );

      case 409:
        if (detail != null) {
          final d = detail.toLowerCase();
          if (d.contains('email') || d.contains('correo') ||
              d.contains('already') || d.contains('existe') ||
              d.contains('registered')) {
            return const ApiException(
              message: 'Este correo ya está registrado.',
              statusCode: 409,
            );
          }
          return ApiException(message: detail, statusCode: 409);
        }
        return const ApiException(
          message: 'El recurso ya existe.',
          statusCode: 409,
        );

      case 422:
        // FastAPI devuelve: { "detail": [{ "loc": [...], "msg": "...", "type": "..." }] }
        final raw = body?['detail'];
        if (raw is List && raw.isNotEmpty) {
          final msgs = raw
              .map((e) => e['msg']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          if (msgs.isNotEmpty) {
            return ApiException(
              message: msgs.join('. '),
              statusCode: 422,
            );
          }
        }
        return ApiException(
          message: detail ?? 'Datos del formulario inválidos.',
          statusCode: 422,
        );

      case 429:
        return const ApiException(
          message: 'Demasiados intentos. Espera un momento e intenta de nuevo.',
          statusCode: 429,
        );

      case 500:
        return const ApiException(
          message: 'Error interno del servidor. Intenta más tarde.',
          statusCode: 500,
        );

      case 502:
      case 503:
      case 504:
        return const ApiException(
          message: 'El servidor no está disponible. Intenta más tarde.',
          statusCode: 503,
        );

      default:
        return ApiException(
          message: detail ?? 'Error inesperado (código $code).',
          statusCode: code,
        );
    }
  }

  // Extrae el mensaje de error de cualquier formato que devuelva el backend
  static String? _extractDetail(Map<String, dynamic>? body) {
    if (body == null) return null;

    // FastAPI string: { "detail": "mensaje" }
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;

    // FastAPI lista: { "detail": [{ "msg": "..." }] }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map) {
        final msg = first['msg'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
      }
    }

    // Otros formatos comunes
    final message = body['message'] as String?;
    if (message != null && message.isNotEmpty) return message;

    final error = body['error'] as String?;
    if (error != null && error.isNotEmpty) return error;

    return null;
  }

  // ── Constructores de conveniencia ─────────────────────────────────────────
  // (mantenidos idénticos al original para compatibilidad)

  factory ApiException.network() => const ApiException(
    message: 'Sin conexión al servidor. Revisa tu internet e intenta de nuevo.',
  );

  factory ApiException.timeout() => const ApiException(
    message: 'El servidor tardó demasiado en responder. Intenta de nuevo.',
  );

  factory ApiException.unauthorized() => const ApiException(
    message: 'Sesión expirada. Inicia sesión de nuevo.',
    statusCode: 401,
  );

  factory ApiException.forbidden() => const ApiException(
    message: 'No tienes permisos para realizar esta acción.',
    statusCode: 403,
  );

  factory ApiException.notFound() => const ApiException(
    message: 'El recurso solicitado no existe.',
    statusCode: 404,
  );

  factory ApiException.conflict(String detail) => ApiException(
    message: detail,
    statusCode: 409,
  );

  factory ApiException.unprocessable(Map<String, dynamic>? body) {
    String msg = 'Datos inválidos.';
    final detail = body?['detail'];
    if (detail is List && detail.isNotEmpty) {
      final msgs = detail
          .map((e) => e['msg']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (msgs.isNotEmpty) msg = msgs.join('. ');
    }
    return ApiException(message: msg, statusCode: 422);
  }

  factory ApiException.serverError() => const ApiException(
    message: 'Error del servidor. Intenta más tarde.',
    statusCode: 500,
  );

  // Alias mantenido por compatibilidad
  factory ApiException.networkError() => const ApiException(
    message: 'Sin conexión al servidor. Revisa tu internet e intenta de nuevo.',
  );
}