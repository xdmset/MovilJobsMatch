// lib/presentation/screens/student/applications/applications_screen.dart
//
// Tab 1 - Matches:       ambos dieron like (datos de /matches/estudiante/{id})
// Tab 2 - Sin respuesta: estudiante dio like, vacante activa, empresa aún no responde
// Tab 3 - Rechazadas:    estudiante dio like, pero la vacante está cerrada/inactiva
//                        → señal de que ya no hay oportunidad aquí
//
// Feedback IA: disponible en las 3 tabs con Premium, teaser con botón a premium sin él.
// Conectado a la API de Anthropic via dart-define ANTHROPIC_API_KEY.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});
  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recargar());
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _recargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) {
      final p = context.read<StudentProvider>();
      await p.cargarHistorial(id);
      await p.cargarMatches(id);
    }
  }

  // ── Lógica de clasificación ───────────────────────────────────────────────

  /// IDs de vacantes con match real del servidor
  Set<int> _matchIds(StudentProvider p) => p.matches.map((m) {
    final vacante = m['vacante'] as Map<String, dynamic>?;
    return vacante?['id'] as int? ?? m['vacante_id'] as int?;
  }).whereType<int>().toSet();

  /// Todos los likes sin match del estudiante
  List<Map<String, dynamic>> _getLikesEstudiante(StudentProvider p) {
    final ids = _matchIds(p);
    return p.historial.where((h) {
      final leDioLike = h['le_dio_like'] as bool? ?? false;
      final tipo      = h['tipo'] as String? ?? '';
      final esMatch   = h['match'] as bool? ?? false;
      final id        = h['id'] as int?;
      return (leDioLike || tipo == 'like') && !esMatch && !ids.contains(id);
    }).toList();
  }

  /// Sin respuesta: dio like, vacante activa, empresa no respondió aún
  List<Map<String, dynamic>> _getSinRespuesta(StudentProvider p) =>
      _getLikesEstudiante(p).where((h) {
        final estado = (h['estado'] as String? ?? 'activa').toLowerCase();
        return estado == 'activa' || estado == 'pausada' || estado.isEmpty;
      }).toList();

  /// Cerradas: dio like, vacante ya no activa (cerrada/archivada)
  List<Map<String, dynamic>> _getRechazadas(StudentProvider p) =>
      _getLikesEstudiante(p).where((h) {
        final estado = (h['estado'] as String? ?? 'activa').toLowerCase();
        return estado == 'cerrada' || estado == 'inactiva' || estado == 'archivada';
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Consumer<StudentProvider>(builder: (_, p, __) {
          final totalMatches = p.matches.length;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mis postulaciones'),
            if (totalMatches > 0)
              Text('$totalMatches match${totalMatches == 1 ? '' : 'es'}',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
          ]);
        }),
        actions: [
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: _recargar, tooltip: 'Actualizar'),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Consumer<StudentProvider>(builder: (_, p, __) => Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite, size: 15),
                const SizedBox(width: 5),
                Text('Matches (${p.matches.length})'),
              ]),
            )),
            Consumer<StudentProvider>(builder: (_, p, __) {
              final count = _getSinRespuesta(p).length;
              return Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.hourglass_empty_outlined, size: 15),
                const SizedBox(width: 5),
                Text('Sin respuesta ($count)'),
              ]));
            }),
            Consumer<StudentProvider>(builder: (_, p, __) {
              final count = _getRechazadas(p).length;
              return Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cancel_outlined, size: 15),
                const SizedBox(width: 5),
                Text('Cerradas ($count)'),
              ]));
            }),
          ],
        ),
      ),
      body: Consumer<StudentProvider>(builder: (context, p, _) {
        if (p.cargandoHistorial && p.historial.isEmpty)
          return const Center(child: CircularProgressIndicator());

        return RefreshIndicator(
          onRefresh: _recargar,
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildMatchesTab(context, p.matches),
              _buildSinRespuestaTab(context, _getSinRespuesta(p)),
              _buildRechazadasTab(context, _getRechazadas(p)),
            ],
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: MATCHES
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMatchesTab(BuildContext context, List<Map<String, dynamic>> matches) {
    if (matches.isEmpty) {
      return _buildEmpty(
        '¡Aún no tienes matches!',
        'Cuando una empresa también te elija, aparecerán aquí.',
        Icons.favorite_border,
        AppColors.accentGreen,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: matches.length,
      itemBuilder: (_, i) => _buildMatchCard(context, matches[i]),
    );
  }

  Widget _buildMatchCard(BuildContext context, Map<String, dynamic> match) {
    final vacante     = match['vacante'] as Map<String, dynamic>? ?? {};
    final titulo      = vacante['titulo']           as String? ?? 'Vacante';
    final descripcion = vacante['descripcion']      as String? ?? '';
    final modalidad   = vacante['modalidad']        as String? ?? '';
    final ubicacion   = vacante['ubicacion']        as String? ?? '';
    final contrato    = vacante['tipo_contrato']    as String? ?? '';
    final minS        = vacante['sueldo_minimo'];
    final maxS        = vacante['sueldo_maximo'];
    final moneda      = vacante['moneda']           as String? ?? 'MXN';
    final fechaMatch  = match['fecha_match']        as String? ?? '';
    final empNombre   = vacante['empresa_nombre']   as String?
                     ?? match['empresa_nombre']     as String? ?? 'Empresa';
    final empFotoUrl  = vacante['empresa_foto_url'] as String?
                     ?? match['empresa_foto_url']   as String?;
    final empSector   = vacante['empresa_sector']   as String?
                     ?? match['empresa_sector']     as String?;
    final esPremium   = context.read<AuthProvider>().usuario?.esPremium ?? false;

    String salario = '';
    if (minS != null && maxS != null)
      salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda';
    else if (minS != null) salario = 'Desde \$${_fmt(minS)} $moneda';

    return GestureDetector(
      onTap: () => _showDetalle(context, vacante, accentColor: AppColors.accentGreen),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(
            color: AppColors.accentGreen.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner match
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.accentGreen.withOpacity(0.15),
              AppColors.primaryPurple.withOpacity(0.08),
            ]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            const Icon(Icons.favorite, size: 16, color: AppColors.accentGreen),
            const SizedBox(width: 8),
            Text('¡Match! 🎉', style: AppTextStyles.subtitle1.copyWith(
                color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (fechaMatch.isNotEmpty)
              Text(_formatFecha(fechaMatch), style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _logoEmpresa(empFotoUrl, empNombre, 54, 14),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(empNombre, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
                Text(titulo, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold)),
                if (empSector != null && empSector.isNotEmpty)
                  Text(empSector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary)),
              ])),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (modalidad.isNotEmpty) _chip(Icons.work_outline, _lModal(modalidad), AppColors.primaryPurple),
              if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined, ubicacion, AppColors.accentBlue),
              if (salario.isNotEmpty)   _chip(Icons.payments_outlined, salario, AppColors.accentGreen),
              if (contrato.isNotEmpty)  _chip(Icons.badge_outlined, contrato, AppColors.accentOrange),
            ]),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.5)),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentGreen.withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: AppColors.accentGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'La empresa revisó tu perfil y te eligió. '
                  'Mantén tu CV actualizado para que puedan contactarte.',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, height: 1.5),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            // Feedback IA disponible en matches también
            _buildBotonIA(context, vacante, esPremium,
                contextoPrompt: 'match — la empresa también los eligió'),
          ]),
        ),
      ]),
    ), // Container
    ); // GestureDetector
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: SIN RESPUESTA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSinRespuestaTab(BuildContext context, List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return _buildEmpty(
        'Sin postulaciones pendientes',
        'Las vacantes donde diste like pero aún no hay respuesta aparecerán aquí.',
        Icons.hourglass_empty_outlined,
        AppColors.accentOrange,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: lista.length,
      itemBuilder: (_, i) => _buildPendienteCard(context, lista[i]),
    );
  }

  Widget _buildPendienteCard(BuildContext context, Map<String, dynamic> v) {
    final titulo    = v['titulo']           as String? ?? 'Vacante';
    final descripcion = v['descripcion']    as String? ?? '';
    final modalidad = v['modalidad']        as String? ?? '';
    final ubicacion = v['ubicacion']        as String? ?? '';
    final minS      = v['sueldo_minimo'];
    final maxS      = v['sueldo_maximo'];
    final moneda    = v['moneda']           as String? ?? 'MXN';
    final ts        = v['timestamp']        as String? ?? '';
    final empNombre = v['empresa_nombre']   as String? ?? 'Empresa';
    final empFotoUrl= v['empresa_foto_url'] as String?;
    final empSector = v['empresa_sector']   as String?;
    final esPremium = context.read<AuthProvider>().usuario?.esPremium ?? false;

    String salario = '';
    if (minS != null && maxS != null) salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda';
    else if (minS != null) salario = 'Desde \$${_fmt(minS)} $moneda';

    return GestureDetector(
      onTap: () => _showDetalle(context, v, accentColor: AppColors.accentOrange),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accentOrange.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.hourglass_top_outlined, size: 14, color: AppColors.accentOrange),
            const SizedBox(width: 6),
            Text('Esperando respuesta',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accentOrange, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (ts.isNotEmpty)
              Text(_formatFecha(ts), style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _logoEmpresa(empFotoUrl, empNombre, 48, 12),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(empNombre, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
                Text(titulo, style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.w600)),
                if (empSector != null && empSector.isNotEmpty)
                  Text(empSector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
              ])),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (modalidad.isNotEmpty) _chipMini(_lModal(modalidad), AppColors.primaryPurple),
              if (ubicacion.isNotEmpty) _chipMini(ubicacion, AppColors.accentBlue),
              if (salario.isNotEmpty)   _chipMini(salario, AppColors.accentGreen),
            ]),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary, height: 1.4)),
            ],
            const SizedBox(height: 12),
            _buildBotonIA(context, v, esPremium,
                contextoPrompt: 'postulación enviada, empresa aún no ha respondido'),
          ]),
        ),
      ]),
    ), // Container
    ); // GestureDetector
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: RECHAZADAS / VACANTES CERRADAS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildRechazadasTab(BuildContext context, List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return _buildEmpty(
        'Sin vacantes cerradas',
        'Las vacantes donde postulaste pero que ya cerraron aparecerán aquí.',
        Icons.cancel_outlined,
        AppColors.error,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: lista.length,
      itemBuilder: (_, i) => _buildRechazadaCard(context, lista[i]),
    );
  }

  Widget _buildRechazadaCard(BuildContext context, Map<String, dynamic> v) {
    final titulo    = v['titulo']           as String? ?? 'Vacante';
    final descripcion = v['descripcion']    as String? ?? '';
    final modalidad = v['modalidad']        as String? ?? '';
    final ubicacion = v['ubicacion']        as String? ?? '';
    final minS      = v['sueldo_minimo'];
    final maxS      = v['sueldo_maximo'];
    final moneda    = v['moneda']           as String? ?? 'MXN';
    final ts        = v['timestamp']        as String? ?? '';
    final empNombre = v['empresa_nombre']   as String? ?? 'Empresa';
    final empFotoUrl= v['empresa_foto_url'] as String?;
    final empSector = v['empresa_sector']   as String?;
    final esPremium = context.read<AuthProvider>().usuario?.esPremium ?? false;

    String salario = '';
    if (minS != null && maxS != null) salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda';
    else if (minS != null) salario = 'Desde \$${_fmt(minS)} $moneda';

    return GestureDetector(
      onTap: () => _showDetalle(context, v, accentColor: AppColors.error),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header rojo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
            const SizedBox(width: 6),
            Text('Vacante cerrada',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (ts.isNotEmpty)
              Text(_formatFecha(ts), style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Logo empresa con opacidad reducida para indicar cerrada
              Opacity(
                opacity: 0.6,
                child: _logoEmpresa(empFotoUrl, empNombre, 48, 12),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(empNombre, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                if (empSector != null && empSector.isNotEmpty)
                  Text(empSector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
              ])),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (modalidad.isNotEmpty) _chipMini(_lModal(modalidad), AppColors.textSecondary),
              if (ubicacion.isNotEmpty) _chipMini(ubicacion, AppColors.textSecondary),
              if (salario.isNotEmpty)   _chipMini(salario, AppColors.textSecondary),
            ]),
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary, height: 1.4)),
            ],
            const SizedBox(height: 12),

            // Tip motivacional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.primaryPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Esta vacante ya cerró, pero puedes usar el análisis IA para mejorar '
                  'tu perfil y tener más éxito en tu próxima postulación.',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 12),

            // Botón IA — aquí es donde más valor tiene
            _buildBotonIA(context, v, esPremium,
                contextoPrompt: 'la vacante ya cerró sin que hubiera match',
                labelBoton: 'Análisis IA — ¿cómo mejorar?'),
          ]),
        ),
      ]),
    ), // Container
    ); // GestureDetector
  }

  // ── Botón IA reutilizable ─────────────────────────────────────────────────
  // Se usa en los 3 tabs. Si es premium muestra el botón real, si no el teaser.
  Widget _buildBotonIA(
    BuildContext context,
    Map<String, dynamic> vacante,
    bool esPremium, {
    String? contextoPrompt,
    String? labelBoton,
  }) {
    if (esPremium) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showAIFeedback(context, vacante, contextoPrompt),
          icon: const Icon(Icons.auto_awesome, size: 15, color: AppColors.primaryPurple),
          label: Text(labelBoton ?? 'Análisis IA de tu postulación',
              style: const TextStyle(color: AppColors.primaryPurple)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primaryPurple),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }

    // Teaser premium
    return GestureDetector(
      onTap: () => context.push(AppRoutes.studentPremium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primaryPurple.withOpacity(0.08),
            AppColors.accentBlue.withOpacity(0.06),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.primaryPurple),
          const SizedBox(width: 8),
          const Expanded(child: Text(
            'Con Premium la IA analiza tu postulación y te da consejos personalizados',
            style: TextStyle(fontSize: 12, color: AppColors.primaryPurple),
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(8)),
            child: const Text('Ver planes',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ]),
      ),
    );
  }

  // ── Detalle completo de vacante + empresa ─────────────────────────────────
  void _showDetalle(BuildContext context, Map<String, dynamic> vacante,
      {Color? accentColor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleVacanteSheet(
          vacante: vacante, accentColor: accentColor ?? AppColors.primaryPurple),
    );
  }

  void _showAIFeedback(BuildContext context, Map<String, dynamic> vacante,
      [String? contextoExtra]) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AIFeedbackSheet(
        vacante: vacante, contextoExtra: contextoExtra),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildEmpty(String title, String sub, IconData icon, Color color) =>
    ListView(children: [
      SizedBox(height: 420, child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: color.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: color.withOpacity(0.6))),
          const SizedBox(height: 20),
          Text(title, style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub, style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: _recargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar')),
        ]),
      ))),
    ]);

  Widget _logoEmpresa(String? fotoUrl, String nombre, double size, double radius) {
    final ini = nombre.trim().split(' ').where((w) => w.isNotEmpty)
        .take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: size, height: size, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: AppColors.primaryPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(radius)),
      child: fotoUrl != null
          ? Image.network(fotoUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Text(ini,
                  style: TextStyle(color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold, fontSize: size * 0.32))))
          : Center(child: Text(ini, style: TextStyle(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.32))),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _chipMini(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color,
        fontWeight: FontWeight.w600)),
  );

  String _fmt(dynamic n) {
    final d = double.tryParse(n.toString()) ?? 0;
    return d.truncate().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _formatFecha(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month-1]}';
    } catch (_) { return ''; }
  }

  String _lModal(String m) {
    switch (m) {
      case 'remoto':     return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido':    return 'Híbrido';
      default:           return m;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DETALLE DE VACANTE + EMPRESA
// Bottom sheet con toda la información de la vacante y empresa
// ══════════════════════════════════════════════════════════════════════════════
class _DetalleVacanteSheet extends StatelessWidget {
  final Map<String, dynamic> vacante;
  final Color accentColor;
  const _DetalleVacanteSheet({required this.vacante, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final titulo        = vacante['titulo']              as String? ?? 'Vacante';
    final descripcion   = vacante['descripcion']         as String? ?? '';
    final requisitos    = vacante['requisitos']          as String? ?? '';
    final modalidad     = vacante['modalidad']           as String? ?? '';
    final ubicacion     = vacante['ubicacion']           as String? ?? '';
    final contrato      = vacante['tipo_contrato']       as String? ?? '';
    final moneda        = vacante['moneda']              as String? ?? 'MXN';
    final minS          = vacante['sueldo_minimo'];
    final maxS          = vacante['sueldo_maximo'];
    final estado        = vacante['estado']              as String? ?? '';
    final fechaPub      = vacante['fecha_publicacion']   as String? ?? '';

    // Datos empresa
    final empNombre     = vacante['empresa_nombre']      as String? ?? 'Empresa';
    final empFotoUrl    = vacante['empresa_foto_url']    as String?;
    final empSector     = vacante['empresa_sector']      as String? ?? '';
    final empDesc       = vacante['empresa_descripcion'] as String? ?? '';
    final empWeb        = vacante['empresa_sitio_web']   as String? ?? '';
    final empUbicacion  = vacante['empresa_ubicacion']   as String? ?? '';

    String salario = '';
    if (minS != null && maxS != null) {
      salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda';
    } else if (minS != null) {
      salario = 'Desde \$${_fmt(minS)} $moneda';
    }

    String lModal(String m) {
      switch (m) {
        case 'remoto':     return '🌐 Remoto';
        case 'presencial': return '🏢 Presencial';
        case 'hibrido':    return '🔀 Híbrido';
        default:           return m;
      }
    }

    String fmtFecha(String ts) {
      try {
        final d = DateTime.parse(ts).toLocal();
        const m = ['ene','feb','mar','abr','may','jun',
                    'jul','ago','sep','oct','nov','dic'];
        return '${d.day} de ${m[d.month - 1]} de ${d.year}';
      } catch (_) { return ''; }
    }

    Widget infoRow(IconData icon, String label, String value, {Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: color ?? AppColors.textTertiary),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
              Text(value, style: AppTextStyles.bodyMedium.copyWith(
                  color: color ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500)),
            ])),
          ]),
        );

    Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(t, style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.bold)),
    );

    Widget logoEmpresa() {
      final ini = empNombre.trim().split(' ')
          .where((w) => w.isNotEmpty).take(2)
          .map((w) => w[0].toUpperCase()).join();
      return Container(
        width: 64, height: 64, clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3))),
        child: empFotoUrl != null
            ? Image.network(empFotoUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: Text(ini,
                    style: TextStyle(color: accentColor,
                        fontWeight: FontWeight.bold, fontSize: 22))))
            : Center(child: Text(ini, style: TextStyle(
                color: accentColor, fontWeight: FontWeight.bold, fontSize: 22))),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.97, minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),

          // Header empresa
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              logoEmpresa(),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Empresa nombre
                Row(children: [
                  Expanded(child: Text(empNombre,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: accentColor, fontWeight: FontWeight.bold))),
                  // Badge estado
                  if (estado.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: estado == 'activa'
                              ? AppColors.accentGreen.withOpacity(0.12)
                              : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(estado[0].toUpperCase() + estado.substring(1),
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: estado == 'activa'
                                  ? AppColors.accentGreen : AppColors.error)),
                    ),
                ]),
                if (empSector.isNotEmpty)
                  Text(empSector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
                const SizedBox(height: 4),
                // Título puesto
                Text(titulo, style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.bold)),
              ])),
            ]),
          ),
          const Divider(height: 1),

          // Cuerpo scrolleable
          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Chips rápidos ──────────────────────────────────────────────
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (modalidad.isNotEmpty) _chipDetalle(lModal(modalidad), accentColor),
                if (ubicacion.isNotEmpty) _chipDetalle('📍 $ubicacion', AppColors.accentBlue),
                if (salario.isNotEmpty)   _chipDetalle('💰 $salario', AppColors.accentGreen),
                if (contrato.isNotEmpty)  _chipDetalle('📋 $contrato', AppColors.accentOrange),
              ]),
              const SizedBox(height: 20),

              // ── Descripción ────────────────────────────────────────────────
              if (descripcion.isNotEmpty) ...[
                sectionTitle('Descripción del puesto'),
                Text(descripcion, style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary, height: 1.6)),
                const SizedBox(height: 20),
              ],

              // ── Requisitos ─────────────────────────────────────────────────
              if (requisitos.isNotEmpty) ...[
                sectionTitle('Requisitos'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.15))),
                  child: Text(requisitos, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                ),
                const SizedBox(height: 20),
              ],

              // ── Info de la vacante ─────────────────────────────────────────
              sectionTitle('Detalles del puesto'),
              if (modalidad.isNotEmpty)
                infoRow(Icons.work_outline, 'Modalidad', lModal(modalidad)),
              if (ubicacion.isNotEmpty)
                infoRow(Icons.location_on_outlined, 'Ubicación', ubicacion),
              if (salario.isNotEmpty)
                infoRow(Icons.payments_outlined, 'Salario', salario,
                    color: AppColors.accentGreen),
              if (contrato.isNotEmpty)
                infoRow(Icons.badge_outlined, 'Tipo de contrato', contrato),
              if (fechaPub.isNotEmpty)
                infoRow(Icons.calendar_today_outlined, 'Publicada el',
                    fmtFecha(fechaPub)),
              const SizedBox(height: 20),

              // ── Sobre la empresa ───────────────────────────────────────────
              sectionTitle('Sobre la empresa'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.business, size: 16, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(empNombre,
                        style: AppTextStyles.subtitle1.copyWith(
                            fontWeight: FontWeight.bold))),
                  ]),
                  if (empSector.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.category_outlined, size: 14,
                          color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Text(empSector, style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary)),
                    ]),
                  ],
                  if (empUbicacion.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_city_outlined, size: 14,
                          color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Text(empUbicacion, style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary)),
                    ]),
                  ],
                  if (empWeb.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.language_outlined, size: 14,
                          color: AppColors.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(empWeb,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accentBlue),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  if (empDesc.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Text(empDesc, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary, height: 1.5)),
                  ],
                ]),
              ),
              const SizedBox(height: 24),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _chipDetalle(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Text(label, style: TextStyle(fontSize: 12, color: color,
        fontWeight: FontWeight.w600)),
  );

  String _fmt(dynamic n) {
    final d = double.tryParse(n.toString()) ?? 0;
    return d.truncate().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGET DE RETROALIMENTACIÓN IA
// Conectado a la API de Anthropic via --dart-define=ANTHROPIC_API_KEY=sk-ant-...
// ══════════════════════════════════════════════════════════════════════════════
class _AIFeedbackSheet extends StatefulWidget {
  final Map<String, dynamic> vacante;
  final String? contextoExtra;
  const _AIFeedbackSheet({required this.vacante, this.contextoExtra});
  @override
  State<_AIFeedbackSheet> createState() => _AIFeedbackSheetState();
}

class _AIFeedbackSheetState extends State<_AIFeedbackSheet> {
  bool _cargando = true;
  String _feedback = '';
  String? _error;

  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

  @override
  void initState() { super.initState(); _generarFeedback(); }

  Future<void> _generarFeedback() async {
    setState(() { _cargando = true; _error = null; _feedback = ''; });
    try {
      final v         = widget.vacante;
      final titulo    = v['titulo']              as String? ?? 'la vacante';
      final desc      = v['descripcion']         as String? ?? '';
      final requi     = v['requisitos']          as String? ?? '';
      final modalidad = v['modalidad']           as String? ?? '';
      final contrato  = v['tipo_contrato']       as String? ?? '';
      final empNombre = v['empresa_nombre']      as String? ?? '';
      final empSector = v['empresa_sector']      as String? ?? '';
      final empDesc   = v['empresa_descripcion'] as String? ?? '';
      final contexto  = widget.contextoExtra ?? 'postulación enviada';

      final prompt = '''
Eres un coach de carrera experto en reclutamiento laboral para jóvenes estudiantes mexicanos.

Contexto de la postulación: $contexto.

Datos de la vacante:
- Puesto: $titulo
- Empresa: $empNombre${empSector.isNotEmpty ? ' ($empSector)' : ''}
- Modalidad: $modalidad
- Contrato: $contrato
${empDesc.isNotEmpty ? '- Sobre la empresa: $empDesc' : ''}
${desc.isNotEmpty ? '- Descripción: $desc' : ''}
${requi.isNotEmpty ? '- Requisitos: $requi' : ''}

Responde en español, de forma amigable, motivadora y concreta. Usa exactamente 3 secciones:

🎯 Por qué esta oportunidad vale la pena
(2-3 oraciones sobre el valor de esta vacante/empresa para un estudiante)

💡 Cómo destacar tu perfil para este puesto
(3-4 consejos accionables específicos basados en los requisitos de la vacante)

✅ Próximos pasos concretos
(2-3 acciones que puede hacer ahora mismo para mejorar sus chances)

Sé específico. No uses frases genéricas. Máximo 280 palabras en total.
''';

      final text = await _callClaude(prompt);
      if (mounted) setState(() { _feedback = text; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'No se pudo generar el análisis. Verifica tu conexión.';
        _cargando = false;
      });
    }
  }

  Future<String> _callClaude(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('ANTHROPIC_API_KEY no configurada. '
          'Ejecuta con --dart-define=ANTHROPIC_API_KEY=sk-ant-...');
    }
    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type':       'application/json',
        'x-api-key':          _apiKey,
        'anthropic-version':  '2023-06-01',
      },
      body: jsonEncode({
        'model':      'claude-sonnet-4-20250514',
        'max_tokens': 1000,
        'messages':   [{'role': 'user', 'content': prompt}],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final data    = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) throw Exception('Sin respuesta');
    return (content.first as Map)['text'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.vacante['titulo'] as String? ?? 'Vacante';
    final empNombre = widget.vacante['empresa_nombre'] as String? ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.80, maxChildSize: 0.95, minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    gradient: AppColors.purpleGradient,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Análisis IA', style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
                Text('$empNombre · $titulo',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.workspace_premium, size: 12, color: AppColors.primaryPurple),
                  SizedBox(width: 4),
                  Text('Premium', style: TextStyle(fontSize: 11,
                      color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          const Divider(height: 20),

          // Contenido
          Expanded(child: _cargando
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      gradient: AppColors.purpleGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32)),
                const SizedBox(height: 20),
                Text('Analizando tu postulación...',
                    style: AppTextStyles.subtitle1.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('La IA está preparando tu feedback personalizado',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ])
            : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(_error!, style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                        onPressed: _generarFeedback,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar')),
                  ])))
              : SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Contexto de la vacante
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.business_outlined, size: 16,
                            color: AppColors.primaryPurple),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '${empNombre.isNotEmpty ? "$empNombre · " : ""}$titulo',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryPurple, fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Feedback de la IA
                    Text(_feedback, style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary, height: 1.7)),
                    const SizedBox(height: 24),

                    // Regenerar
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _generarFeedback,
                        icon: const Icon(Icons.refresh, size: 16, color: AppColors.primaryPurple),
                        label: const Text('Generar nuevo análisis',
                            style: TextStyle(color: AppColors.primaryPurple)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryPurple),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]),
                ),
          ),
        ]),
      ),
    );
  }
}