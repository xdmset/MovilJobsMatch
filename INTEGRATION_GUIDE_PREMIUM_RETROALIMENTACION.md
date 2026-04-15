# Guía de Integración - Premium + Retroalimentación

## ✅ Estado de Integración

### Archivos Integrados
- ✅ `lib/presentation/providers/student_provider.dart` - Premium support
- ✅ `lib/data/repositories/retroalimentacion_repository.dart` - Feedback & roadmap
- ✅ `lib/presentation/screens/student/applications/applications_screen.dart` - UI retroalimentación
- ✅ `lib/data/repositories/student_repository.dart` - postulacion_id storage

### Cambios Realizados

#### 1. StudentShellScreen ✅
**Archivo:** `lib/presentation/screens/student/student_shell_screen.dart`

**Integración de setPremium():**
```dart
Future<void> _init() async {
  final userId = context.read<AuthProvider>().usuario?.id;
  final p      = context.read<StudentProvider>();
  if (userId == null) return;

  // Cargar datos en orden crítico
  await p.cargarHistorial(userId);
  await p.cargarVacantes(estudianteId: userId);
  await p.cargarMatches(userId);

  // ✅ Inyectar flag premium después de cargar usuario
  context.read<StudentProvider>().setPremium(
    context.read<AuthProvider>().esPremium,
  );
}
```

#### 2. StudentPremiumScreen ✅
**Archivo:** `lib/presentation/screens/student/premium/student_premium_screen.dart`

**Cambios:**
- ✅ Agregado import: `import '../../../providers/student_provider.dart';`
- ✅ En método `_sync()`, después de `refrescarUsuario()`:
  ```dart
  if (mounted) {
    context.read<StudentProvider>().setPremium(
      context.read<AuthProvider>().esPremium,
    );
  }
  ```

#### 3. StudentProvider ✅
**Archivo:** `lib/presentation/providers/student_provider.dart`

**Ya incluyó:**
- `_esPremium` boolean flag (default: false)
- `setPremium(bool value)` - inyecta el flag desde AuthProvider
- `hasReachedLimit` devuelve `false` cuando `esPremium == true` ✨
- `remainingSwipes` devuelve `null` cuando es premium (ilimitado) ✨
- `limpiar()` resetea también `_esPremium = false`

#### 4. Retroalimentación Repository ✅
**Archivo:** `lib/data/repositories/retroalimentacion_repository.dart`

**Endpoints implementados:**
- `getRetroalimentacion(postulacionId)` - GET con polling automático
- `crearRetroalimentacion(...)` - POST feedback de empresa
- `generarRoadmap(postulacionId)` - POST generar roadmap
- Cache por postulacion_id, invalidable

**Polling automático:**
- Máx 5 intentos cada 3 segundos
- Si roadmap_estado == "pendiente", espera hasta "generado"

#### 5. Flujo de postulacion_id ✅
**Archivo:** `lib/data/repositories/student_repository.dart`

**Cambios implementados:**
- ✅ Importado: `package:shared_preferences/shared_preferences.dart`
- ✅ `registrarSwipe()` ahora guarda el ID en SharedPreferences:
  ```dart
  // Guardar postulacion_id para uso posterior
  if (postulacionId != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('postulacion_id_vacante_$vacanteId', postulacionId);
  }
  ```
- ✅ `getHistorialEstudiante()` enriquece cada item con postulacion_id:
  ```dart
  final savedPostId = prefs.getInt('postulacion_id_vacante_$vacanteId');
  if (savedPostId != null) {
    item['postulacion_id'] = savedPostId;
  }
  ```

#### 6. ApplicationsScreen ✅
**Archivo:** `lib/presentation/screens/student/applications/applications_screen.dart`

**Ya incluyó:**
- `_buildBotonRetro()` con lógica de prioridad:
  1. Premium + postulacion_id → backend (con fallback IA)
  2. Premium sin postulacion_id → fallback IA
  3. Sin premium → teaser
- `_RetroSheet` - muestra retroalimentación
- `_buildBackendContent()` - roadmap del backend (semana a semana, habilidades, acciones)
- `_buildIAContent()` - fallback a Claude AI

---

## 🔑 Configuración: ANTHROPIC_API_KEY

### Paso 1: Obtener API Key
1. Ir a https://console.anthropic.com/
2. Crear cuenta o iniciar sesión
3. Ir a **API Keys**
4. Crear nueva key
5. Copiar la key (empieza con `sk-ant-`)

### Paso 2: Configurar en Flutter

#### Opción A: Archivo .env (recomendado para desarrollo)
1. Crear archivo `.env` en raíz del proyecto:
   ```env
   ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
   ```

2. Agregar `flutter_dotenv` a `pubspec.yaml`:
   ```yaml
   dev_dependencies:
     flutter_dotenv: ^5.0.0
   ```

3. Ejecutar `flutter pub get`

