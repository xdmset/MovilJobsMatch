// ═══════════════════════════════════════════════════════════════════
// Modelos que mapean 1:1 con los schemas del OpenAPI de JobMatch
// ═══════════════════════════════════════════════════════════════════

// ── Token (respuesta de login y refresh) ──────────────────────────
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessTokenExpiresIn;
  final int refreshTokenExpiresIn;

  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessTokenExpiresIn,
    required this.refreshTokenExpiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> j) => TokenResponse(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
        tokenType: j['token_type'] as String? ?? 'Bearer',
        accessTokenExpiresIn: j['access_token_expires_in'] as int? ?? 3600,
        refreshTokenExpiresIn: j['refresh_token_expires_in'] as int? ?? 86400,
      );
}

// ── Role ──────────────────────────────────────────────────────────
class RoleModel {
  final int id;
  final String nombre; // 'admin' | 'estudiante' | 'empresa'

  const RoleModel({required this.id, required this.nombre});

  factory RoleModel.fromJson(Map<String, dynamic> j) => RoleModel(
        id: j['id'] as int,
        nombre: j['nombre'] as String,
      );
}

// ── User (respuesta de registro y /user/) ─────────────────────────
// Schema: { email, id, rol_id, es_premium, fecha_registro }
class UserModel {
  final int id;
  final String email;
  final int rolId;
  final bool esPremium;
  final DateTime? fechaRegistro;

  const UserModel({
    required this.id,
    required this.email,
    required this.rolId,
    required this.esPremium,
    this.fechaRegistro,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as int,
        email: j['email'] as String,
        rolId: j['rol_id'] as int,
        esPremium: j['es_premium'] as bool? ?? false,
        fechaRegistro: j['fecha_registro'] != null
            ? DateTime.tryParse(j['fecha_registro'] as String)
            : null,
      );

  /// rolId: 1=admin, 2=estudiante, 3=empresa
  /// Estos IDs los resolvemos en tiempo de ejecución consultando /rol/
  bool get esEstudiante => rolId == 2;
  bool get esEmpresa => rolId == 3;
  bool get esAdmin => rolId == 1;
}

// ── UserCreate (body para POST /user/) ────────────────────────────
// Schema: { email, password, rol_id, perfil_estudiante?, perfil_empresa? }
class UserCreateRequest {
  final String email;
  final String password;
  final int rolId;
  final PerfilEstudianteCreateDto? perfilEstudiante;
  final PerfilEmpresaCreateDto? perfilEmpresa;

  const UserCreateRequest({
    required this.email,
    required this.password,
    required this.rolId,
    this.perfilEstudiante,
    this.perfilEmpresa,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'rol_id': rolId,
        if (perfilEstudiante != null)
          'perfil_estudiante': perfilEstudiante!.toJson(),
        if (perfilEmpresa != null)
          'perfil_empresa': perfilEmpresa!.toJson(),
      };
}

// ── PerfilEstudianteCreate ─────────────────────────────────────────
// Todos los campos son opcionales excepto los 3 requeridos.
// habilidades es STRING (no array) según el schema de la API.
class PerfilEstudianteCreateDto {
  final String nombreCompleto;        // requerido
  final String institucionEducativa;  // requerido
  final String nivelAcademico;        // requerido
  final String? biografia;
  final String? habilidades;          // string simple, ej: "Excel, Inglés"
  final String? ubicacion;
  final String? modalidadPreferida;   // "remoto" | "presencial" | "hibrido"

  const PerfilEstudianteCreateDto({
    required this.nombreCompleto,
    required this.institucionEducativa,
    required this.nivelAcademico,
    this.biografia,
    this.habilidades,
    this.ubicacion,
    this.modalidadPreferida,
  });

