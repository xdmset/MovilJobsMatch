# 🔍 Debugging Premium - Guía de Verificación

## Estado Actual ✅

Ha sido configurado un flujo mejorado para detectar Premium automáticamente después de PowerPal:

1. **Flujo PayPal → App**:
   - ✅ Deep linking configurado (Android + iOS)
   - ✅ URLs cambiadas a `jobmatch://paypal-success` y `jobmatch://paypal-cancel`
   - ✅ App automáticamente sincroniza cuando se resume

2. **Botón Cancelar Suscripción**:
   - ✅ Visible cuando `esPremium == true`
   - ✅ En StudentPremiumScreen (línea 240-246)
   - ✅ En CompanyPremiumScreen (línea igual)

3. **Sincronización de Premium Flag**:
   ```
   _sync() → sincronizar(id) → refrescarUsuario() → StudentProvider.setPremium()
   ```

---

## 🐛 Si Premium No Se Detecta

### Paso 1: Verificar Backend Response

Cuando PayPal aprueba y app sincroniza, el backend debe devolver:

```json
{
  "id": 123,
  "email": "usuario@example.com",
  "es_premium": true,  ← CRÍTICO: Debe ser `true`
  "rol": "estudiante",
  "rol_id": 2
}
```

**Qué revisar en la terminal:**
- Buscar logs: `[AuthProvider] usuario refrescado — esPremium: true`
- Si dice `false`, el backend NO está actualizando `es_premium`

### Paso 2: Verificar Timing

En la terminal, buscar:
```
[PayPal] App resumed con pendingId: <id>
[PayPal] Creando suscripción
[PayPal] Respuesta: {approve_url: ...}
[PayPal] POST /payments/paypal/subscriptions/{id}/sync
[AuthProvider] usuario refrescado — esPremium: true
```

Si el último log dice `false`, contactar al backend.

### Paso 3: Verificar SharedPreferences

El pendingId se guarda en SharedPrefs con key: `pending_paypal_sub_id_estudiante`

Verificar en logs:
```
[PayPal] pending_paypal_sub_id_estudiante = <subId>
```

### Paso 4: Force Sync Manual

En StudentPremiumScreen hay un botón "Ver icador" (cuando `_pendingId != null && !esPremium`).
Presionar para forzar sincronización manual.

---

## 🔧 Cambios Realizados en Esta Sesión

### 1. Deep Linking (Android)
**Archivo**: `android/app/src/main/AndroidManifest.xml`
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="jobmatch" android:host="paypal-success"/>
    <data android:scheme="jobmatch" android:host="paypal-cancel"/>
</intent-filter>
```

### 2. Deep Linking (iOS)
**Archivo**: `ios/Runner/Info.plist` (Debe agregarse)
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>jobmatch</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>jobmatch</string>
        </array>
    </dict>
</array>
```

### 3. URLs PayPal Actualizadas

**StudentPremiumScreen**:
```dart
static const _returnUrl = 'jobmatch://paypal-success';
static const _cancelUrl = 'jobmatch://paypal-cancel';
```

**CompanyPremiumScreen**: ✅ Igual

### 4. GoRouter Deep Link Handlers

**routes.dart**: Agregadas rutas para manejar los deep links:
```dart
GoRoute(
  path: 'jobmatch://paypal-success',
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    return auth.esEstudiante ? AppRoutes.studentPremium : AppRoutes.companyPremium;
  },
),
```

### 5. Settings Redirection

**routes.dart**: Settings ahora redirige según rol:
```dart
GoRoute(
  path: AppRoutes.settings,
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    return auth.esEstudiante ? AppRoutes.studentSettings : AppRoutes.companySettings;
  },
),
```

---

## ✅ Verificación Completa

**Hacer esto para asegurar que todo funciona:**

1. **Premium No Actual**: Acceder a StudentPremiumScreen → No debe ver botón "Cancelar"
2. **Simular Pago**:
   - Hacer screenshot del approveUrl
   - Pegar en navegador PC
   - Completar flujo PayPal
3. **Esperar App Resume**: 
   - Cuando browser cierre o redirija, app debe resumir
   - Debe sincronizar automáticamente
4. **Verificar Cambio**: 
   - Debe aparecer botón "Cancelar Subscripción"
   - Debe mostrar "✓ Bienvenido a Premium"
5. **Verificar Logs**:
   - Terminal debe mostrar `esPremium: true`

---

## 📋 Archivos Comunes Ahora Innecesarios

```
❌ lib/presentation/screens/common/settings_screen.dart
   → La ruta ahora redirige automáticamente
   
❌ lib/presentation/screens/common/premium_screen.dart
   → Comentado/no usado (cada rol tiene su archivo)
```

---

## 🚀 Si Aún No Funciona

**Contactar al backend con:**

1. El usuario sincronizó PayPal exitosamente
2. El endpoint `/payments/paypal/subscriptions/{id}/sync` respondió OK
3. Pero el endpoint `GET /usuarios/{id}` aún devuelve `"es_premium": false`

**Posible causa backend:**
- `es_premium` flag no se está actualizando en BD
- El webhook de PayPal no está procesando correctamente
- Desincronización entre tabla usuarios y tabla suscripciones
