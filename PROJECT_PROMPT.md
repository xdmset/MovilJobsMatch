# 📱 JobMatch Mobile App - Prompt del Proyecto

**Nombre:** JobMatch - Conectando talento con oportunidades  
**Tipo:** Aplicación Flutter (multiplataforma)  
**Versión:** 1.0.0+1  
**SDK Dart:** >=3.0.0 <4.0.0  
**Estado:** En desarrollo

---

## 🎯 Descripción General

JobMatch es una aplicación móvil tipo Tinder para conectar estudiantes con oportunidades laborales. Permite que:
- **Estudiantes**: Busquen vacantes, hagan swipes (like/dislike), vean matches y apliquen a posiciones
- **Empresas**: Publiquen vacantes, evalúen candidatos, gestionionen postulaciones y brinden retroalimentación
- **Administradores**: Moderación de contenido y gestión del sistema

La app implementa **Clean Architecture** con capas bien definidas.

---

## 🏗️ Arquitectura del Proyecto

### Estructura de carpetas principales:

```
lib/
├── main.dart                    # Punto de entrada
├── config/
│   └── routes.dart             # Configuración de rutas (router go_router)
├── core/                        # Lógica transversal
│   ├── constants/
│   │   ├── api_constants.dart  # URLs, endpoints base
│   │   ├── app_colors.dart     # Paleta de colores
│   │   ├── app_routes.dart     # Rutas de navegación
│   │   └── app_text_styles.dart # Estilos de texto
│   ├── errors/
│   │   ├── api_exceptions.dart # Excepciones API
│   │   └── failures.dart       # Failures para manejo de errores
│   ├── services/
│   │   ├── api_service.dart    # Cliente HTTP centralizado
│   │   └── token_storage.dart  # Persistencia de tokens JWT
│   ├── theme/
│   │   └── app_theme.dart      # Temas light/dark
│   └── utils/
│       ├── date_formatter.dart
│       ├── snackbar_helper.dart
│       └── validators.dart     # Validaciones (email, contraseña, etc.)
├── data/                        # Capa de datos
│   ├── models/                 # DTOs - Mapeos de API
│   │   ├── auth_models.dart
│   │   ├── application_model.dart
│   │   ├── company_model.dart
│   │   ├── match_model.dart
│   │   ├── message_model.dart
│   │   ├── student_model.dart
│   │   ├── user_model.dart
│   │   └── vacancy_model.dart
│   ├── repositories/           # Implementación de repositorios
│   │   ├── auth_repository.dart
│   │   ├── vacancy_repository.dart
│   │   ├── match_repository.dart
│   │   ├── student_repository.dart
│   │   ├── company_repository.dart
│   │   ├── paypal_repository.dart
│   │   ├── chat_repository.dart
│   │   └── media_repository.dart
│   └── services/               # Servicios de datos
│       ├── notification_service.dart
│       └── storage_service.dart
├── domain/                      # Capa de lógica de negocio
│   ├── entities/               # Modelos puros de negocio
│   │   ├── user.dart
│   │   ├── student.dart
│   │   ├── company.dart
│   │   ├── vacancy.dart
│   │   ├── match.dart
│   │   └── application.dart
│   └── usecases/               # Casos de uso
│       ├── auth/
│       │   ├── login_usecase.dart
│       │   └── register_usecase.dart
│       ├── company/
│       │   ├── create_vacancy_usecase.dart
│       │   └── manage_applications_usecase.dart
│       └── student/
│           ├── get_matches_usecase.dart
│           └── swipe_vacancy_usecase.dart
├── presentation/               # Capa de UI
│   ├── providers/              # StateManagement con Provider
│   │   ├── auth_provider.dart
│   │   ├── student_provider.dart
│   │   ├── vacancy_provider.dart
│   │   ├── company_provider.dart
│   │   ├── match_provider.dart
│   │   ├── perfil_provider.dart
│   │   ├── settings_provider.dart
│   │   └── theme_provider.dart
│   ├── screens/                # Pantallas
│   │   ├── admin/
│   │   │   ├── dashboard_screen.dart
│   │   │   └── moderation_screen.dart
│   │   ├── auth/
│   │   │   ├── welcome_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── register_student_screen.dart
│   │   │   └── register_company_screen.dart
│   │   ├── splash/
│   │   │   └── splash_screen.dart
│   │   ├── student/
│   │   │   ├── student_shell_screen.dart
│   │   │   ├── home/
│   │   │   ├── applications/
│   │   │   ├── ai_feedback/
│   │   │   ├── activity/
│   │   │   └── [más screens]
│   │   ├── company/
│   │   │   ├── company_shell_screen.dart
│   │   │   ├── home/
│   │   │   ├── vacancies/
│   │   │   ├── candidates/      # ← Pantalla actual
│   │   │   ├── premium/
│   │   │   ├── profile/
│   │   │   └── settings/
│   │   └── common/
│   │       ├── premium_screen.dart
│   │       └── settings_screen.dart
│   └── widgets/                # Widgets reutilizables
│       ├── bottom_nav_bar.dart
│       ├── custom_app_bar.dart
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       ├── empty_state.dart
│       └── loading_indicator.dart
└── RegisterRequest/
    └── repositories/
```