  Map<String, dynamic> toJson() => {
        'nombre_completo': nombreCompleto,
        'institucion_educativa': institucionEducativa,
        'nivel_academico': nivelAcademico,
        if (biografia != null) 'biografia': biografia,
        if (habilidades != null) 'habilidades': habilidades,
        if (ubicacion != null) 'ubicacion': ubicacion,
        if (modalidadPreferida != null)
          'modalidad_preferida': modalidadPreferida,
      };
}

// ── PerfilEstudiante (respuesta) ──────────────────────────────────
class PerfilEstudiante {
  final int usuarioId;
  final String nombreCompleto;
  final String institucionEducativa;
  final String nivelAcademico;
  final String? biografia;
  final String? habilidades;  // string simple
  final String? ubicacion;
  final String? modalidadPreferida;
  final String? cvUrl;
  final String? cvTipoArchivo;
  final String? fotoPerfilUrl;

  const PerfilEstudiante({
    required this.usuarioId,
    required this.nombreCompleto,
    required this.institucionEducativa,
    required this.nivelAcademico,
    this.biografia,
    this.habilidades,
    this.ubicacion,
    this.modalidadPreferida,
    this.cvUrl,
    this.cvTipoArchivo,
    this.fotoPerfilUrl,
  });

  factory PerfilEstudiante.fromJson(Map<String, dynamic> j) =>
      PerfilEstudiante(
        usuarioId: j['usuario_id'] as int,
        nombreCompleto: j['nombre_completo'] as String,
        institucionEducativa: j['institucion_educativa'] as String,
        nivelAcademico: j['nivel_academico'] as String,
        biografia: j['biografia'] as String?,
        habilidades: j['habilidades'] as String?,
        ubicacion: j['ubicacion'] as String?,
        modalidadPreferida: j['modalidad_preferida'] as String?,
        cvUrl: j['cv_url'] as String?,
        cvTipoArchivo: j['cv_tipo_archivo'] as String?,
        fotoPerfilUrl: j['foto_perfil_url'] as String?,
      );

  /// Convierte el string "Excel, Inglés, Python" en lista para mostrar en UI
  List<String> get habilidadesLista {
    if (habilidades == null || habilidades!.trim().isEmpty) return [];
    return habilidades!.split(',').map((h) => h.trim()).toList();
  }
}

// ── PerfilEmpresaCreate ───────────────────────────────────────────
class PerfilEmpresaCreateDto {
  final String nombreComercial;
  final String? sector;
  final String? descripcion;
  final String? sitioWeb;
  final String? ubicacionSede;

  const PerfilEmpresaCreateDto({
    required this.nombreComercial,
    this.sector,
    this.descripcion,
    this.sitioWeb,
    this.ubicacionSede,
  });

  Map<String, dynamic> toJson() => {
        'nombre_comercial': nombreComercial,
        if (sector != null) 'sector': sector,
        if (descripcion != null) 'descripcion': descripcion,
        if (sitioWeb != null) 'sitio_web': sitioWeb,
        if (ubicacionSede != null) 'ubicacion_sede': ubicacionSede,
      };
}

// ── PerfilEmpresa (respuesta) ─────────────────────────────────────
class PerfilEmpresa {
  final int usuarioId;
  final String nombreComercial;
  final String? sector;
  final String? descripcion;
  final String? sitioWeb;
  final String? ubicacionSede;
  final String? fotoPerfilUrl;

  const PerfilEmpresa({
    required this.usuarioId,
    required this.nombreComercial,
    this.sector,
    this.descripcion,
    this.sitioWeb,
    this.ubicacionSede,
    this.fotoPerfilUrl,
  });

  factory PerfilEmpresa.fromJson(Map<String, dynamic> j) => PerfilEmpresa(
        usuarioId: j['usuario_id'] as int,
        nombreComercial: j['nombre_comercial'] as String,
        sector: j['sector'] as String?,
        descripcion: j['descripcion'] as String?,
        sitioWeb: j['sitio_web'] as String?,
        ubicacionSede: j['ubicacion_sede'] as String?,
        fotoPerfilUrl: j['foto_perfil_url'] as String?,
      );
}