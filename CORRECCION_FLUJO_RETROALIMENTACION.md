# ⚠️ CORRECCIÓN DEL FLUJO - Retroalimentación

## 🚨 LO QUE CAMBIÓ

Basándome en tu OpenAPI spec y explicación, el flujo **NO es que el cliente genere IA**, sino que:

1. **Empresa rechaza** → Ingresa formulario con qué le falta mejorar
2. **Backend llama IA** → Genera roadmap analizando CV + feedback
3. **Cliente consulta** → Solo muestra lo que backend generó

---

## ❌ LO QUE ESTABA MAL

En las versiones anteriores (SETUP_ANTHROPIC_API_KEY.md, INTEGRATION_GUIDE, etc.) puse:
- ❌ ANTHROPIC_API_KEY en el cliente
- ❌ flutter_dotenv para cargar env
- ❌ `_callClaude()` generando IA en Flutter
- ❌ Fallback local a IA

**Esto era INCORRECTO.** El cliente no debería necesitar API key.

---

## ✅ LO CORRECTO (Según OpenAPI)

### Flujo de la Empresa (Backend)

```
1. Empresa elige "Rechazar" en candidato
2. Sistema muestra formulario:
   ✓ Campo: "¿Qué le falta mejorar?" (campos_mejora)
   ✓ Campo: "Sugerencias para mejora" (sugerencias_perfil)
3. Presiona "Rechazar"
4. Client: PUT /api/v1/postulaciones/{postulacion_id}/estado
   Body:
   {
     "nuevo_estado": "rechazado",
     "feedback": {
       "campos_mejora": "Falta experiencia en React",
       "sugerencias_perfil": "Te recomendamos cursos de..."
     }
   }
5. Backend recibe la solicitud
   ├─ Cambia estado a "rechazado"
   ├─ Crea retroalimentación
   ├─ LLAMA CLAUDE INTERNAMENTE:
   │  - Lee CV del estudiante
   │  - Lee feedback de empresa
   │  - Genera roadmap detallado
   └─ Guarda retroalimentación con roadmap
6. Backend: 200 OK
```

### Flujo del Estudiante (Cliente)

```
1. Estudiante abre "Mis Postulaciones"
2. Tab "Cerradas" (vacantes rechazadas)
3. Presiona "Ver plan de acción"
4. Client: GET /api/v1/retroalimentacion/postulacion/{postulacion_id}
   └─ Backend devuelve la retroalimentación

5. Si roadmap_estado == "generado":
   └─ Muestra roadmap visual

6. Si roadmap_estado == "pendiente":
   ├─ Polling automático (espera max 15s)
   ├─ Cada 3 segundos intenta de nuevo
   └─ Cuando esté generado → muestra resultado

7. Si hay error:
   └─ Muestra mensaje "No hay retroalimentación disponible"
```

---

## 📋 Cambios Necesarios

### Cliente (Flutter) - ApplicationsScreen

**QUÉ QUITAR:**
```dart
// ❌ ELIMINAR estas líneas
import 'dart:convert';
import 'package:http/http.dart' as http;

static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

Future<String> _callClaude(String prompt) async { ... }
Future<void> _generarFeedbackIA() async { ... }
Widget _buildIAContent() { ... }
```

**QUÉ MANTENER:**
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
        if (mounted) setState(() { 
          _retro = retro; 
          _cargando = false; 
        });
        return;
      }
    } catch (e) {
      debugPrint('[RetroSheet] error: $e');
    }
  }
  
  // Sin retroalimentación → mostrar error
  if (mounted) {
    setState(() {
      _errorIA = 'No hay retroalimentación disponible';
      _cargando = false;
    });
  }
}

Widget _buildIAContent() {
  if (_errorIA != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_errorIA!),
      ),
    );
  }
  
  return SizedBox.shrink(); // No mostrar nada si no hay error
}
```

### Backend (Python/FastAPI) - IMPORTANTE

El endpoint `PUT /postulaciones/{postulacion_id}/estado` DEBE:

```python
@router.put("/api/v1/postulaciones/{postulacion_id}/estado")
async def actualizar_estado(
    postulacion_id: int,
    cambio: CambiarEstadoPostulacion,
    current_user = Depends(get_current_user)
):
    postulacion = get_postulacion(postulacion_id)
    postulacion.estado = cambio.nuevo_estado
    
    # ✅ CLAVE: Si es rechazo + tiene feedback
    if cambio.nuevo_estado == "rechazado" and cambio.feedback:
        # 1. Crear retroalimentación
        retro = create_retroalimentacion(
            postulacion_id=postulacion_id,
            campos_mejora=cambio.feedback.campos_mejora,
            sugerencias_perfil=cambio.feedback.sugerencias_perfil
        )
        
        # 2. GENERAR ROADMAP CON CLAUDE (AQUÍ)
        try:
            cv_data = get_cv_estudiante(postulacion.estudiante_id)
            roadmap = await generate_roadmap_with_claude(
                cv=cv_data,
                feedback=cambio.feedback
            )
            retro.roadmap = roadmap
            retro.roadmap_estado = "generado"
        except Exception as e:
            logger.error(f"Error generando roadmap: {e}")
            retro.roadmap_estado = "error"
        
        save(retro)
    
    save(postulacion)
    return {"status": "ok"}
