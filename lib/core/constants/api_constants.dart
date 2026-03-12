class ApiConstants {
  static const String baseUrl = 'https://api.jobmatch.com.mx';
  static const String apiV1 = '/api/v1';
  static const String apiBaseUrl = '$baseUrl$apiV1';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String login = '/auth/jwt/login';
  static const String logout = '/auth/jwt/logout';
  static const String refresh = '/auth/jwt/refresh';

  // ── User ──────────────────────────────────────────────────────────────────
  static const String createUser = '/user/';

  // ── Roles ─────────────────────────────────────────────────────────────────
  static const String roles = '/rol/';

  // ── Perfil Estudiante ─────────────────────────────────────────────────────
  static String perfilEstudiante(int usuarioId) =>
      '/perfil_estudiante/$usuarioId';

  // ── Perfil Empresa ────────────────────────────────────────────────────────
  static String perfilEmpresa(int userId) => '/perfil_empresa/$userId';

  // ── Vacantes ──────────────────────────────────────────────────────────────
  static const String vacantes = '/vacante/';
  static String vacante(int id) => '/vacante/$id';
  static String crearVacante(int empresaId) => '/vacante/$empresaId';

  // ── Swipes ────────────────────────────────────────────────────────────────
  static String swipeEstudiante(int estudianteId) => '/swipes/$estudianteId';
  static String swipeEmpresa(int empresaId) => '/swipes/empresa/$empresaId';

  // ── Postulaciones ─────────────────────────────────────────────────────────
  static const String crearPostulacionWeb = '/postulaciones/web';
  static String postulacionesEmpresa(int empresaId) =>
      '/postulaciones/empresa/$empresaId';
  static String cambiarEstadoPostulacion(int id) =>
      '/postulaciones/$id/estado';

  // ── Suscripciones ─────────────────────────────────────────────────────────
  static const String suscripciones = '/suscripciones/';
  static String suscripcionesUsuario(int usuarioId) =>
      '/suscripciones/usuario/$usuarioId';

  // ── Media ─────────────────────────────────────────────────────────────────
  static String fotoEstudiante(int usuarioId) =>
      '/media/estudiantes/$usuarioId/foto';
  static String cvEstudiante(int usuarioId) =>
      '/media/estudiantes/$usuarioId/cv';
  static String fotoEmpresa(int usuarioId) =>
      '/media/empresas/$usuarioId/foto';

  // ── Retroalimentación ────────────────────────────────────────────────────
  static const String crearRetroalimentacion = '/retroalimentacion/';
  static String retroPorPostulacion(int postulacionId) =>
      '/retroalimentacion/postulacion/$postulacionId';

  // ── Usuarios ─────────────────────────────────────────────────────────────
  static const String readUsers = '/user/';

  // ── Config ────────────────────────────────────────────────────────────────
  static const Duration timeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 30);
}