---

## 📦 Dependencias Principales

```yaml
# Estado & Navegación
provider: ^6.0.0          # State management
go_router: ^11.0.0        # Routing

# Networking
dio: ^5.0.0              # HTTP client
retrofit: ^4.0.0         # REST client generator

# Persistencia
sqflite: ^2.2.0          # Base datos local SQLite
shared_preferences: ^2.0.0 # Almacenamiento clave-valor
flutter_secure_storage:  # Almacenamiento seguro de tokens

# Autenticación
firebase_auth: ^4.0.0    # Autenticación Firebase
jwt_decoder: ^2.0.0      # Decodificación JWT

# Multimedia
image_picker: ^0.8.0     # Selección de imágenes
file_picker: ^5.0.0      # Selector de archivos
flutter_inappwebview:    # Web view para pagos PayPal

# Utilidades
intl: ^0.18.0            # Internacionalización
uuid: ^3.0.0             # Generación de UUIDs
logger: ^1.3.0           # Logging

# UI/UX
flutter_svg: ^2.0.0      # Soporte SVG
lottie: ^2.0.0           # Animaciones Lottie
url_launcher: ^6.0.0     # Abrir enlaces
path_provider: ^2.0.0    # Rutas del sistema

# PayPal
paypal_checkout: ^1.0.0  # Pagos PayPal
```

---

## 🔐 Proveedores (State Management)

La app usa **Provider** como gestor de estado. Proveedores principales:

### 1. **AuthProvider**
```dart
// Gestiona:
- Login/Logout
- Registro de estudiante/empresa
- Token JWT (access + refresh)
- Usuario actual (email, rol, id)
- Estado de autenticación
- Reset de tema en logout
```

### 2. **ThemeProvider**
```dart
// Gestiona:
- Tema claro/oscuro
- Idioma/Locale
- Persistencia de preferencias
```

### 3. **StudentProvider**
```dart
// Gestiona:
- Perfil del estudiante
- Lista de vacantes (feed de swipes)
- Matches
- Postulaciones
- Historial de actividades
```

### 4. **CompanyProvider**
```dart
// Gestiona:
- Perfil de la empresa
- Vacantes publicadas
- Candidatos/aplicantes
- Estados de postulaciones
- Análiticas de vacantes
```

### 5. **VacancyProvider**
```dart
// Gestiona:
- CRUD de vacantes
- Filtros (modalidad, ubicación, sueldo)
- Vista detallada de vacante
- Historial de visualizaciones
```

### 6. **MatchProvider**
```dart
// Gestiona:
- Historial de matches
- Matches activos
- Comunicación entre matches
```

