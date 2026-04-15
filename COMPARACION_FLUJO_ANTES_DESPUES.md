# 📊 COMPARACIÓN - Flujo Incorrecto vs Correcto

## ❌ FLUJO INCORRECTO (Lo que documenté antes)

```
CLIENTE (Flutter)                    SERVIDOR (Backend)
┌──────────────────────┐            ┌──────────────────┐
│ ApplicationsScreen    │            │ /postulaciones   │
│                      │            │   /{id}/estado   │
│ 1. Presiona botón    │            │                  │
│ 2. GET /retro...     │◄───────────│ 200 OK           │
│ 3. SI no hay dato    │            │ (solo cambio     │
│ 4. Genera IA LOCAL:  │            │  estado)         │
│    - Importa http    │            │                  │
│    - Importa Claude  │            │                  │
│    - Carga API KEY   │            │                  │
│    - Llama /v1/msgs  │────────────►ANTHROPIC API    │
│ 5. Muestra resultado │            │ (tercero)        │
└──────────────────────┘            └──────────────────┘

PROBLEMAS:
❌ API KEY expuesta en cliente
❌ Flutter cargando dependencias grandes (http, json decode)
❌ Flujo complejo en cliente
❌ Tasa de error alta (conexión, timeout, API key inválida)
❌ No escala (múltiples llamadas simultáneas)
```

---

## ✅ FLUJO CORRECTO (Según OpenAPI)

```
EMPRESA (Empresa Mobile)             SERVIDOR (Backend)
┌────────────────┐                  ┌─────────────────────┐
│ Rechaza        │                  │ PUT /postulaciones  │
│ candidato      │                  │    /{id}/estado     │
│                │                  │                     │
│ 1. Muestra     │                  │ Recibe:             │
│    formulario  │                  │ - nuevo_estado      │
│                │                  │ - feedback          │
│ 2. Ingresa:    │                  │   ├─ campos_mejora  │
│    - Qué falta │─────────────────►│   └─ sugerencias    │
│    - Suger.    │                  │                     │
│                │    200 OK        │ 1. Cambia estado    │
│ 3. Presiona    │◄─────────────────│ 2. Crea retro...    │
│    "Rechazar"  │                  │ 3. LLAMA CLAUDE:    │
│                │                  │    - Lee CV         │
└────────────────┘                  │    - Lee feedback   │
                                     │    - Genera roadmap │
                                     │ 4. Guarda resultado │
CLIENTE (Flutter - Estudiante)       │                     │
┌──────────────────────┐            └─────────────────────┘
│ ApplicationsScreen    │            
│                      │ ┌─ Periódicamente
│ 1. Abre historial    │ │ (sin hacer nada)
│ 2. Ve vacante        │ │
│    rechazada         │ │
│ 3. Presiona "Ver     │ │
│    plan de acción"   │ │
│                      │ │
│ 4. GET /retro... ────┼─►SERVIDOR
│    postulacion/{id}  │
│                      │ ◄─ Devuelve:
│ 5. SI pendiente:     │    {
│    - Polling 15s     │     \"roadmap_estado\": \"generado\",
│    - Espera resultado│     \"roadmap\": { ... }
│                      │    }
│ 6. Muestra roadmap ◄─┘
│                      │
└──────────────────────┘

BENEFICIOS:
✅ SIN API KEY en cliente
✅ Fácil implementación en cliente
✅ IA ejecutado una sola vez en backend
✅ Resultado cacheado
✅ Escalable
✅ Seguro
```

---

## 📌 Por Qué Cambió

**Cuando viste el OpenAPI:**

```
PUT /postulaciones/{postulacion_id}/estado
├─ Input: nuevo_estado + feedback
├─ Descripción: "Cambia el estado y AGREGA FEEDBACK si es rechazo"
│              ↑↑↑ Esto significa que el backend
│                  recibe feedback de la empresa
│
└─ Path: /retroalimentacion/postulacion/{id}/generar-roadmap
         ↑↑↑ El backend tiene endpoint para generar
             (probablemente con IA internamente)
```

**Conclusión:** 
El backend YA implementa la lógica de IA. El cliente solo necesita consultar.

---

## 🔄 Línea del Tiempo

### Fase 1: Mi Implementación Inicial (INCORRECTO)
```
Día 1: Creas ApplicationsScreen con IA local
      ├─ SETUP_ANTHROPIC_API_KEY.md ← usable pero INCORRECTO
      ├─ INTEGRATION_GUIDE... .md ← parcialmente correcto
      └─ Lógica: Cliente genera IA
```

### Fase 2: Aclaración (CORRECTO)
```
Hoy: Aclaras el flujo real
     ├─ Backend genera IA
     ├─ Cliente solo consulta
     ├─ CORRECCION_FLUJO...md ← el nuevo entendimiento
     └─ Arquitectura simplificada
```

---

## 🛠️ Cambio de Código

### Antes
```dart
class _RetroSheetState extends State<_RetroSheet> {
  final _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  
  Future<void> _generarFeedbackIA() async {
    // LÍNEAS DE CÓDIGO: ~50
    final prompt = "Analiza CV...";
    final text = await _callClaude(prompt);
    setState(() { _feedbackIA = text; });
  }
  
  @override
  Widget build(BuildContext context) {
    return _cargando ? _buildLoading() : _buildIAContent();
  }
}
```

### Después
```dart
class _RetroSheetState extends State<_RetroSheet> {
  Future<void> _cargar() async {
    // LÍNEAS DE CÓDIGO: ~15
    final retro = await _retroRepo.getRetroalimentacion(
      widget.postulacionId!
    );
    setState(() { _retro = retro; });
  }
  
  @override
  Widget build(BuildContext context) {
    return _cargando ? _buildLoading() : _buildBackendContent(_retro!);
  }
}
```

**Reducción: 50 → 15 líneas** ✨

---

## ✅ Action Items

### Ignorar (Ya NO válidos)
- [ ] flutter pub add flutter_dotenv
- [ ] Crear .env con ANTHROPIC_API_KEY
- [ ] Configurar dotenv.load() en main.dart
- [ ] Cualquier cosa con String.fromEnvironment('ANTHROPIC_API_KEY')

### Implementar (SÍ válido)
- [ ] Limpiar ApplicationsScreen
- [ ] Mantener RetroalimentacionRepository.getRetroalimentacion()
- [ ] Simplificar _RetroSheetState.build()
- [ ] Quitar imports innecesarios (http, dart:convert)
- [ ] Verificar que backend genera IA

---

## 🎯 Una Oración

> El cliente no genera inteligencia artificial. Solo pregunta al backend "¿Ya generaste mi retroalimentación?" y muestra lo que responde.

---

**Verde ✅:** Flujo correcto implementado en backend  
**Naranja ⚠️:** Requiere coordinación backend-frontend  
**Rojo ❌:** No hacer (no lo necesita)

Todos los nuevos docs (`CORRECCION_**`, `FLUJO_**`) explican la versión verde ✅.
