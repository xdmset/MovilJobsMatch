# 🔌 Para el Equipo de Backend

## Requisitos del Endpoint PUT /postulaciones/{postulacion_id}/estado

### Descripción General

Cuando una empresa rechaza una postulación E INGRESA FEEDBACK, el backend debe:

1. **Cambiar estado** de postulación a "rechazado"
2. **Crear retroalimentación** con feedback de empresa
3. **GENERAR ROADMAP** llamando Claude AI analizando:
   - CV del estudiante
   - Feedback de empresa (campos_mejora + sugerencias_perfil)
4. **Guardar resultado** en base de datos

---

## 📥 Input

### Endpoint
```
PUT /api/v1/postulaciones/{postulacion_id}/estado
```

### Request Body
```json
{
  "nuevo_estado": "rechazado",
  "feedback": {
    "campos_mejora": "Necesitas mejorar en comunicación y liderazgo",
    "sugerencias_perfil": "Te recomendamos tomar un curso de soft skills"
  }
}
```

**Nota:** `feedback` puede ser `null` (si solo rechaza sin comentarios)

---

## 📤 Output

```json
{
  "status": "ok"  // o lo que corresponda
}
```

**La retroalimentación se crea/actualiza internamente.**

---

## 🤖 Lógica Interna Necesaria

### Pseudocódigo

```python
@router.put("/api/v1/postulaciones/{postulacion_id}/estado")
async def actualizar_estado(
    postulacion_id: int,
    cambio: CambiarEstadoPostulacion,
    current_user = Depends(get_current_user)
):
    # 1. Obtener postulación
    postulacion = Postulacion.get(id=postulacion_id)
    postulacion.estado = cambio.nuevo_estado
    postulacion.save()
    
    # 2. Si es RECHAZO + tiene FEEDBACK
    if cambio.nuevo_estado == "rechazado" and cambio.feedback:
        
        # 3. Crear o actualizar retroalimentación
        retro = Retroalimentacion.get_or_create(
            postulacion_id=postulacion_id
        )
        retro.campos_mejora = cambio.feedback.campos_mejora
        retro.sugerencias_perfil = cambio.feedback.sugerencias_perfil
        retro.roadmap_estado = "generando"  # Usar estado pendiente/generando
        retro.save()
        
        # 4. GENERAR ROADMAP CON CLAUDE (AQUÍ ES LA MAGIA)
        try:
            # 4.1 Obtener CV del estudiante
            cv_data = await get_cv_content(postulacion.estudiante_id)
            
            # 4.2 Construir prompt para Claude
            prompt = f"""
            Analiza el siguiente CV y feedback de empresa.
            Genera un plan de acción concreto y ejecutable.
            
            === CV DEL ESTUDIANTE ===
            {cv_data}
            
            === FEEDBACK DE LA EMPRESA ===
            Áreas de mejora: {cambio.feedback.campos_mejora}
            Sugerencias: {cambio.feedback.sugerencias_perfil}
            
            === REQUERIMIENTO ===
            Devuelve un JSON VÁLIDO (solo JSON, sin explicaciones) con esta estructura:
            {{
              "habilidades": ["habilidad1", "habilidad2", ...],
              "acciones": ["acción concreta 1", "acción concreta 2", ...],
              "recursos": ["link o recurso 1", "link o recurso 2", ...],
              "tiempo_estimado": "X semanas",
              "prioridad": "alta|media|baja",
              "roadmap_detallado": [
                {{
                  "semana": "Semana 1-2",
                  "objetivo": "Objetivo principal",
                  "tareas": ["tarea1", "tarea2", "tarea3"]
                }},
                ...
              ]
            }}
            
            Sé específico. No uses frases genéricas.
            """
            
            # 4.3 Llamar Claude
            response = claude_client.messages.create(
                model="claude-3-5-sonnet-20241022",
                max_tokens=2000,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )
            
            # 4.4 Parsear respuesta
            roadmap_text = response.content[0].text
            
            # 4.5 Convertir a JSON
            roadmap_json = parse_json_from_response(roadmap_text)
            
            # 4.6 Mapear a modelo RoadmapData
            roadmap = RoadmapData(
                habilidades=roadmap_json.get("habilidades", []),
                acciones=roadmap_json.get("acciones", []),
                recursos=roadmap_json.get("recursos", []),
                tiempo_estimado=roadmap_json.get("tiempo_estimado", ""),
                prioridad=roadmap_json.get("prioridad", "media"),
                roadmap_detallado=[
                    RoadmapStep(
                        semana=s["semana"],
                        objetivo=s["objetivo"],
                        tareas=s.get("tareas", [])
                    )
                    for s in roadmap_json.get("roadmap_detallado", [])
                ]
            )
            
            # 4.7 Guardar roadmap
            retro.roadmap = roadmap  # O serialize a JSON según tu BD
            retro.roadmap_estado = "generado"
            retro.roadmap_generado_en = datetime.now()
            
        except Exception as e:
            logger.error(f"Error generando roadmap: {e}")
            retro.roadmap_estado = "error"
            # Opcionalmente: enviar notificación para admin
        
        finally:
            retro.save()
    
    return {"status": "ok"}
```