### 7. **PerfilProvider**
```dart
// Gestiona:
- Datos de perfil (estudiante/empresa)
- Edición de perfil
- Carga de foto y CV
```

### 8. **SettingsProvider**
```dart
// Gestiona:
- Configuraciones de usuario
- Privacidad
- Notificaciones
```

---

## 🔌 API Endpoints (OpenAPI 3.1.0)

**Base URL:** `/api/v1`

### 🔒 Autenticación

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/auth/jwt/login` | Login con email y password. Retorna access_token, refresh_token |
| `POST` | `/auth/jwt/refresh` | Refrescar access token usando refresh token |
| `POST` | `/auth/jwt/logout` | Logout (requiere OAuth2) |

**Request Login:**
```json
{
  "email": "usuario@test.com",
  "password": "contraseña"
}
```

**Response:**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "Bearer",
  "access_token_expires_in": 3600,
  "refresh_token_expires_in": 2592000
}
```

---

### 👤 Usuarios (User Management)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/user/` | Listar usuarios (con skip/limit) |
| `POST` | `/user/` | Crear nuevo usuario |
| `GET` | `/user/me` | Obtener usuario actual con todo su perfil |
| `GET` | `/user/{user_id}` | (N/A - no listado) |
| `DELETE` | `/user/{user_id}` | Eliminar usuario |
| `POST` | `/user/me/password` | Cambiar contraseña |
| `POST` | `/user/premium/sync` | Sincronizar bandera de premium |

**UserMe Response:**
```json
{
  "email": "user@example.com",
  "id": 123,
  "rol_id": 1,
  "es_premium": true,
  "fecha_registro": "2024-01-15T10:30:00Z",
  "rol": "estudiante",
  "is_active": true,
  "is_superuser": false,
  "is_verified": true,
  "perfil_estudiante": { /* PerfilEstudiante */ },
  "perfil_empresa": { /* PerfilEmpresa */ }
}
```

---

### 📋 Roles (Role Management)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/rol/` | Listar roles |
| `POST` | `/rol/` | Crear rol (requiere nombre: "admin", "estudiante", "empresa") |
| `GET` | `/rol/{rol_id}` | Obtener rol por ID |
| `PUT` | `/rol/{rol_id}` | Actualizar rol |
| `DELETE` | `/rol/{rol_id}` | Eliminar rol |

---

### 📸 Media (Fotos y CV)

#### Estudiante Foto
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/media/estudiantes/{usuario_id}/foto` | Subir foto de perfil |
| `GET` | `/media/estudiantes/{usuario_id}/foto` | Obtener foto |
| `DELETE` | `/media/estudiantes/{usuario_id}/foto` | Eliminar foto |

#### Estudiante CV
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/media/estudiantes/{usuario_id}/cv` | Subir CV (PDF, DOC) |
| `GET` | `/media/estudiantes/{usuario_id}/cv` | Obtener CV |
| `DELETE` | `/media/estudiantes/{usuario_id}/cv` | Eliminar CV |

#### Empresa Foto
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/media/empresas/{usuario_id}/foto` | Subir logo/foto empresa |
| `GET` | `/media/empresas/{usuario_id}/foto` | Obtener foto |
| `DELETE` | `/media/empresas/{usuario_id}/foto` | Eliminar foto |

**MediaUploadResponse:**
```json
{
  "usuario_id": 123,
  "media_type": "foto",
  "object_name": "estudiantes/123/foto.jpg",
  "bucket": "jobmatch-media",
  "url": "https://cdn.example.com/...",
  "content_type": "image/jpeg",
  "size": 256000
}
```

---

### 👨‍🎓 Perfil Estudiante

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/perfil_estudiante/{usuario_id}` | Obtener perfil del estudiante |
| `POST` | `/perfil_estudiante/{usuario_id}` | Crear perfil (después de registro) |
| `PUT` | `/perfil_estudiante/{usuario_id}` | Actualizar perfil |
| `DELETE` | `/perfil_estudiante/{usuario_id}` | Eliminar perfil |

