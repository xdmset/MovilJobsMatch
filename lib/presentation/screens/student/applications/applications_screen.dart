// lib/presentation/screens/student/applications/applications_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
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
    _tabs = TabController(length: 2, vsync: this);
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
              Text('$totalMatches match${totalMatches == 1 ? '' : 'es'} activo${totalMatches == 1 ? '' : 's'}',
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
          tabs: [
            Consumer<StudentProvider>(builder: (_, p, __) => Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite, size: 16),
                const SizedBox(width: 6),
                Text('Matches (${p.matches.length})'),
              ]),
            )),
            Consumer<StudentProvider>(builder: (_, p, __) {
              final descartados = p.historial
                  .where((h) => h['le_dio_like'] == false && h['tipo'] != 'like')
                  .length;
              return Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cancel_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Descartados ($descartados)'),
                ]),
              );
            }),
          ],
        ),
      ),
      body: Consumer<StudentProvider>(builder: (context, p, _) {
        if (p.cargandoHistorial && p.historial.isEmpty)
          return const Center(child: CircularProgressIndicator());

        final descartados = p.historial
            .where((h) => h['le_dio_like'] == false && h['tipo'] != 'like')
            .toList();

        return RefreshIndicator(
          onRefresh: _recargar,
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildMatchesTab(context, p.matches, p),
              _buildDescartadosTab(context, descartados, p),
            ],
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: MATCHES
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMatchesTab(BuildContext context,
      List<Map<String, dynamic>> matches, StudentProvider p) {
    if (matches.isEmpty) {
      return _buildEmpty(
        '¡Aún no tienes matches!',
        'Cuando una empresa también te elija, aparecerán aquí con todos los detalles del puesto.',
        Icons.favorite_border,
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
    final titulo      = vacante['titulo']        as String? ?? 'Vacante';
    final descripcion = vacante['descripcion']   as String? ?? '';
    final requisitos  = vacante['requisitos']    as String? ?? '';
    final modalidad   = vacante['modalidad']     as String? ?? '';
    final ubicacion   = vacante['ubicacion']     as String? ?? '';
    final contrato    = vacante['tipo_contrato'] as String? ?? '';
    final minS        = vacante['sueldo_minimo'];
    final maxS        = vacante['sueldo_maximo'];
    final moneda      = vacante['moneda']        as String? ?? 'MXN';
    final sector      = vacante['sector']        as String?
                     ?? vacante['tipo_empresa']  as String? ?? '';
    final fechaMatch  = match['fecha_match']     as String?
                     ?? vacante['timestamp']     as String? ?? '';

    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    return Container(
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

        // ── Header match ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            Text('¡Match!', style: AppTextStyles.subtitle1.copyWith(
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

            // ── Logo + título empresa ──────────────────────────────────
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.business, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.bold)),
                if (sector.isNotEmpty)
                  Text(sector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary)),
              ])),
            ]),
            const SizedBox(height: 14),

            // ── Chips info ─────────────────────────────────────────────
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (modalidad.isNotEmpty) _chip(Icons.work_outline,
                  _lModal(modalidad), AppColors.primaryPurple),
              if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined,
                  ubicacion, AppColors.accentBlue),
              if (salario.isNotEmpty) _chip(Icons.attach_money,
                  salario, AppColors.accentGreen),
              if (contrato.isNotEmpty) _chip(Icons.badge_outlined,
                  contrato, AppColors.textSecondary),
            ]),

            // ── Descripción preview ────────────────────────────────────
            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              Text(descripcion,
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.5)),
            ],

            // ── Requisitos preview ─────────────────────────────────────
            if (requisitos.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.checklist_outlined, size: 14,
                    color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(child: Text(requisitos,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary))),
              ]),
            ],

            const SizedBox(height: 14),

            // ── Botón ver más ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showMatchDetails(context, match),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ver detalles completos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showMatchDetails(BuildContext context, Map<String, dynamic> match) {
    final vacante     = match['vacante'] as Map<String, dynamic>? ?? {};
    final titulo      = vacante['titulo']        as String? ?? 'Vacante';
    final descripcion = vacante['descripcion']   as String? ?? '';
    final requisitos  = vacante['requisitos']    as String? ?? '';
    final modalidad   = vacante['modalidad']     as String? ?? '';
    final ubicacion   = vacante['ubicacion']     as String? ?? '';
    final contrato    = vacante['tipo_contrato'] as String? ?? '';
    final minS        = vacante['sueldo_minimo'];
    final maxS        = vacante['sueldo_maximo'];
    final moneda      = vacante['moneda']        as String? ?? 'MXN';
    final sector      = vacante['sector']        as String?
                     ?? vacante['tipo_empresa']  as String? ?? '';
    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
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
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                      gradient: AppColors.purpleGradient,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.business, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.bold)),
                  if (sector.isNotEmpty)
                    Text(sector, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite, size: 11, color: AppColors.accentGreen),
                      SizedBox(width: 4),
                      Text('¡Match!', style: TextStyle(
                          fontSize: 11, color: AppColors.accentGreen,
                          fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ])),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Info chips
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (modalidad.isNotEmpty) _chip(Icons.work_outline,
                      _lModal(modalidad), AppColors.primaryPurple),
                  if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined,
                      ubicacion, AppColors.accentBlue),
                  if (salario.isNotEmpty) _chip(Icons.attach_money,
                      salario, AppColors.accentGreen),
                  if (contrato.isNotEmpty) _chip(Icons.badge_outlined,
                      contrato, AppColors.textSecondary),
                ]),
                const SizedBox(height: 20),

                if (descripcion.isNotEmpty) ...[
                  _sectionTitle('Descripción del puesto'),
                  const SizedBox(height: 8),
                  Text(descripcion, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 18),
                ],
                if (requisitos.isNotEmpty) ...[
                  _sectionTitle('Requisitos'),
                  const SizedBox(height: 8),
                  Text(requisitos, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 18),
                ],

                // ── Siguiente paso ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.25)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.tips_and_updates_outlined,
                          color: AppColors.accentGreen, size: 18),
                      SizedBox(width: 8),
                      Text('¿Qué sigue?', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'La empresa revisó tu perfil y también te eligió. '
                      'Mantén tu CV actualizado y revisa tu perfil para que '
                      'la empresa pueda contactarte.',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                  ]),
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: DESCARTADOS (por la empresa) — con retroalimentación IA Premium
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDescartadosTab(BuildContext context,
      List<Map<String, dynamic>> descartados, StudentProvider p) {
    if (descartados.isEmpty) {
      return _buildEmpty(
        'Sin vacantes descartadas',
        'Las vacantes que hayas pasado (swipe izquierdo) aparecerán aquí.',
        Icons.cancel_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: descartados.length,
      itemBuilder: (_, i) => _buildDescartadoCard(context, descartados[i], p),
    );
  }

  Widget _buildDescartadoCard(BuildContext context,
      Map<String, dynamic> v, StudentProvider p) {
    final titulo      = v['titulo']        as String? ?? 'Vacante';
    final descripcion = v['descripcion']   as String? ?? '';
    final modalidad   = v['modalidad']     as String? ?? '';
    final ubicacion   = v['ubicacion']     as String? ?? '';
    final minS        = v['sueldo_minimo'];
    final maxS        = v['sueldo_maximo'];
    final moneda      = v['moneda']        as String? ?? 'MXN';
    final ts          = v['timestamp']     as String? ?? '';
    final sector      = v['sector']        as String?
                     ?? v['tipo_empresa']  as String? ?? '';
    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    final auth = context.read<AuthProvider>();
    final esPremium = auth.usuario?.esPremium ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
            const SizedBox(width: 6),
            Text('Descartaste esta vacante',
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

            // Logo + título
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.business_outlined,
                    color: AppColors.textSecondary, size: 22)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
                if (sector.isNotEmpty)
                  Text(sector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
              ])),
            ]),
            const SizedBox(height: 10),

            Wrap(spacing: 6, runSpacing: 4, children: [
              if (modalidad.isNotEmpty) _chipMini(_lModal(modalidad),
                  AppColors.textSecondary),
              if (ubicacion.isNotEmpty) _chipMini(ubicacion,
                  AppColors.textSecondary),
              if (salario.isNotEmpty) _chipMini(salario,
                  AppColors.textSecondary),
            ]),

            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary, height: 1.4)),
            ],

            const SizedBox(height: 12),

            // ── Botón IA feedback (solo premium) ─────────────────────
            if (esPremium)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAIFeedback(context, v),
                  icon: const Icon(Icons.auto_awesome, size: 15,
                      color: AppColors.primaryPurple),
                  label: const Text('¿Por qué no encajé? (IA)',
                      style: TextStyle(color: AppColors.primaryPurple)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryPurple),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              )
            else
              // Teaser premium
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primaryPurple.withOpacity(0.08),
                    AppColors.accentBlue.withOpacity(0.06),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primaryPurple.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_outline, size: 16,
                      color: AppColors.primaryPurple),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Con Premium la IA te explica por qué no encajaste y cómo mejorar tu CV',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPurple),
                  )),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppRoutes.studentPremium),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4)),
                    child: const Text('Ver', style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple)),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  // ── Modal con IA feedback para descartado ─────────────────────────────────
  void _showAIFeedback(BuildContext context, Map<String, dynamic> vacante) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AIFeedbackSheet(vacante: vacante),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildEmpty(String title, String sub, IconData icon) =>
    ListView(children: [
      SizedBox(height: 420, child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: AppColors.textTertiary)),
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

  Widget _sectionTitle(String t) => Text(t,
      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold));

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
      default: return m;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGET DE RETROALIMENTACIÓN IA (Premium)
