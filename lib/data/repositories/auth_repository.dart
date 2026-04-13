// lib/data/repositories/auth_repository.dart

import 'dart:convert';
import '../../core/constants/api_constants.dart';
import '../../core/errors/api_exceptions.dart';
import '../../core/services/api_service.dart';
import '../../core/services/token_storage.dart';
import '../models/auth_models.dart';

class AuthRepository {
  final _api     = ApiService.instance;
  final _storage = TokenStorage.instance;

  static int? _rolEstudianteId;
  static int? _rolEmpresaId;

  Future<int> _getRolEstudianteId() async =>
      _rolEstudianteId ?? (await _storage.getRolEstudianteId()) ?? 2;
  Future<int> _getRolEmpresaId() async =>
      _rolEmpresaId ?? (await _storage.getRolEmpresaId()) ?? 3;

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final json = await _api.post(
          ApiConstants.login, {'email': email, 'password': password});
      final tokens = TokenResponse.fromJson(json);
      await _storage.guardarTokens(
        accessToken:  tokens.accessToken,
        refreshToken: tokens.refreshToken,
        tokenType:    tokens.tokenType,
      );

      UserModel user;
      try {
        final me  = await _api.get('/user/me', auth: true);
        final map = me is Map<String, dynamic>
            ? me : (me['data'] as Map<String, dynamic>);
        user = UserModel.fromJson(map);
      } catch (_) {
        user = _userFromJwt(tokens.accessToken, email);
      }