**PerfilEstudiante:**
```json
{
  "nombre_completo": "Juan Pérez",
  "institucion_educativa": "Universidad XYZ",
  "nivel_academico": "Pregrado",
  "biografia": "Estudiante de Ingeniería en Sistemas...",
  "habilidades": { "Python": 3, "React": 2, "SQL": 4 },
  "ubicacion": "Bogotá, Colombia",
  "modalidad_preferida": "Remoto",
  "usuario_id": 123,
  "fecha_nacimiento": "2002-05-20",
  "cv_url": "https://cdn.example.com/...",
  "cv_tipo_archivo": "pdf",
  "foto_perfil_url": "https://cdn.example.com/..."
}
```

---

### 🏢 Perfil Empresa

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/perfil_empresa/{user_id}` | Obtener perfil de empresa |
| `POST` | `/perfil_empresa/{user_id}` | Crear perfil |
| `PUT` | `/perfil_empresa/{user_id}` | Actualizar perfil |
| `DELETE` | `/perfil_empresa/{user_id}` | Eliminar perfil |

**PerfilEmpresa:**
```json
{
  "nombre_comercial": "Tech Solutions Inc",
  "sector": "Tecnología",
  "descripcion": "Empresa de desarrollo de software...",
  "sitio_web": "https://techsolutions.com",
  "ubicacion_sede": "Medellín, Colombia",
  "foto_perfil_url": "https://cdn.example.com/...",
  "usuario_id": 456
}
```

---

### 📣 Vacantes (Job Listings)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/vacante/` | Listar vacantes con filtros (RF-09) |
| `POST` | `/vacante/{empresa_id}` | Crear nueva vacante |
| `GET` | `/vacante/{vacante_id}` | Obtener detalle de vacante |
| `PUT` | `/vacante/{vacante_id}` | Actualizar vacante |
| `DELETE` | `/vacante/{vacante_id}` | Eliminar vacante |
| `POST` | `/vacante/{vacante_id}/view` | Registrar visualización |
| `GET` | `/vacante/historial/estudiante/{estudiante_id}` | Historial con analytics |
| `GET` | `/vacante/historial/empresa/{empresa_id}` | Historial empresa |

**Filtros disponibles (GET `/vacante/`):**
- `modalidad` - "remoto", "presencial", "hibrido"
- `ubicacion` - Ciudad o estado
- `sueldo_min` - Sueldo mínimo deseado

**Vacante:**
```json
{
  "id": 789,
  "titulo": "Senior Full Stack Developer",
  "descripcion": "Buscamos desarrollador con 5+ años...",
  "requisitos": "Python, React, PostgreSQL, Docker",
  "tipo_contrato": "Indefinido",
  "modalidad": "Remoto",
  "ubicacion": "Bogotá",
  "sueldo_minimo": 3000000,
  "sueldo_maximo": 5000000,
  "moneda": "COP",
  "estado": "activa",
  "empresa_id": 456,
  "fecha_publicacion": "2024-01-20T14:30:00Z"
}
```

---

### 💓 Swipes (Mecanismo de matching tipo Tinder)

#### Estudiante Swipes
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/swipes/{estudiante_id}/vacantes` | Feed con vacantes para hacer swipe |
| `POST` | `/swipes/{estudiante_id}` | Registrar swipe (like/dislike) |

**Request Swipe Estudiante:**
```json
{
  "vacante_id": 789,
  "interes_estudiante": true  // true = like, false = dislike
}
```

**Response (si hay match):**
```json
{
  "id": 1001,
  "estudiante_id": 123,
  "vacante_id": 789,
  "fecha_match": "2024-01-20T15:45:00Z"
}
```

#### Empresa Swipes
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/swipes/empresa/{empresa_id}/candidatos` | Feed con candidatos |
| `POST` | `/swipes/empresa/{empresa_id}` | Registrar swipe empresa |