```

---

## 🚀 Acciones Inmediatas

### 1. Cliente (Frontend)

**En este repo (Dart/Flutter):**

```bash
# ❌ NO hacer flutter pub add flutter_dotenv
# ❌ NO crear .env
# ❌ NO configurar ANTHROPIC_API_KEY

# SÍ hacer:
# - Limpiar ApplicationsScreen de lógica IA
# - Mantener solo consulta a RetroalimentacionRepository
# - Simplificar _RetroSheetState
```

### 2. Backend (Python)

**En tu repo backend:**

```python
# ✅ AGREGAR lógica en actualizar_estado():
# - Generar roadmap con Claude
# - Guardar en retroalimentacion
# - Usar campos_mejora + sugerencias_perfil

# ✅ AGREGAR endpoint (ya está):
# POST /api/v1/retroalimentacion/postulacion/{id}/generar-roadmap
# - Para regeneración manual si es necesario

# ✅ Ejemplo prompt para Claude:
'''
Analiza el CV del estudiante y el feedback de la empresa.
Genera un plan de acción CONCRETO con:

CV:
{cv_contenido}

Feedback de la empresa:
- Áreas de mejora: {campos_mejora}
- Sugerencias: {sugerencias_perfil}

Devuelve JSON con:
{
  "habilidades": ["skill1", "skill2"],
  "acciones": ["acción1", "acción2"],
  "recursos": ["link1", "link2"],
  "tiempo_estimado": "4 semanas",
  "prioridad": "alta",
  "roadmap_detallado": [
    {
      "semana": "Semana 1",
      "objetivo": "...",
      "tareas": ["tarea1", "tarea2"]
    }
  ]
}
'''
```

---

## 📊 Resumen de Cambios

| Aspecto | Antes | Ahora |
|--------|-------|-------|
| **IA generada en** | Cliente (Flutter) | Backend (Python) |
| **API Key ubicación** | CLIENT .env | Backend (secrets) |
| **_callClaude()** | ✅ Existe | ❌ No existe |
| **flutter_dotenv** | ✅ Necesaria | ❌ NO necesaria |
| **ANTHROPIC_API_KEY** | ✅ En cliente | ❌ NO en cliente |
| **ApplicationsScreen** | 🔥 Complejo | ✅ Simple |
| **RetroSheetState** | Genera + muestra | Solo muestra |
| **Backend /estado PUT** | Solo cambia estado | Genera IA + retro |

---

## ✅ Documentos a ELIMINAR/ACTUALIZAR

### Eliminar (ya no son válidos):
- ❌ `SETUP_ANTHROPIC_API_KEY.md` - No se necesita en cliente
- ❌ La parte de "fallback a IA" en `INTEGRATION_GUIDE_PREMIUM_RETROALIMENTACION.md`

### Mantener/Actualizar:
- ✅ `RESUMEN_EJECUTIVO.md` - Actualizar descripción
- ✅ `FLUJO_CORRECTO_RETROALIMENTACION.md` - NUEVO (este documento)
- ✅ Resto de documentos

---

## 🎯 Punchline

**Cliente dice:** _"Necesito la retroalimentación de esa postulación"_  
**Backend responde:** _"Aquí está. Yo ya llamé a Claude y generé el roadmap"_  
**Cliente piensa:** _"Qué fácil. Solo muestro lo que me dieron"_ ✨

---

## ❓ Próximos Pasos

1. **Verificar Backend:**
   - ¿Tiene el endpoint PUT /postulaciones/{id}/estado?
   - ¿Llama Claude internamente?
   - ¿Devuelve retroalimentación con roadmap?

2. **Actualizar Cliente:**
   - Quitar imports de http, dart:convert
   - Quitar _callClaude() y _generarFeedbackIA()
   - Simplificar _RetroSheetState

3. **Testing:**
   - Empresa rechaza candidato
   - Inicia formulario con feedback
   - CV se analiza + roadmap se genera (en backend)
   - Estudiante ve roadmap en "Ver plan de acción"

---

**⚡ El cambio es simple para el cliente: solo recibe y muestra lo que backend genera.**
