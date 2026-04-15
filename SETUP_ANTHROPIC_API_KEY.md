# 🔑 Configuración ANTHROPIC_API_KEY - Guía Paso a Paso

## Problema
El archivo `applications_screen.dart` necesita `ANTHROPIC_API_KEY` para generar retroalimentación con Claude AI cuando no hay datos del backend.

```dart
static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
```

Si no está configurada, verás el error:
```
Exception: ANTHROPIC_API_KEY no configurada.
```

---

## ✅ Solución Recomendada: flutter_dotenv

Esta es la opción más fácil y segura para desarrollo.

### Paso 1: Instalar flutter_dotenv

```bash
# En la raíz del proyecto
flutter pub add flutter_dotenv
```

O manualmente en `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_dotenv: ^5.1.0
```

```bash
flutter pub get
```

### Paso 2: Crear archivo .env

Crea un archivo `.env` en la **raíz del proyecto** (al lado de `pubspec.yaml`):

```env
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
```

⚠️ **IMPORTANTE:**
- No incluyas `sk-ant-xxxxxxxxxxxxx` literalmente
- Reemplázalo con tu API key real
- **NUNCA** commits el `.env` a git (agregar a `.gitignore`)

### Paso 3: Agregar .env a .gitignore

```bash
# En .gitignore, agregar:
.env
.env.local
.env.*.local
```

O si tu `.gitignore` no existe:
```bash
echo ".env" >> .gitignore
```

### Paso 4: Actualizar main.dart

En tu función `main()`, cargar el archivo `.env` **antes** de `runApp()`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ CLAVE: Cargar .env
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}
```

### Paso 5: Actualizar applications_screen.dart

Cambiar la línea de la API key:

**De:**
```dart
class _RetroSheetState extends State<_RetroSheet> {
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  ...
}
```

**A:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class _RetroSheetState extends State<_RetroSheet> {
  final _apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
  ...
}
```

### Paso 6: Validar que funciona

```bash
flutter pub get
flutter run
```

Cuando presiones el botón de retroalimentación:
- ✅ Si ve `_buildBackendContent()` → felicidades
- ✅ Si fallback a IA y genera texto → ¡funciona!
- ❌ Si error "ANTHROPIC_API_KEY no configurada" → `dotenv.load()` no se ejecutó

---

## 🔐 Obtener API Key de Anthropic

### Opción 1: [console.anthropic.com](https://console.anthropic.com) (Recomendado)

1. Ir a https://console.anthropic.com/
2. Sign up o Log in
3. Navegar a **API Keys** en el menú lateral
4. Click en **"Create Key"**
5. Dale un nombre: `movil-app`
6. Copiar la key (empieza con `sk-ant-`)
7. **Guárdala en `.env`**

### Opción 2: Usar API key temporal para testing

Si solo quieres probar rápidamente:

```env
ANTHROPIC_API_KEY=sk-ant-test0000000000000000000000000000000000000000000000000000000
```

⚠️ **Esto NO funcionará**, pero te permite compilar y probar la UI sin errores.

---

## 🛠️ Troubleshooting

### Error: "Cannot load environment from .env"
**Solución:** Verificar que `.env` está en la raíz (al lado de `pubspec.yaml`)

```bash
# Verificar estructura
ls -la .env
ls -la pubspec.yaml
# Deben estar en el mismo nivel
```

### Error: "ANTHROPIC_API_KEY is empty"
**Solución:** Verificar contenido de `.env`

```bash
cat .env
# Debe mostrar:
# ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
```

### Error: "401 Unauthorized" en la IA
**Solución:** API key incorrecta o expirada

1. Ir a https://console.anthropic.com/api_keys
2. Generar nueva key
3. Actualizar `.env`
4. Relanzar la app

### El archivo .env se sube a git por accidente
```bash
# Eliminar del historio (si ya está commiteado)
git rm --cached .env
git commit -m "Remove .env from tracking"

# Agregar a .gitignore (si no está)
echo ".env" >> .gitignore
git add .gitignore
git commit -m "Add .env to .gitignore"

# Verificar
git status
# No debe mostrar .env
```

---

## 📋 Versiones Soportadas

| Paquete | Versión | Estado |
|---------|---------|--------|
| flutter_dotenv | ^5.1.0 | ✅ Recomendada |
| Dart | 3.0+ | ✅ Recomendada |
| Flutter | 3.0+ | ✅ Recomendada |

---

## 🔄 Alternativa: Build Flag (para CI/CD)

Si usas GitHub Actions, Jenkins, o similar:

```bash
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
```

O en `.github/workflows/build.yml`:
```yaml
- name: Build APK
  run: |
    flutter build apk --release \
      --dart-define=ANTHROPIC_API_KEY=${{ secrets.ANTHROPIC_API_KEY }}
```

⚠️ **No recomendado para desarrollo local** porque:
- Largo de escribir cada vez
- Fácil de olvidar
- No funciona bien con hot reload

---

## 🎯 Verificación Final

Checklist antes de commit:

- [ ] Archivo `.env` existe en raíz del proyecto
- [ ] `.env` está en `.gitignore`
- [ ] `flutter_dotenv` está en `pubspec.yaml`
- [ ] `main.dart` tiene `await dotenv.load()`
- [ ] `applications_screen.dart` usa `dotenv.env['ANTHROPIC_API_KEY']`
- [ ] `flutter pub get` sin errores
- [ ] `flutter run` sin errores
- [ ] ¡Prueba el botón de retroalimentación!

---

## 📞 Soporte

Si tienes problemas:

1. **Verificar logs:**
   ```bash
   flutter run -v
   # Buscar: "ANTHROPIC_API_KEY"
   ```

2. **Revisar que la key es válida:**
   - Empieza con `sk-ant-`
   - Tiene ~100 caracteres
   - Sin espacios extra

3. **Revisar Anthropic Console:**
   - Confirmar que la key está activa
   - Verificar cuota de tokens disponible
   - Revisar límites de tasa (rate limits)

4. **Revisar logs de la app:**
   - Buscar `[RetroSheet]` o `[RetroRepo]`
   - Ver si hay errores de Anthropic API

---

## 💡 Tips

**Para desarrollo seguro:**
- Mantener `.env` en `.gitignore`
- Usar `.env.example` para documentar vars necesarias
- Rotar keys periódicamente
- Usar variables de ambiente en CI/CD

**Para testing:**
```dart
// En tests, usar fixture:
setUp(() async {
  dotenv.testLoad(fileInput: 'ANTHROPIC_API_KEY=sk-ant-test-key');
});
```

---

**¡Listo! Con esto tu app debería funcionar con retroalimentación de IA. 🎉**