---

## 📦 Dependencias Backend Necesarias

```python
# requirements.txt o pyproject.toml

# Ya debería tener:
fastapi
sqlalchemy
pydantic

# Necesita:
anthropic  # Última versión (pip install -U anthropic)
```

---

## 🔑 Configuración

### Variables de Entorno

```bash
# .env o archivo de configuración
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxx
```

**IMPORTANCIA:** Esta key debe estar en el SERVIDOR, nunca en el cliente.

---

## 🔄 Optional: Endpoint para Regenerar Roadmap

Ya existe en OpenAPI:

```
POST /api/v1/retroalimentacion/postulacion/{postulacion_id}/generar-roadmap
```

Usar si usuario presiona "Regenerar" o hay error inicial.

---

## 📋 Testing Checklist

### Test 1: Rechazo sin feedback
```bash
PUT /api/v1/postulaciones/1/estado
{
  "nuevo_estado": "rechazado"
}
```
**Esperado:** 200 OK, estado cambiado, sin retroalimentación creada

### Test 2: Rechazo con feedback
```bash
PUT /api/v1/postulaciones/1/estado
{
  "nuevo_estado": "rechazado",
  "feedback": {
    "campos_mejora": "Falta experiencia en React",
    "sugerencias_perfil": "Te recomendamos completar un bootcamp"
  }
}
```
**Esperado:** 
- 200 OK
- Estado = "rechazado"
- Retroalimentación creada
- Roadmap generado
- roadmap_estado = "generado"

### Test 3: Consultar retroalimentación
```bash
GET /api/v1/retroalimentacion/postulacion/1
```
**Esperado:**
```json
{
  "id": 123,
  "postulacion_id": 1,
  "campos_mejora": "...",
  "sugerencias_perfil": "...",
  "roadmap_estado": "generado",
  "roadmap": {
    "habilidades": [...],
    "acciones": [...],
    "recursos": [...],
    ...
  }
}
```

---

## ⚠️ Consideraciones

### Performance
- Generar roadmap toma ~3-5 segundos
- Considerar usar task queue (Celery, RQ) para requests async
- O devolver estado "pendiente" al inicio, luego generar en background

### Manejo de Errores
- Si Claude falla → guardar roadmap_estado = "error"
- Permitir que usuario regenere desde endpoint POST
- No bloquear el cambio de estado si IA falla

### Rate Limiting
- Claude tiene rate limits
- Implementar caché para prompts similares
- Considerar costo (Claude 3.5 Sonnet ~$3/1M tokens)

---

## 🚀 Ejemplo Completo

Ver el archivo `FLUJO_CORRECTO_RETROALIMENTACION.md` para diagrama de flujo completo.

---

## 📞 Preguntas Frecuentes

**Q: ¿Y si el CV no existe?**  
A: Usar placeholder o permitir generación genérica

**Q: ¿Qué si Claude retorna formato inválido?**  
A: Validar JSON, si falla escribir roadmap_estado = "error"

**Q: ¿Almacenar roadmap como JSON en BD?**  
A: Sí, o como texto si prefieres

**Q: ¿Notificar al estudiante?**  
A: Opcional, pero recomendado

---

**Este es el ÚNICO cambio backend requerido para que todo funcione correctamente.** ✨