// Llama a la API de Claude para analizar por qué el estudiante no encajó
// ══════════════════════════════════════════════════════════════════════════════
class _AIFeedbackSheet extends StatefulWidget {
  final Map<String, dynamic> vacante;
  const _AIFeedbackSheet({required this.vacante});
  @override
  State<_AIFeedbackSheet> createState() => _AIFeedbackSheetState();
}

class _AIFeedbackSheetState extends State<_AIFeedbackSheet> {
  bool _cargando = true;
  String _feedback = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _generarFeedback();
  }

  Future<void> _generarFeedback() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final v          = widget.vacante;
      final titulo     = v['titulo']      as String? ?? 'la vacante';
      final desc       = v['descripcion'] as String? ?? '';
      final requi      = v['requisitos']  as String? ?? '';
      final modalidad  = v['modalidad']   as String? ?? '';
      final contrato   = v['tipo_contrato'] as String? ?? '';

      // Obtener perfil del estudiante desde el provider si está disponible
      // Para el prompt usamos los datos de la vacante que tenemos
      final prompt = '''
Eres un coach de carrera profesional y experto en reclutamiento laboral.
Un estudiante descartó (swipe izquierdo) una vacante y quiere saber:
1. Qué podría mejorar en su perfil/CV para este tipo de puesto
2. Si debería reconsiderar la vacante
3. Consejos concretos y accionables

Datos de la vacante descartada:
- Puesto: $titulo
- Modalidad: $modalidad
- Tipo de contrato: $contrato
- Descripción: $desc
- Requisitos: $requi

Responde en español, de forma amigable y motivadora. Máximo 3 secciones cortas:
1. 🎯 Por qué podría ser una buena oportunidad
2. 💡 Qué mejorar en tu perfil para este tipo de puesto  
3. ✅ Próximos pasos concretos

Sé específico basándote en los requisitos de la vacante. Responde directamente sin preámbulos.
''';

      final response = await _callClaude(prompt);
      if (mounted) setState(() { _feedback = response; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'No se pudo generar el análisis. Intenta de nuevo.';
        _cargando = false;
      });
    }
  }

  Future<String> _callClaude(String prompt) async {
    // Llamada a la API de Anthropic
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final http = await _httpPost(uri, jsonEncode({
      'model': 'claude-sonnet-4-20250514',
      'max_tokens': 1000,
      'messages': [{'role': 'user', 'content': prompt}],
    }));
    final data = jsonDecode(http);
    final content = data['content'] as List?;
    if (content == null || content.isEmpty) throw Exception('Sin respuesta');
    return (content.first as Map)['text'] as String? ?? '';
  }

  // HTTP helper sin dependencias externas
  Future<String> _httpPost(Uri uri, String body) async {
    // Usamos HttpClient de dart:io a través de http package
    // En producción ya tienes dio configurado — adaptar según tu api_service
    throw UnimplementedError(
      'Conectar _callClaude con tu ApiService o http package. '
      'El endpoint es POST https://api.anthropic.com/v1/messages '
      'con el body ya formateado correctamente.'
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Análisis IA', style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
                Text('Basado en la vacante descartada',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.workspace_premium, size: 12,
                      color: AppColors.primaryPurple),
                  SizedBox(width: 4),
                  Text('Premium', style: TextStyle(
                      fontSize: 11, color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          const Divider(height: 20),
          Expanded(child: _cargando
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.purpleGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text('Analizando la vacante...',
                    style: AppTextStyles.subtitle1.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('La IA está preparando tu retroalimentación',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary)),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
              ])
            : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.error_outline, size: 48,
                        color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(_error!, style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                        onPressed: _generarFeedback,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar')),
                  ]),
                ))
              : SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Nombre vacante
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.work_outline, size: 16,
                            color: AppColors.primaryPurple),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          widget.vacante['titulo'] as String? ?? 'Vacante',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // Feedback de la IA
                    Text(_feedback, style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary, height: 1.7)),
                    const SizedBox(height: 24),
                    // Botón regenerar
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _generarFeedback,
                        icon: const Icon(Icons.refresh, size: 16,
                            color: AppColors.primaryPurple),
                        label: const Text('Generar nuevo análisis',
                            style: TextStyle(color: AppColors.primaryPurple)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryPurple),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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