      await _storage.guardarUsuario(
        userId: user.id, email: user.email,
        rolId: user.rolId, esPremium: user.esPremium,
      );
      return user;
    } on ApiException catch (e) {
      // Traducir errores crudos del backend a mensajes claros en español
      throw ApiException(
        message: _traducirErrorLogin(e.message),
        statusCode: e.statusCode,
      );
    }
  }

  // Traduce los errores crudos que devuelve FastAPI-Users al español claro
  String _traducirErrorLogin(String raw) {
    final r = raw.toLowerCase();

    // FastAPI-Users devuelve: "LOGIN_BAD_CREDENTIALS"
    if (r.contains('bad_credentials') || r.contains('bad credentials') ||
        r.contains('incorrect') || r.contains('login_bad')) {
      return 'Correo o contraseña incorrectos. Verifica tus datos.';
    }
    // "LOGIN_USER_NOT_VERIFIED"
    if (r.contains('not_verified') || r.contains('not verified') ||
        r.contains('unverified')) {
      return 'Tu cuenta no está verificada. Revisa tu correo.';
    }
    // "LOGIN_USER_NOT_ACTIVE" / "USER_INACTIVE"
    if (r.contains('not_active') || r.contains('not active') ||
        r.contains('inactive') || r.contains('inactiv')) {
      return 'Tu cuenta está inactiva. Contacta a soporte.';
    }
    // Ya está en español o es un mensaje genérico útil
    if (r.contains('correo') || r.contains('contraseña') ||
        r.contains('conexión') || r.contains('servidor') ||
        r.contains('tiempo')) {
      return raw;
    }
    // Fallback con el mensaje original entre paréntesis para debugging
    return 'Error al iniciar sesión. Intenta de nuevo.';
  }

  UserModel _userFromJwt(String accessToken, String email) {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) throw Exception('JWT malformado');
      String payload = parts[1]
          .replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '=';  break;
      }
      final claims = jsonDecode(
          utf8.decode(base64Decode(payload))) as Map<String, dynamic>;
      final userId = int.tryParse(claims['sub']?.toString() ?? '0') ?? 0;
      final role   = claims['role']?.toString() ?? 'estudiante';
      final rolId  = role == 'empresa' ? (_rolEmpresaId ?? 3)
                   : role == 'admin'   ? 1
                   : (_rolEstudianteId ?? 2);
      return UserModel(id: userId, email: email, rolId: rolId, esPremium: false);
    } catch (_) {
      return UserModel(id: 0, email: email, rolId: 2, esPremium: false);
    }
  }

  // ── Restaurar sesión ──────────────────────────────────────────────────────
  // FIX: también refresca esPremium desde el servidor al restaurar sesión
  Future<UserModel?> restaurarSesion() async {
    try {
      final token = await _storage.getAccessToken();
      if (token == null || token.isEmpty || _tokenExpirado(token)) {
        await _storage.limpiar(); return null;
      }

      // Intentar refrescar desde el servidor para tener esPremium actualizado
      try {
        final me  = await _api.get('/user/me', auth: true);
        final map = me is Map<String, dynamic>
            ? me : (me['data'] as Map<String, dynamic>);
        final user = UserModel.fromJson(map);
        // Actualizar cache local con el estado premium real
        await _storage.guardarUsuario(
          userId: user.id, email: user.email,
          rolId: user.rolId, esPremium: user.esPremium,
        );
        return user;
      } catch (_) {
        // Fallback a cache local si el servidor no responde
        final userId    = await _storage.getUserId();
        final email     = await _storage.getUserEmail();
        final rolId     = await _storage.getRolId();
        final esPremium = await _storage.getEsPremium();
        if (userId == null || email == null || rolId == null) return null;
        return UserModel(
            id: userId, email: email,
            rolId: rolId, esPremium: esPremium);
      }
    } catch (_) { await _storage.limpiar(); return null; }
  }

  bool _tokenExpirado(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      String p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (p.length % 4) {
        case 2: p += '=='; break;
        case 3: p += '='; break;
      }
      final claims = jsonDecode(
          utf8.decode(base64Decode(p))) as Map<String, dynamic>;
      final exp = claims['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().isAfter(
          DateTime.fromMillisecondsSinceEpoch(exp * 1000));
    } catch (_) { return true; }
  }

  // ── Registro Estudiante ───────────────────────────────────────────────────
  Future<UserModel> registrarEstudiante({
    required String email,
    required String password,
    required String nombreCompleto,
    required String institucionEducativa,
    required String nivelAcademico,
    required String fechaNacimiento,
    String? biografia,
    String? habilidades,
    String? ubicacion,
    String? modalidadPreferida,
  }) async {
    final rolId = await _getRolEstudianteId();
    final body  = UserCreateRequest(
      email:    email,
      password: password,
      rolId:    rolId,
      perfilEstudiante: PerfilEstudianteCreateDto(
        nombreCompleto:       nombreCompleto,
        institucionEducativa: institucionEducativa,
        nivelAcademico:       nivelAcademico,
        fechaNacimiento:      fechaNacimiento,
        biografia:            biografia,
        habilidades:          habilidades,
        ubicacion:            ubicacion,
        modalidadPreferida:   modalidadPreferida,
      ),
    ).toJson();
    await _api.post(ApiConstants.createUser, body, auth: false);
    _rolEstudianteId = rolId;
    await _storage.guardarRolEstudianteId(rolId);
    return await login(email: email, password: password);
  }

  // ── Registro Empresa ──────────────────────────────────────────────────────
  Future<UserModel> registrarEmpresa({
    required String email,
    required String password,
    required String nombreComercial,
    String? sector,
    String? descripcion,
    String? sitioWeb,
    String? ubicacionSede,
  }) async {
    final rolId = await _getRolEmpresaId();
    final body  = UserCreateRequest(
      email:    email,
      password: password,
      rolId:    rolId,
      perfilEmpresa: PerfilEmpresaCreateDto(
        nombreComercial: nombreComercial,
        sector:          sector,
        descripcion:     descripcion,
        sitioWeb:        sitioWeb,
        ubicacionSede:   ubicacionSede,
      ),
    ).toJson();
    await _api.post(ApiConstants.createUser, body, auth: false);
    _rolEmpresaId = rolId;
    await _storage.guardarRolEmpresaId(rolId);
    return await login(email: email, password: password);
  }

  // ── Cambiar contraseña ────────────────────────────────────────────────────
  Future<void> cambiarPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post('/user/me/password',
        {'current_password': currentPassword, 'new_password': newPassword},
        auth: true);
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try { await _api.post(ApiConstants.logout, {}, auth: true); } catch (_) {}
    finally { await _storage.limpiar(); }
  }
}