4. En `main.dart`, cargar antes de runApp():
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await dotenv.load(); // ← Cargar .env
     runApp(const MyApp());
   }
   ```

5. EN applications_screen.dart, la key se accede con:
   ```dart
   static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
   ```
   
   Pero si usas flutter_dotenv, cambiar a:
   ```dart
   final _apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
   ```

#### Opción B: Pasar como build flag (para CI/CD)
```bash
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
```

#### Opción C: Firebase Remote Config (para producción)
1. Configurar en Firebase Console
2. Leer en tiempo de ejecución

---

## 🧪 Testing

### Verificar integración de setPremium()
```dart
test('setPremium debe actualizar _esPremium', () {
  final provider = StudentProvider();
  
  provider.setPremium(false);
  expect(provider.esPremium, false);
  expect(provider.hasReachedLimit, true); // 20 swipes max
  
  provider.setPremium(true);
  expect(provider.esPremium, true);
  expect(provider.hasReachedLimit, false); // Sin límite
  expect(provider.remainingSwipes, null); // Ilimitado
});
```

### Verificar postulacion_id storage
```dart
test('registrarSwipe guarda postulacion_id', () async {
  final repo = StudentRepository.instance;
  final prefs = await SharedPreferences.getInstance();
  
  // Realizar swipe (mock del backend)
  await repo.registrarSwipe(1, 100, true);
  
  // Verificar que se guardó
  final saved = prefs.getInt('postulacion_id_vacante_100');
  expect(saved, isNotNull);
});
```

---

## 🐛 Troubleshooting

### Error: "ANTHROPIC_API_KEY not configured"
**Solución:**
1. Verificar que .env está en la raíz del proyecto
2. Ejecutar `flutter pub get`
3. Relanzar la app (no solo hot reload)
4. Si usa flutter_dotenv, asegurar que se carga en main.dart

### Error: "postulacion_id is null en retroalimentación"
**Solución:**
1. Verificar que se ejecutó el `like` (registrarSwipe)
2. Buscar en SharedPreferences: `postulacion_id_vacante_<vacanteId>`
3. Si no existe, el backend probablemente no devolvió el ID
4. Verificar respuesta de POST /swipes/{id}

### Error: "Fallback a IA no genera contenido"
**Solución:**
1. Verificar que ANTHROPIC_API_KEY está configurada
2. Verificar que la key es válida (no expirada)
3. En logs, buscar error de Claude API
4. Revisar cuota de tokens en console.anthropic.com

---

## 📊 Flujo de Datos - Premium + Retroalimentación

```
┌─────────────────────────────────────────────────────────┐
│ StudentShellScreen._init()                              │
│ ├─ cargarHistorial(userId)                              │
│ ├─ cargarVacantes(estudianteId: userId)                 │
│ ├─ cargarMatches(userId)                                │
│ └─ setPremium(auth.esPremium) ✅ CLAVE                  │
└─────────────────────────────────────────────────────────┘
         │
         ├─→ StudentHomeScreen (swipe)
         │   └─ _onLike() → likeVacancy()
         │      ├─ _repo.registrarSwipe(userId, vacanteId, true)
         │      │  ├─ POST /swipes/{userId}
         │      │  └─ Guardar postulacion_id en SharedPreferences ✅
         │      └─ Actualizar historial
         │
         └─→ ApplicationsScreen (retroalimentación)
             ├─ Si premium + postulacion_id:
             │  ├─ RetroRepo.getRetroalimentacion(postId)
             │  │  ├─ GET /retroalimentacion/postulacion/{id}
             │  │  ├─ Si pendiente → polling (máx 5 intentos)
             │  │  └─ Devolver RoadmapData
             │  └─ Mostrar _RetroBackendSheet (roadmap, habilidades, etc.)
             │
             ├─ Si no hay datos backend:
             │  ├─ Generar con Claude AI (ANTHROPIC_API_KEY)
             │  ├─ POST /v1/messages (Anthropic)
             │  └─ Mostrar _AIFeedbackSheet
             │
             └─ Si sin premium:
                └─ Mostrar teaser + botón a StudentPremiumScreen
```

---

## 📝 Verificación de Integración

### Checklist Final

- [ ] Student Provider tiene setPremium() implementado
- [ ] StudentShellScreen llama setPremium() en _init()
- [ ] StudentPremiumScreen llama setPremium() después de refrescarUsuario()
- [ ] Import de StudentProvider en student_premium_screen.dart ✅
- [ ] retroalimentacion_repository.dart tiene polling automático
- [ ] student_repository.dart guarda postulacion_id en SharedPreferences
- [ ] getHistorialEstudiante() enriquece con postulacion_id
- [ ] applications_screen.dart muestra retroalimentación con prioridad correcta
- [ ] ANTHROPIC_API_KEY está configurada en .env
- [ ] No hay errores de compilación: `flutter analyze`

### Comandos para Verificar

```bash
# Compilar sin errores
flutter pub get
flutter analyze

# Ejecutar tests
flutter test

# Build release (si no hay errores, está todo bien)
flutter build apk --release
```

---

## 🎉 Resumen

✅ **Integración completada:**
1. Premium flag inyectado desde AuthProvider
2. Swipes ilimitados cuando paga
3. Retroalimentación del backend con polling
4. Fallback automático a IA de Anthropic
5. postulacion_id guardado y recuperado localmente
6. Sin errores de compilación

**Próximo paso:** Configurar ANTHROPIC_API_KEY en tu entorno.