**Parámetros GET (filtros):**
- `vacante_id` (requerido)
- `ubicacion`, `modalidad_preferida`, `institucion_educativa`, `nivel_academico`, `habilidad`

**Request Swipe Empresa:**
```json
{
  "estudiante_id": 123,
  "vacante_id": 789,
  "interes_empresa": true
}
```

---

### 🎯 Matches

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/matches/estudiante/{estudiante_id}` | Historial de matches del estudiante |

**MatchResponse:**
```json
{
  "id": 1001,
  "estudiante_id": 123,
  "vacante_id": 789,
  "fecha_match": "2024-01-20T15:45:00Z"
}
```

---

### 📨 Postulaciones (Applications)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/postulaciones/web` | Crear postulación (desde web/app) |
| `GET` | `/postulaciones/empresa/{empresa_id}` | Listar postulaciones de empresa |
| `PUT` | `/postulaciones/{postulacion_id}/estado` | Cambiar estado (RF-06, RF-11) |

**Request Crear Postulación:**
```json
{
  "estudiante_id": 123,
  "vacante_id": 789
}
```

**PostulacionRead:**
```json
{
  "id": 2001,
  "match_id": 1001,
  "estudiante_id": 123,
  "vacante_id": 789,
  "empresa_id": 456,
  "source": "swipe",
  "estado": "pendiente",
  "fecha_creacion": "2024-01-20T16:00:00Z",
  "fecha_actualizacion": "2024-01-20T16:00:00Z"
}
```

**Estados de postulación:**
- `pendiente` - En revisión
- `aceptada` - Empresa aceptó
- `rechazada` - Empresa rechazó
- `entrevista` - Avanzó a entrevista

**Request Cambiar Estado:**
```json
{
  "nuevo_estado": "entrevista",
  "feedback": {
    "campos_mejora": "SQL y Docker",
    "sugerencias_perfil": "Mejorar portfolio"
  }
}
```

---

### 💬 Retroalimentación (Feedback)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/retroalimentacion/` | Crear feedback (IA) |
| `GET` | `/retroalimentacion/{retroalimentacion_id}` | Obtener feedback |
| `GET` | `/retroalimentacion/postulacion/{postulacion_id}` | Feedback de postulación |
| `PUT` | `/retroalimentacion/{retroalimentacion_id}` | Actualizar |
| `DELETE` | `/retroalimentacion/{retroalimentacion_id}` | Eliminar |

**RetroalimentacionCreate:**
```json
{
  "postulacion_id": 2001,
  "campos_mejora": "SQL avanzado, Docker",
  "sugerencias_perfil": "Mejora tu portfolio con proyectos reales"
}
```

---

### 💳 Pagos (PayPal)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/payments/paypal/plans` | Listar planes de suscripción |
| `GET` | `/payments/paypal/plans/me` | Planes disponibles para usuario |
| `POST` | `/payments/paypal/bootstrap` | Crear catálogo PayPal |
| `POST` | `/payments/paypal/subscriptions` | Crear suscripción |
| `POST` | `/payments/paypal/subscriptions/{id}/sync` | Sincronizar estado |
| `POST` | `/payments/paypal/subscriptions/{id}/cancel` | Cancelar suscripción |
| `POST` | `/payments/paypal/webhook` | Webhook PayPal |

**PaypalPlanResponse:**
```json
{
  "id": 1,
  "codigo": "PLAN_STUDENT_PREMIUM",
  "nombre": "Premium Estudiante",
  "rol_objetivo": "estudiante",
  "periodicidad": "mensual",
  "paypal_product_id": "PROD-...",
  "paypal_plan_id": "I-...",
  "moneda": "USD",
  "precio": "9.99",
  "intervalo_unidad": "MONTH",
  "intervalo_conteo": 1,
  "activo": true
}
```

---

