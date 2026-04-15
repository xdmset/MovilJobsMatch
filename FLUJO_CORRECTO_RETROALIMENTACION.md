# 🔄 Flujo Correcto de Retroalimentación - Según OpenAPI

## ✅ Flujo Real (Backend → IA → Estudiante)

```
┌─ EMPRESA
│  ├─ 1. Ve postulación en "Candidatos"
│  ├─ 2. Presiona "Rechazar" (PUT /postulaciones/{id}/estado)
│  │     ├─ UI abre formulario
│  │     ├─ Ingresa qué le falta mejorar (campos_mejora)
│  │     └─ Ingresa sugerencias (sugerencias_perfil)
│  │
│  └─ 3. Envía:
│     ```json
│     {
│       "nuevo_estado": "rechazado",
│       "feedback": {
│         "campos_mejora": "Necesitas mejorar en comunicación...",
│         "sugerencias_perfil": "Te recomendamos tomar cursos de..."
│       }
│     }
│     ```
│
└─ BACKEND (llama IA internamente)
   ├─ 1. Recibe PUT /postulaciones/{postulacion_id}/estado
   ├─ 2. Cambia estado a "rechazado"
   ├─ 3. Crea retroalimentación: POST /retroalimentacion/
   │     ```json
   │     {
   │       "postulacion_id": 123,
   │       "campos_mejora": "...",
   │       "sugerencias_perfil": "..."
   │     }
   │     ```
   │
   ├─ 4. Llama IA INTERNAMENTE para generar roadmap
   │     ├─ Lee CV del estudiante (GET /media/estudiantes/{id}/cv)
   │     ├─ Lee feedback de empresa (campos_mejora, sugerencias_perfil)
   │     ├─ Llama Claude: "Analiza CV + feedback → genera roadmap"
   │     └─ Actualiza retroalimentacion con roadmap
   │
   └─ 5. Devuelve respuesta con retroalimentación creada
      ```json
      {
        "id": 456,
        "postulacion_id": 123,
        "campos_mejora": "...",
        "sugerencias_perfil": "...",
        "roadmap_estado": "generado",
        "roadmap": { ... }
      }
      ```

└─ ESTUDIANTE
   ├─ 1. Abre "Mis Postulaciones" → tab "Cerradas"
   ├─ 2. Ve vacante rechazada
   ├─ 3. Presiona "Ver plan de acción"
   ├─ 4. App: GET /retroalimentacion/postulacion/{postulation_id}
   └─ 5. Muestra roadmap generado por IA
```

---

## 📋 Endpoints Relevantes del OpenAPI

### 1️⃣ Rechazar Postulación (Empresa)
```
PUT /api/v1/postulaciones/{postulacion_id}/estado
```

**Body:**
```json
{
  "nuevo_estado": "rechazado",
  "feedback": {
    "campos_mejora": "Falta experiencia en React",
    "sugerencias_perfil": "Te recomendamos mejorar en..."
  }
}
```

**Response:**
```json
{}  // Solo 200 OK
```

**Nota:** El backend DEBE:
- Crear la retroalimentación automáticamente
- Llamar IA internamente para generar roadmap
- Enriquecer la retroalimentación con roadmap

### 2️⃣ Generar Roadmap (Backup Manual)
```
POST /api/v1/retroalimentacion/postulacion/{postulacion_id}/generar-roadmap
```

**Parámetros:** Ninguno (el backend tiene todo: CV, feedback, etc.)

**Response:**
```json
{
  "id": 456,
  "postulacion_id": 123,
  "roadmap_estado": "generado",
  "roadmap": {
    "habilidades": ["React", "TypeScript"],
    "acciones": ["Completa curso X"],
    "recursos": ["Link a curso"],
    "tiempo_estimado": "4 semanas",
    "prioridad": "alta",
    "roadmap_detallado": [
      {
        "semana": "Semana 1",
        "objetivo": "Aprender React basics",
        "tareas": ["Curso A", "Proyecto 1"]
      }
    ]
  }
}
```

### 3️⃣ Obtener Retroalimentación (Estudiante)
```
GET /api/v1/retroalimentacion/postulacion/{postulacion_id}
```

**Response:**
```json
{
  "id": 456,
  "postulacion_id": 123,
  "campos_mejora": "Necesitas mejorar en...",
  "sugerencias_perfil": "Te recomendamos...",
  "fecha_envio": "2026-04-14T10:30:00",
  "roadmap_estado": "generado",
  "roadmap": { ... },
  "roadmap_generado_en": "2026-04-14T10:30:15"
}
```

---

## 🎯 Qué Debe Hacer el BACKEND

### En PUT /postulaciones/{postulacion_id}/estado:

```python
# Pseudocódigo
def actualizar_estado(postulacion_id, nuevo_estado, feedback=None):
    postulacion = get_postulacion(postulacion_id)
    postulacion.estado = nuevo_estado
    
    if nuevo_estado == "rechazado" and feedback:
        # 1. Crear retroalimentación
        retro = create_retroalimentacion(
            postulacion_id=postulacion_id,
            campos_mejora=feedback.campos_mejora,
            sugerencias_perfil=feedback.sugerencias_perfil
        )
        
        # 2. Generar roadmap CON IA
        roadmap = generate_roadmap_with_ai(
            postulacion_id=postulacion_id,
            cv_estudiante=get_cv(postulacion.estudiante_id),
            feedback=feedback
        )
        
        # 3. Actualizar retroalimentación con roadmap
        retro.roadmap = roadmap
        retro.roadmap_estado = "generado"
        retro.save()
    
    postulacion.save()
    return 200
```

### En generate_roadmap_with_ai():

```python
def generate_roadmap_with_ai(postulacion_id, cv_estudiante, feedback):
    prompt = f"""
    Analiza el CV del estudiante y el feedback de la empresa.
    Genera un plan de acción concreto con:
    - Habilidades a desarrollar
    - Acciones recomendadas
    - Recursos útiles
    - Roadmap semana a semana
    
    CV: {cv_contenido}
    
    Feedback de empresa:
    - Áreas de mejora: {feedback.campos_mejora}
    - Sugerencias: {feedback.sugerencias_perfil}
    
    Devuelve JSON con estructura RoadmapData
    """
    
    # Llamar Claude
    response = claude.message(prompt)
    roadmap = parse_response(response)
    return roadmap
```

---

## 🛠️ Cambios Necesarios en el Cliente (Flutter)

### Cambio 1: Quitar generación IA del cliente

**De:** El cliente generaba IA con `_callClaude()`  
**A:** El cliente solo **consulta** retroalimentación del backend

### Cambio 2: Simplificar ApplicationsScreen

No necesita:
- ❌ `static const _apiKey = String.fromEnvironment(...)`
- ❌ `_callClaude()` method
- ❌ Fallback a IA local

Necesita:
- ✅ `RetroalimentacionRepository.getRetroalimentacion()`
- ✅ Mostrar resultado del backend
- ✅ Mostrar estado "generando..." si roadmap_estado == "pendiente"

### Cambio 3: Flow simplificado

```dart
// Antes (INCORRECTO):
_RetroSheetState._cargar():
  ├─ Intentar backend
  ├─ Si no hay → Fallback a Claude local
  └─ Mostrar resultado

// Ahora (CORRECTO):
_RetroSheetState._cargar():
  ├─ GET /retroalimentacion/postulacion/{id}
  │  ├─ Si pendiente → polling (esperar 15s max)
  │  └─ Si generado → mostrar roadmap
  │
  └─ Si error → mostrar mensaje error
```

---

## ⚠️ Implicaciones para ApplicationsScreen

### YA NO SE NECESITA:
```dart
// ❌ ELIMINAR
import 'package:http/http.dart' as http;
import 'dart:convert';

static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

Future<String> _callClaude(String prompt) async { ... }
Future<void> _generarFeedbackIA() async { ... }
```

### SE MANTIENE:
```dart
// ✅ MANTENER
final _retroRepo = RetroalimentacionRepository.instance;

Future<void> _cargar() async {
  setState(() { _cargando = true; });
  
  if (widget.postulacionId != null) {
    try {
      final retro = await _retroRepo.getRetroalimentacion(
        widget.postulacionId!
      );
      if (retro != null && retro.tieneContenido) {
        setState(() { 
          _retro = retro;
          _cargando = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[RetroSheet] error: $e');
    }
  }
  
  // Si no hay retroalimentación → error
  if (mounted) {
    setState(() {
      _errorIA = 'No hay retroalimentación disponible';
      _cargando = false;
    });
  }
}
```

---

## 🔑 Diferencia Clave

| Aspecto | ❌ ANTES (Incorrecto) | ✅ AHORA (Correcto) |
|--------|----------------------|-------------------|
| **Quién genera IA** | Cliente (Flutter) | Backend (Python) |
| **API Key** | En cliente | En backend (secreto) |
| **CV necesario** | Sí (desde historial) | Sí (backend lo lee) |
| **Feedback entrada** | Automático (IA analiza) | Manual (empresa ingresa) |
| **Tiempo generación** | ~3-5 segundos | ~10-15 segundos (backend) |
| **Fallback** | IA de Claude | Error message |
| **Disponibilidad** | Solo con API key | Siempre (backend) |

---

## 📌 Resumen

✅ **Backend hace todo:**
1. Recibe rechazo + feedback de empresa
2. Genera IA analizando CV + feedback
3. Devuelve retroalimentación con roadmap

✅ **Cliente solo consulta:**
1. Llama GET /retroalimentacion/postulacion/{id}
2. Poll si está "pendiente"
3. Muestra resultado visual

✅ **NO se necesita:**
- ANTHROPIC_API_KEY en cliente
- flutter_dotenv
- IA en ApplicationsScreen
- Fallback local

---

**El cliente es SIMPLE CONSUMER del backend. Todo lo complejo está en el servidor.** 🚀
