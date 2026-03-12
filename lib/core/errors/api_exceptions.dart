class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';

  factory ApiException.fromStatusCode(int code, Map<String, dynamic>? body) {
    final detail = body?['detail'];

    switch (code) {
      case 400:
        return ApiException(
          message: detail?.toString() ?? 'Solicitud inválida.',
          statusCode: 400,
        );
      case 401:
        return const ApiException(
          message: 'Email o contraseña incorrectos.',
          statusCode: 401,
        );
      case 403:
        return const ApiException(
          message: 'No tienes permisos para esta acción.',
          statusCode: 403,
        );
      case 404:
        return const ApiException(
          message: 'Recurso no encontrado.',
          statusCode: 404,
        );
      case 409:
        return ApiException(
          message: detail?.toString() ?? 'El recurso ya existe.',
          statusCode: 409,
        );
      case 422:
        // FastAPI validation errors: [{loc, msg, type}]
        String msg = 'Datos inválidos.';
        if (detail is List && detail.isNotEmpty) {
          final msgs = detail
              .map((e) => e['msg']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          if (msgs.isNotEmpty) msg = msgs.join('. ');
        }
        return ApiException(message: msg, statusCode: 422);
      case 500:
      default:
        return const ApiException(
          message: 'Error del servidor. Intenta más tarde.',
          statusCode: 500,
        );
    }
  }

  factory ApiException.network() => const ApiException(
        message: 'Sin conexión a internet. Verifica tu red.',
      );

  factory ApiException.timeout() => const ApiException(
        message: 'Tiempo de espera agotado. Intenta de nuevo.',
      );

  factory ApiException.unauthorized() => const ApiException(
        message: 'No autenticado. Inicia sesión.',
        statusCode: 401,
      );

  factory ApiException.forbidden() => const ApiException(
        message: 'No tienes permisos para esta acción :( .',
        statusCode: 403,
      );

  factory ApiException.notFound() => const ApiException(
        message: 'Recurso no encontrado.',
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

  factory ApiException.networkError() => const ApiException(
        message: 'Sin conexión a internet. Verifica tu red.',
      );
}