### 📅 Suscripciones

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/suscripciones/` | Listar suscripciones |
| `POST` | `/suscripciones/` | Crear suscripción |
| `GET` | `/suscripciones/usuario/{usuario_id}` | Suscripciones del usuario |
| `GET` | `/suscripciones/usuario/{usuario_id}/actual` | Suscripción actual |
| `GET` | `/suscripciones/{suscripcion_id}` | Obtener suscripción |
| `PUT` | `/suscripciones/{suscripcion_id}` | Actualizar |
| `DELETE` | `/suscripciones/{suscripcion_id}` | Eliminar |

**Suscripcion:**
```json
{
  "id": 101,
  "usuario_id": 123,
  "tipo_plan": "premium",
  "rol_objetivo": "estudiante",
  "codigo_plan": "PLAN_STUDENT_PREMIUM",
  "fecha_inicio": "2024-01-01",
  "fecha_fin": "2024-02-01"
}
```

---

## 🎨 Estilos y Colores

Definidos en `core/constants/app_colors.dart` y `core/constants/app_text_styles.dart`:

- **Colores primarios:** Azul profesional, verde (éxito), rojo (error)
- **Temas:** Light (blanco/grises) y Dark (gris oscuro/negro)
- **Tipografía:** Roboto (defecto Material), tamaños 12-32sp

---

## 🔑 Autenticación y Seguridad

### JWT (JSON Web Tokens)
- Almacenado con `flutter_secure_storage`
- Tokens dual: `access_token` (corta duración) + `refresh_token` (larga duración)
- Refresh automático cuando access expire

### Interceptores de HTTP
- Agregación automática de Bearer token
- Manejo de 401 (Unauthorized) → refrescar o logout
- Manejo de 403 (Forbidden) → mostrar error

### Roles
- `admin` - Administrador del sistema
- `estudiante` - Busca empleos
- `empresa` - Publica vacantes

---

## 🚀 Características Principales

### Para Estudiantes (RF-Student)
- ✅ Registro/Login
- ✅ Perfil con foto, CV, habilidades
- ✅ Swipe feed de vacantes (tipo Tinder)
- ✅ Matches automáticos (like mutuo)
- ✅ Historial de actividades
- ✅ Aplicación directa a vacantes
- ✅ Retroalimentación con IA
- ✅ Suscripción Premium
- ✅ Chat con empresas

### Para Empresas (RF-Company)
- ✅ Registro/Login
- ✅ Perfil empresarial
- ✅ CRUD de vacantes
- ✅ Feed de candidatos
- ✅ Gestión de postulaciones (estados)
- ✅ Análitica de vacantes
- ✅ Filtros avanzados
- ✅ Suscripción Premium
- ✅ Chat con candidatos

### General
- ✅ Notificaciones push
- ✅ Tema claro/oscuro
- ✅ Internacionalización
- ✅ Manejo de errores robusto

---

## 📁 Modelos de Datos Principales

### UserModel
```dart
class User {
  int id;
  String email;
  int rolId;
  bool esPremium;
  DateTime fechaRegistro;
}
```

### StudentModel
```dart
class PerfilEstudiante {
  int usuarioId;
  String nombreCompleto;
  String institucionEducativa;
  String nivelAcademico;
  String? biografia;
  Map<String, int>? habilidades;
  String? ubicacion;
  String? modalidadPreferida;
  String? cvUrl;
  String? fotoPerfigUrl;
}
```

### CompanyModel
```dart
class PerfilEmpresa {
  int usuarioId;
  String nombreComercial;
  String? sector;
  String? descripcion;
  String? sitioWeb;
  String? ubicacionSede;
  String? fotoPerfigUrl;
}
```

### VacancyModel
```dart
class Vacante {
  int id;
  String titulo;
  String descripcion;
  String? requisitos;
  String? tipoContrato;
  String modalidad; // remoto, presencial, hibrido
  String? ubicacion;
  double? sueldoMinimo;
  double? sueldoMaximo;
  String? moneda;
  String estado;
  int empresaId;
  DateTime fechaPublicacion;
}
```

### MatchModel
```dart
class Match {
  int id;
  int estudianteId;
  int vacanteId;
  DateTime fechaMatch;
}
```

---

## 🔄 Flujo de autenticación

1. **Login/Register** → POST `/auth/jwt/login` → Recibe tokens
2. **Store Tokens** → `token_storage.dart` (secure storage)
3. **Fetch User** → GET `/user/me` (con Bearer token)
4. **Load Perfil** → GET `/perfil_estudiante/{id}` o `/perfil_empresa/{id}`
5. **Navigate Home** → Go Router redirige a home basado en rol
6. **Token Refresh** → Si access expires, POST `/auth/jwt/refresh`
7. **Logout** → POST `/auth/jwt/logout` + limpiar storage + navigate login

---

## 📱 Pantallas Principales

### Flujo de Estudiante
1. **Splash** → Verificación de login
2. **Welcome/Login** → Autenticación
3. **Register Student** → Registro con perfil
4. **Student Home (Feed de Swipes)**
   - Tarjetas de vacantes
   - Like/Dislike
   - Matches en tiempo real
5. **Matches/Activity** → Ver matches
6. **Applications** → Postulaciones activas
7. **AI Feedback** → Retroalimentación con IA
8. **Profile** → Editar perfil
9. **Premium** → Compra de suscripción

### Flujo de Empresa
1. **Splash** → Verificación de login
2. **Welcome/Login** → Autenticación
3. **Register Company** → Registro con perfil
4. **Company Home**
   - Dashboard de vacantes
   - Estadísticas
5. **Vacancies** → CRUD de vacantes
6. **Candidates** → Feed y gestión de candidatos
7. **Applications** → Postulaciones recibidas
8. **Profile** → Editar perfil
9. **Premium** → Suscripción

---

## ⚙️ Convenciones de Código

- **Nombres de clases:** PascalCase (`AuthProvider`, `UserModel`)
- **Nombres de variables:** camelCase (`userName`, `isLoading`)
- **Nombres de constantes:** camelCase o UPPER_SNAKE_CASE (`apiUrl`, `API_KEY`)
- **Prefijos de widgets privados:** `_` (`_buildAppBar()`)
- **Archivos:** snake_case (`auth_provider.dart`, `user_model.dart`)

---

## 🛠️ Requisitos para Desarrollo

- Flutter 3.0+
- Dart 3.0+
- Android SDK (para Android)
- Xcode (para iOS)
- Git

**Instalación:**
```bash
flutter pub get
flutter run -d <device_id>
```

---

## 📞 Endpoints de Soporte

- **Health Check** → `GET /health`
- **API Base** → `https://api.jobmatch.com/api/v1`

---

## 🚦 Estados y Flujos

### Estados de Postulación
- `pendiente` → Empresa no ha revisado
- `entrevista` → Avanzó a entrevista
- `aceptada` → Empresa hizo oferta
- `rechazada` → Rechazada con feedback

### Estados de Vacante
- `activa` → Publicada
- `pausada` → Temporalmente pausada
- `cerrada` → Puesto cubierto
- `archivada` → Histórico

### Estados de Match
- `pendiente_empresa` → Esperando like de empresa
- `pendiente_estudiante` → Esperando like de estudiante
- `activo` → Ambos dieron like
- `chat_activo` → Conversación en curso

---

## 📊 Resumen de Endpoints

**Total: ~60 endpoints**

| Categoría | Cantidad |
|-----------|----------|
| Auth | 3 |
| User | 6 |
| Roles | 4 |
| Media (Foto/CV) | 9 |
| Perfil (Estudiante/Empresa) | 8 |
| Vacantes | 7 |
| Swipes | 4 |
| Matches | 1 |
| Postulaciones | 3 |
| Retroalimentación | 5 |
| Pagos (PayPal) | 6 |
| Suscripciones | 7 |

---

**Última actualización:** abril 2026  
**Versión del documento:** 1.0
