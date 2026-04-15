// lib/presentation/screens/student/ai_feedback/ai_feedback_screen.dart
//
// Pantalla de retroalimentación IA — exclusiva para usuarios Premium.
// Llama a la API de Anthropic (Claude) directamente usando http,
// igual que ApiService, sin depender de auth del backend.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class AIFeedbackScreen extends StatefulWidget {
  /// Datos de la postulación/vacante para contextualizar el análisis.
  /// Si se abre desde el historial: pasar los campos de la vacante directamente.
  final String? applicationId;
  final String? companyName;
  final String? position;
  final Map<String, dynamic>? vacanteData;   // datos completos de la vacante
  final Map<String, dynamic>? estudianteData; // perfil del estudiante

  const AIFeedbackScreen({
    super.key,
    this.applicationId,
    this.companyName,
    this.position,
    this.vacanteData,
    this.estudianteData,
  });

  @override
  State<AIFeedbackScreen> createState() => _AIFeedbackScreenState();
}

class _AIFeedbackScreenState extends State<AIFeedbackScreen> {
  bool   _isAnalyzing = true;
  bool   _analysisComplete = false;

  String? _error;
  String _analysisText = '';

  // Secciones parseadas del texto de Claude
  List<_Section> _sections = [];

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    setState(() { _isAnalyzing = true; _error = null; _sections = []; });
    try {
      final text = await _callClaude();
      if (mounted) {
        setState(() {
          _analysisText    = text;
          _sections        = _parseSections(text);
          _isAnalyzing     = false;
          _analysisComplete = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _error = 'No se pudo generar el análisis: $e';
        _isAnalyzing = false;
      });
      }
    }
  }

  Future<String> _callClaude() async {
    final vacante   = widget.vacanteData ?? {};
    final estudiante = widget.estudianteData ?? {};

    final titulo      = widget.position ?? vacante['titulo']      as String? ?? 'el puesto';
    final empresa     = widget.companyName ?? vacante['empresa']  as String? ?? 'la empresa';
    final descripcion = vacante['descripcion']   as String? ?? '';
    final requisitos  = vacante['requisitos']    as String? ?? '';
    final modalidad   = vacante['modalidad']     as String? ?? '';
    final contrato    = vacante['tipo_contrato'] as String? ?? '';
    final ubicacion   = vacante['ubicacion']     as String? ?? '';
    final sueldo      = _salario(vacante);

    final nombre      = estudiante['nombre_completo']      as String? ?? '';
    final nivel       = estudiante['nivel_academico']      as String? ?? '';
    final institucion = estudiante['institucion_educativa'] as String? ?? '';
    final habilidades = estudiante['habilidades']          as String? ?? '';
    final modalPref   = estudiante['modalidad_preferida']  as String? ?? '';
    final biografia   = estudiante['biografia']            as String? ?? '';

    final prompt = '''
Eres un coach de carrera experto en reclutamiento laboral en México y Latinoamérica.
Analiza la compatibilidad entre el perfil de un estudiante y una vacante, y genera un análisis detallado y accionable en español.

## VACANTE
- Puesto: $titulo
- Empresa: $empresa
- Descripción: ${descripcion.isNotEmpty ? descripcion : 'No especificada'}
- Requisitos: ${requisitos.isNotEmpty ? requisitos : 'No especificados'}
- Modalidad: ${modalidad.isNotEmpty ? modalidad : 'No especificada'}
- Tipo de contrato: ${contrato.isNotEmpty ? contrato : 'No especificado'}
- Ubicación: ${ubicacion.isNotEmpty ? ubicacion : 'No especificada'}
- Sueldo: ${sueldo.isNotEmpty ? sueldo : 'No especificado'}

## PERFIL DEL ESTUDIANTE
- Nombre: ${nombre.isNotEmpty ? nombre : 'No especificado'}
- Nivel académico: ${nivel.isNotEmpty ? nivel : 'No especificado'}
- Institución: ${institucion.isNotEmpty ? institucion : 'No especificada'}
- Habilidades: ${habilidades.isNotEmpty ? habilidades : 'No especificadas'}
- Modalidad preferida: ${modalPref.isNotEmpty ? modalPref : 'No especificada'}
- Biografía/Resumen: ${biografia.isNotEmpty ? biografia : 'No especificada'}

## INSTRUCCIONES
Genera un análisis estructurado con EXACTAMENTE estas 5 secciones usando los emojis como encabezados:

🎯 COMPATIBILIDAD
Evalúa del 1-10 qué tan compatible es el perfil con la vacante y explica brevemente por qué.

💪 FORTALEZAS
Lista 3-4 aspectos positivos del perfil que encajan con la vacante.

⚠️ ÁREAS DE MEJORA
Lista 3-4 aspectos específicos que el estudiante debería fortalecer para este tipo de puesto.

📚 PLAN DE ACCIÓN
Da 3-5 recomendaciones concretas y accionables: cursos específicos, certificaciones, proyectos a construir, o habilidades a practicar. Sé específico con nombres de plataformas (Coursera, Udemy, YouTube, etc.).

✅ VEREDICTO
Una o dos oraciones finales con un consejo motivador y claro sobre si aplicar o prepararse más.

Responde SOLO con el análisis estructurado, sin introducción ni conclusión adicional. Sé directo, útil y motivador. Usa español neutro.
''';

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type':      'application/json',
        'anthropic-version': '2023-06-01',
        // La API key se inyecta vía variable de entorno en producción.
        // Para desarrollo: reemplazar con tu key de Anthropic.
        // En producción usar: const String.fromEnvironment('ANTHROPIC_API_KEY')
        'x-api-key': const String.fromEnvironment('ANTHROPIC_API_KEY',
            defaultValue: ''),
      },
      body: jsonEncode({
        'model':      'claude-sonnet-4-20250514',
        'max_tokens': 1500,
        'messages':   [{'role': 'user', 'content': prompt}],
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Error API ${response.statusCode}: ${response.body}');
    }

    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) throw Exception('Sin respuesta');
    return (content.first as Map)['text'] as String? ?? '';
  }

  String _salario(Map<String, dynamic> v) {
    final minS   = v['sueldo_minimo'];
    final maxS   = v['sueldo_maximo'];
    final moneda = v['moneda'] as String? ?? 'MXN';
    if (minS != null && maxS != null) return '\$$minS – \$$maxS $moneda';
    if (minS != null) return 'Desde \$$minS $moneda';
    return '';
  }

  // Parsear las secciones del texto de Claude
  List<_Section> _parseSections(String text) {
    final emojis = ['🎯', '💪', '⚠️', '📚', '✅'];
    final sections = <_Section>[];

    for (int i = 0; i < emojis.length; i++) {
      final emoji = emojis[i];
      final start = text.indexOf(emoji);
      if (start == -1) continue;

      final end = i < emojis.length - 1
          ? text.indexOf(emojis[i + 1])
          : text.length;
      if (end == -1) {
        sections.add(_Section(emoji, text.substring(start).trim()));
        continue;
      }

      sections.add(_Section(emoji, text.substring(start, end).trim()));
    }

    // Si no se pudo parsear (Claude respondió diferente), mostrar todo junto
    if (sections.isEmpty && text.isNotEmpty) {
      sections.add(_Section('🤖', text));
    }
    return sections;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final titulo = widget.position
        ?? widget.vacanteData?['titulo'] as String?
        ?? 'Análisis de compatibilidad';

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Análisis IA'),
          Text(titulo, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop()),
        actions: [
          if (_analysisComplete)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Nuevo análisis',
              onPressed: _startAnalysis,
            ),
          // Badge Premium
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppColors.purpleGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.workspace_premium, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text('Premium', style: TextStyle(
                  fontSize: 11, color: Colors.white,
                  fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
      body: _isAnalyzing
          ? _buildAnalyzingView()
          : _error != null
              ? _buildErrorView()
              : _buildResults(),
    );
  }

  Widget _buildAnalyzingView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
              gradient: AppColors.purpleGradient, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome, size: 56, color: Colors.white)),
        const SizedBox(height: 28),
        const Text('Analizando tu perfil...',
            style: AppTextStyles.h3, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'La IA está comparando tu perfil con los requisitos de la vacante y preparando recomendaciones personalizadas.',
          style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Esto puede tardar unos segundos...',
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary)),
      ]),
    ),
  );

  Widget _buildErrorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
        const SizedBox(height: 16),
        Text('No se pudo generar el análisis',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(_error ?? '', style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            onPressed: _startAnalysis,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar')),
      ]),
    ),
  );

  Widget _buildResults() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [

      // ── Card de contexto ────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primaryPurple.withOpacity(0.12),
            AppColors.accentBlue.withOpacity(0.06),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                gradient: AppColors.purpleGradient,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Análisis generado por IA',
                style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
            Text(
              widget.position ?? widget.vacanteData?['titulo'] as String?
                  ?? 'Vacante analizada',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ])),
        ]),
      ),

      // ── Secciones del análisis ──────────────────────────────────────
      ..._sections.map((s) => _buildSectionCard(s)),

      const SizedBox(height: 8),

      // ── Botón regenerar ─────────────────────────────────────────────
      OutlinedButton.icon(
        onPressed: _startAnalysis,
        icon: const Icon(Icons.refresh, size: 16,
            color: AppColors.primaryPurple),
        label: const Text('Generar nuevo análisis',
            style: TextStyle(color: AppColors.primaryPurple)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.primaryPurple),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),

      const SizedBox(height: 12),
      Text(
        'Este análisis es generado por IA y puede no ser 100% preciso. '
        'Úsalo como guía, no como decisión definitiva.',
        style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary, fontStyle: FontStyle.italic),
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _buildSectionCard(_Section section) {
    final emoji = section.emoji;
    Color accentColor;
    Color bgColor;

    switch (emoji) {
      case '🎯':
        accentColor = AppColors.primaryPurple;
        bgColor     = AppColors.primaryPurple.withOpacity(0.06);
        break;
      case '💪':
        accentColor = AppColors.accentGreen;
        bgColor     = AppColors.accentGreen.withOpacity(0.06);
        break;
      case '⚠️':
        accentColor = Colors.orange;
        bgColor     = Colors.orange.withOpacity(0.06);
        break;
      case '📚':
        accentColor = AppColors.accentBlue;
        bgColor     = AppColors.accentBlue.withOpacity(0.06);
        break;
      case '✅':
        accentColor = AppColors.accentGreen;
        bgColor     = AppColors.accentGreen.withOpacity(0.06);
        break;
      default:
        accentColor = AppColors.textSecondary;
        bgColor     = Colors.transparent;
    }

    // Remover el emoji del encabezado del texto para mostrarlo aparte
    final lines = section.content.split('\n');
    final header = lines.isNotEmpty ? lines.first : '';
    final body   = lines.length > 1
        ? lines.sublist(1).join('\n').trim() : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor == Colors.transparent
            ? Theme.of(context).cardColor : bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Encabezado con emoji
        Text(header, style: AppTextStyles.subtitle1.copyWith(
            fontWeight: FontWeight.bold, color: accentColor)),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 10),
          // Renderizar listas con bullets si el texto usa "-" o "•"
          ..._renderBody(body, accentColor),
        ],
      ]),
    );
  }

  List<Widget> _renderBody(String body, Color accentColor) {
    final lines = body.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return lines.map((line) {
      final trimmed = line.trim();
      final isBullet = trimmed.startsWith('-') || trimmed.startsWith('•')
          || trimmed.startsWith('*');

      if (isBullet) {
        final text = trimmed.replaceFirst(RegExp(r'^[-•*]\s*'), '');
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 6, height: 6,
              decoration: BoxDecoration(
                  color: accentColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary, height: 1.5))),
          ]),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(trimmed, style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary, height: 1.5)),
      );
    }).toList();
  }
}

class _Section {
  final String emoji;
  final String content;
  const _Section(this.emoji, this.content);
}