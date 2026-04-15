// lib/data/models/auth_models.dart

class UserModel {
  final int    id;
  final String email;
  final int    rolId;
  final bool   esPremium;

  UserModel({
    required this.id,
    required this.email,
    required this.rolId,
    required this.esPremium,
  });

  bool get esEstudiante => rolId == 2;
  bool get esEmpresa    => rolId == 3;

  factory UserModel.fromJson(Map<String, dynamic> j) {
    // Detectar rol por string o por id
    int rolId = j['rol_id'] as int? ?? 2;
    final rolStr = j['rol'] as String?;
    if (rolStr == 'empresa') {
      rolId = 3;
    } else if (rolStr == 'admin') rolId = 1;
    else if (rolStr == 'estudiante') rolId = 2;

    return UserModel(
      id:        j['id'] as int,
      email:     j['email'] as String,
      rolId:     rolId,
      esPremium: j['es_premium'] as bool? ?? false,
    );
  }
}

// ── Perfil Estudiante ──────────────────────────────────────────────────────
class PerfilEstudiante {
  final String  nombreCompleto;
  final String  institucionEducativa;
  final String  nivelAcademico;
  final String? biografia;
  final String? habilidades;
  final String? ubicacion;
  final String? modalidadPreferida;
  final int     usuarioId;
  final String? fechaNacimiento;   // ← NUEVO: "YYYY-MM-DD"
  final String? cvUrl;
  final String? cvTipoArchivo;
  final String? fotoPerfilUrl;

  PerfilEstudiante({
    required this.nombreCompleto,
    required this.institucionEducativa,
    required this.nivelAcademico,
    this.biografia,
    this.habilidades,
    this.ubicacion,
    this.modalidadPreferida,
    required this.usuarioId,
    this.fechaNacimiento,
    this.cvUrl,
    this.cvTipoArchivo,
    this.fotoPerfilUrl,
  });

  factory PerfilEstudiante.fromJson(Map<String, dynamic> j) => PerfilEstudiante(
    nombreCompleto:       j['nombre_completo']       as String,
    institucionEducativa: j['institucion_educativa'] as String,
    nivelAcademico:       j['nivel_academico']       as String,
    biografia:            j['biografia']             as String?,
    habilidades:          j['habilidades']?.toString(),
    ubicacion:            j['ubicacion']             as String?,
    modalidadPreferida:   j['modalidad_preferida']   as String?,
    usuarioId:            j['usuario_id']            as int,
    fechaNacimiento:      j['fecha_nacimiento']      as String?,
    cvUrl:                j['cv_url']                as String?,
    cvTipoArchivo:        j['cv_tipo_archivo']       as String?,
    fotoPerfilUrl:        j['foto_perfil_url']       as String?,
  );

  /// Calcula la edad a partir de fecha_nacimiento
  int? get edad {
    if (fechaNacimiento == null) return null;
    try {
      final nac  = DateTime.parse(fechaNacimiento!);
      final hoy  = DateTime.now();
      int   edad = hoy.year - nac.year;
      if (hoy.month < nac.month ||
          (hoy.month == nac.month && hoy.day < nac.day)) {
        edad--;
      }
      return edad;
    } catch (_) { return null; }
  }
}

// ── Perfil Empresa ─────────────────────────────────────────────────────────
class PerfilEmpresa {
  final String  nombreComercial;
  final String? sector;
  final String? descripcion;
  final String? sitioWeb;
  final String? ubicacionSede;
  final String? fotoPerfilUrl;
  final int     usuarioId;

  PerfilEmpresa({
    required this.nombreComercial,
    this.sector,
    this.descripcion,
    this.sitioWeb,
    this.ubicacionSede,
    this.fotoPerfilUrl,
    required this.usuarioId,
  });

  factory PerfilEmpresa.fromJson(Map<String, dynamic> j) => PerfilEmpresa(
    nombreComercial: j['nombre_comercial'] as String,
    sector:          j['sector']          as String?,
    descripcion:     j['descripcion']     as String?,
    sitioWeb:        j['sitio_web']       as String?,
    ubicacionSede:   j['ubicacion_sede']  as String?,
    fotoPerfilUrl:   j['foto_perfil_url'] as String?,
    usuarioId:       j['usuario_id']      as int,
  );
}

// ── DTOs para registro ─────────────────────────────────────────────────────
class PerfilEstudianteCreateDto {
  final String  nombreCompleto;
  final String  institucionEducativa;
  final String  nivelAcademico;
  final String  fechaNacimiento;   // ← NUEVO requerido
  final String? biografia;
  final String? habilidades;
  final String? ubicacion;
  final String? modalidadPreferida;

  PerfilEstudianteCreateDto({
    required this.nombreCompleto,
    required this.institucionEducativa,
    required this.nivelAcademico,
    required this.fechaNacimiento,
    this.biografia,
    this.habilidades,
    this.ubicacion,
    this.modalidadPreferida,
  });

  Map<String, dynamic> toJson() => {
    'nombre_completo':       nombreCompleto,
    'institucion_educativa': institucionEducativa,
    'nivel_academico':       nivelAcademico,
    'fecha_nacimiento':      fechaNacimiento,
    if (biografia   != null) 'biografia':           biografia,
    if (habilidades != null) 'habilidades':          habilidades,
    if (ubicacion   != null) 'ubicacion':            ubicacion,
    if (modalidadPreferida != null)
      'modalidad_preferida': modalidadPreferida,
  };
}

class PerfilEmpresaCreateDto {
  final String  nombreComercial;
  final String? sector;
  final String? descripcion;
  final String? sitioWeb;
  final String? ubicacionSede;

  PerfilEmpresaCreateDto({
    required this.nombreComercial,
    this.sector, this.descripcion,
    this.sitioWeb, this.ubicacionSede,
  });

  Map<String, dynamic> toJson() => {
    'nombre_comercial': nombreComercial,
    if (sector       != null) 'sector':         sector,
    if (descripcion  != null) 'descripcion':    descripcion,
    if (sitioWeb     != null) 'sitio_web':      sitioWeb,
    if (ubicacionSede!= null) 'ubicacion_sede': ubicacionSede,
  };
}

class UserCreateRequest {
  final String                   email;
  final String                   password;
  final int                      rolId;
  final PerfilEstudianteCreateDto? perfilEstudiante;
  final PerfilEmpresaCreateDto?    perfilEmpresa;

  UserCreateRequest({
    required this.email,
    required this.password,
    required this.rolId,
    this.perfilEstudiante,
    this.perfilEmpresa,
  });

  Map<String, dynamic> toJson() => {
    'email':    email,
    'password': password,
    'rol_id':   rolId,
    if (perfilEstudiante != null) 'perfil_estudiante': perfilEstudiante!.toJson(),
    if (perfilEmpresa    != null) 'perfil_empresa':    perfilEmpresa!.toJson(),
  };
}

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int    accessTokenExpiresIn;
  final int    refreshTokenExpiresIn;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessTokenExpiresIn,
    required this.refreshTokenExpiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> j) => TokenResponse(
    accessToken:             j['access_token']              as String,
    refreshToken:            j['refresh_token']             as String,
    tokenType:               j['token_type']                as String? ?? 'bearer',
    accessTokenExpiresIn:    j['access_token_expires_in']   as int? ?? 3600,
    refreshTokenExpiresIn:   j['refresh_token_expires_in']  as int? ?? 86400,
  );
}