import 'package:shared_preferences/shared_preferences.dart';

/// Persiste el JWT, refresh token e info básica del usuario
/// usando SharedPreferences.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _kAccessToken = 'jm_access_token';
  static const _kRefreshToken = 'jm_refresh_token';
  static const _kTokenType = 'jm_token_type';
  static const _kUserId = 'jm_user_id';
  static const _kUserEmail = 'jm_user_email';
  static const _kRolId = 'jm_rol_id';
  static const _kEsPremium = 'jm_es_premium';
  // IDs reales de roles (se resuelven tras el primer login exitoso)
  static const _kRolEstudianteId = 'jm_rol_estudiante_id';
  static const _kRolEmpresaId = 'jm_rol_empresa_id';

  // ── Guardar tras login ────────────────────────────────────────────────────
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
    required String tokenType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kRefreshToken, refreshToken);
    await prefs.setString(_kTokenType, tokenType);
  }

  Future<void> guardarUsuario({
    required int userId,
    required String email,
    required int rolId,
    required bool esPremium,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kUserEmail, email);
    await prefs.setInt(_kRolId, rolId);
    await prefs.setBool(_kEsPremium, esPremium);
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefreshToken);
  }

  Future<String> getAuthHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAccessToken) ?? '';
    final type = prefs.getString(_kTokenType) ?? 'Bearer';
    return '$type $token';
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUserId);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserEmail);
  }

  Future<int?> getRolId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kRolId);
  }

  Future<bool> getEsPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEsPremium) ?? false;
  }

  Future<void> guardarRolEstudianteId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRolEstudianteId, id);
  }

  Future<void> guardarRolEmpresaId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRolEmpresaId, id);
  }

  Future<int?> getRolEstudianteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kRolEstudianteId);
  }

  Future<int?> getRolEmpresaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kRolEmpresaId);
  }

  Future<bool> tieneToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Limpiar al hacer logout ───────────────────────────────────────────────
  // NOTA: NO borramos _kRolEstudianteId / _kRolEmpresaId — son constantes
  // del servidor que no cambian entre sesiones. Mantenerlos evita el
  // brute-force de rol_id en futuros registros.
  Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kTokenType);
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserEmail);
    await prefs.remove(_kRolId);
    await prefs.remove(_kEsPremium);
  }
}