// lib/presentation/screens/student/applications/applications_screen.dart
//
// Tab Matches: vacantes donde AMBOS (estudiante + empresa) dieron like
// Tab Descartadas: vacantes donde el ESTUDIANTE dio like pero la EMPRESA pasó
//                 → se detecta porque están en historial con le_dio_like=true
//                   pero NO aparecen en matches del servidor.
// La IA de feedback requiere Premium y usa la API de Anthropic.

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

  // FIX: "Descartadas por empresa" = vacantes donde el estudiante dio like
  // pero que NO tienen match con ninguna empresa todavía.
  // Estas son las postulaciones que la empresa vio y pasó (sin match aún).
  List<Map<String, dynamic>> _getDescartadasPorEmpresa(StudentProvider p) {
    final matchIds = p.matches.map((m) {
      final vacante = m['vacante'] as Map<String, dynamic>?;
      return vacante?['id'] as int? ?? m['vacante_id'] as int?;
    }).whereType<int>().toSet();

    return p.historial.where((h) {
      final leDioLike = h['le_dio_like'] as bool? ?? false;
      final tipo      = h['tipo'] as String? ?? '';
      final esMatch   = h['match'] as bool? ?? false;
      final id        = h['id'] as int?;
      // Estudiante dio like + NO hay match → empresa no hizo match (la ignoró)
      return (leDioLike || tipo == 'like') && !esMatch && !matchIds.contains(id);
    }).toList();
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
          tabs: [
            Consumer<StudentProvider>(builder: (_, p, __) => Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.favorite, size: 16),
                const SizedBox(width: 6),
                Text('Matches (${p.matches.length})'),
              ]),
            )),
            Consumer<StudentProvider>(builder: (_, p, __) {
              final count = _getDescartadasPorEmpresa(p).length;
              return Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.hourglass_empty_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Sin respuesta ($count)'),
                ]),
              );
            }),
          ],
        ),
      ),
      body: Consumer<StudentProvider>(builder: (context, p, _) {
        if (p.cargandoHistorial && p.historial.isEmpty)
          return const Center(child: CircularProgressIndicator());

        final descartadas = _getDescartadasPorEmpresa(p);

        return RefreshIndicator(
          onRefresh: _recargar,
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildMatchesTab(context, p.matches, p),
              _buildDescartadasTab(context, descartadas, p),
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
        'Cuando una empresa también te elija, aparecerán aquí.',
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
    final titulo      = vacante['titulo']         as String? ?? 'Vacante';
    final descripcion = vacante['descripcion']    as String? ?? '';
    final requisitos  = vacante['requisitos']     as String? ?? '';
    final modalidad   = vacante['modalidad']      as String? ?? '';
    final ubicacion   = vacante['ubicacion']      as String? ?? '';
    final contrato    = vacante['tipo_contrato']  as String? ?? '';
    final minS        = vacante['sueldo_minimo'];
    final maxS        = vacante['sueldo_maximo'];
    final moneda      = vacante['moneda']         as String? ?? 'MXN';
    final fechaMatch  = match['fecha_match']      as String?
                     ?? vacante['timestamp']      as String? ?? '';
    // Datos de empresa (inyectados por el repo)
    final empNombre   = vacante['empresa_nombre'] as String?
                     ?? match['empresa_nombre']   as String? ?? 'Empresa';
    final empFotoUrl  = vacante['empresa_foto_url'] as String?
                     ?? match['empresa_foto_url']   as String?;
    final empSector   = vacante['empresa_sector'] as String?
                     ?? match['empresa_sector']   as String?;

    String salario = '';
    if (minS != null && maxS != null)
      salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda';
    else if (minS != null) salario = 'Desde \$${_fmt(minS)} $moneda';

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

        // ── Banner match ─────────────────────────────────────────────────
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

            // ── Logo + empresa + puesto ───────────────────────────────────
            Row(children: [
              Container(
                width: 54, height: 54,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14)),
                child: empFotoUrl != null
                    ? Image.network(empFotoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _logoFallback(empNombre))
                    : _logoFallback(empNombre),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(empNombre, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
                Text(titulo, style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.bold)),
                if (empSector != null && empSector.isNotEmpty)
                  Text(empSector, style: AppTextStyles.bodySmall.copyWith(
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
              if (salario.isNotEmpty) _chip(Icons.payments_outlined,
                  salario, AppColors.accentGreen),
              if (contrato.isNotEmpty) _chip(Icons.badge_outlined,
                  contrato, AppColors.accentOrange),
            ]),

            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(descripcion, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.5)),
            ],

            const SizedBox(height: 14),

            // ── Bloque "¿qué sigue?" ───────────────────────────────────
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
    final titulo      = vacante['titulo']         as String? ?? 'Vacante';
    final descripcion = vacante['descripcion']    as String? ?? '';
    final requisitos  = vacante['requisitos']     as String? ?? '';
    final modalidad   = vacante['modalidad']      as String? ?? '';
    final ubicacion   = vacante['ubicacion']      as String? ?? '';
    final contrato    = vacante['tipo_contrato']  as String? ?? '';
    final minS        = vacante['sueldo_minimo'];
    final maxS        = vacante['sueldo_maximo'];
    final moneda      = vacante['moneda']         as String? ?? 'MXN';
    final empNombre   = vacante['empresa_nombre'] as String?
                     ?? match['empresa_nombre']   as String? ?? 'Empresa';
    final empFotoUrl  = vacante['empresa_foto_url'] as String?;
    final empDesc     = vacante['empresa_descripcion'] as String?;

    String salario = '';
    if (minS != null && maxS != null)
      salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda';
    else if (minS != null) salario = 'Desde \$${_fmt(minS)} $moneda';

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
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                Container(width: 56, height: 56, clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16)),
                  child: empFotoUrl != null
                      ? Image.network(empFotoUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _logoFallback(empNombre))
                      : _logoFallback(empNombre),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(empNombre, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
                  Text(titulo, style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
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
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (modalidad.isNotEmpty) _chip(Icons.work_outline,
                      _lModal(modalidad), AppColors.primaryPurple),
                  if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined,
                      ubicacion, AppColors.accentBlue),
                  if (salario.isNotEmpty) _chip(Icons.payments_outlined,
                      salario, AppColors.accentGreen),
                  if (contrato.isNotEmpty) _chip(Icons.badge_outlined,
                      contrato, AppColors.accentOrange),
                ]),
                const SizedBox(height: 20),
                if (empDesc != null && empDesc.isNotEmpty) ...[
                  _sectionTitle('Sobre la empresa'),
                  const SizedBox(height: 8),
                  Text(empDesc, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 18),
                ],
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentGreen.withOpacity(0.25))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Icon(Icons.tips_and_updates_outlined,
                          color: AppColors.accentGreen, size: 16),
                      SizedBox(width: 8),
                      Text('¿Qué sigue?', style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'La empresa puede contactarte por correo o a través de la plataforma. '
                      'Asegúrate de tener tu perfil y CV actualizados.',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary, height: 1.5)),
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
  // TAB 2: SIN RESPUESTA — likes del estudiante sin match aún
  // Pueden ser vacantes donde la empresa aún no revisó, o las ignoró.
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildDescartadasTab(BuildContext context,
      List<Map<String, dynamic>> lista, StudentProvider p) {
    if (lista.isEmpty) {
      return _buildEmpty(
        'Sin postulaciones pendientes',
        'Las vacantes donde diste like pero aún no hay match aparecerán aquí.',
        Icons.hourglass_empty_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: lista.length,
      itemBuilder: (_, i) => _buildPendienteCard(context, lista[i], p),
    );
  }

  Widget _buildPendienteCard(BuildContext context,
      Map<String, dynamic> v, StudentProvider p) {
    final titulo      = v['titulo']           as String? ?? 'Vacante';
    final descripcion = v['descripcion']      as String? ?? '';
    final modalidad   = v['modalidad']        as String? ?? '';
    final ubicacion   = v['ubicacion']        as String? ?? '';
    final minS        = v['sueldo_minimo'];
    final maxS        = v['sueldo_maximo'];
    final moneda      = v['moneda']           as String? ?? 'MXN';
    final ts          = v['timestamp']        as String? ?? '';
    final empNombre   = v['empresa_nombre']   as String? ?? 'Empresa';
    final empFotoUrl  = v['empresa_foto_url'] as String?;
    final empSector   = v['empresa_sector']   as String?;

    final auth       = context.read<AuthProvider>();
    final esPremium  = auth.usuario?.esPremium ?? false;

    String salario = '';
    if (minS != null && maxS != null)
      salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda';
    else if (minS != null) salario = 'Desde \$${_fmt(minS)} $moneda';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header: estado de espera
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accentOrange.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.hourglass_top_outlined,
                size: 14, color: AppColors.accentOrange),
            const SizedBox(width: 6),
            Text('Esperando respuesta de la empresa',
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

            // Logo + empresa + puesto
            Row(children: [
              Container(
                width: 48, height: 48, clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: empFotoUrl != null
                    ? Image.network(empFotoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _logoFallback(empNombre))
                    : _logoFallback(empNombre),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(empNombre, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
                Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w600)),
                if (empSector != null && empSector.isNotEmpty)
                  Text(empSector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
              ])),
            ]),
            const SizedBox(height: 10),

            Wrap(spacing: 6, runSpacing: 4, children: [
              if (modalidad.isNotEmpty)
                _chipMini(_lModal(modalidad), AppColors.primaryPurple),
              if (ubicacion.isNotEmpty)
                _chipMini(ubicacion, AppColors.accentBlue),
              if (salario.isNotEmpty)
                _chipMini(salario, AppColors.accentGreen),
            ]),

            if (descripcion.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(descripcion, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary, height: 1.4)),
            ],

            const SizedBox(height: 12),

            // ── Botón IA feedback Premium ────────────────────────────────
            if (esPremium)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAIFeedback(context, v),
                  icon: const Icon(Icons.auto_awesome, size: 15,
                      color: AppColors.primaryPurple),
                  label: const Text('Análisis IA de tu postulación',
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
              // Teaser premium conectado a la pantalla de paypal
              GestureDetector(
                onTap: () => context.push(AppRoutes.studentPremium),
                child: Container(
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
                    const Expanded(child: Text(
                      'Con Premium la IA analiza tu postulación y te da consejos personalizados',
                      style: TextStyle(fontSize: 12,
                          color: AppColors.primaryPurple),
                    )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple,
                        borderRadius: BorderRadius.circular(8)),
                      child: const Text('Ver planes',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

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
      SizedBox(
        height: 420,
        child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.08),
                shape: BoxShape.circle),
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
        )),
      ),
    ]);

  Widget _sectionTitle(String t) => Text(t,
      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold));

  Widget _logoFallback(String nombre) {
    final ini = nombre.trim().split(' ').where((w) => w.isNotEmpty)
        .take(2).map((w) => w[0].toUpperCase()).join();
    return Center(child: Text(ini, style: TextStyle(
        color: AppColors.primaryPurple, fontWeight: FontWeight.bold,
        fontSize: ini.length == 1 ? 20 : 15)));
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
      default: return m;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGET DE RETROALIMENTACIÓN IA — conectado a la API de Anthropic
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

  // API key desde --dart-define=ANTHROPIC_API_KEY=...
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');

  @override
  void initState() { super.initState(); _generarFeedback(); }

  Future<void> _generarFeedback() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final v         = widget.vacante;
      final titulo    = v['titulo']           as String? ?? 'la vacante';
      final desc      = v['descripcion']      as String? ?? '';
      final requi     = v['requisitos']       as String? ?? '';
      final modalidad = v['modalidad']        as String? ?? '';
      final contrato  = v['tipo_contrato']    as String? ?? '';
      final empNombre = v['empresa_nombre']   as String? ?? '';
      final empSector = v['empresa_sector']   as String? ?? '';
      final empDesc   = v['empresa_descripcion'] as String? ?? '';

      final prompt = '''
Eres un coach de carrera experto en reclutamiento laboral para jóvenes estudiantes mexicanos.
Un estudiante postuló a esta vacante pero aún no ha recibido respuesta de la empresa.

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
(2-3 oraciones sobre el valor de esta vacante/empresa)

💡 Cómo destacar tu perfil para este puesto
(3-4 consejos accionables específicos para esta vacante)

✅ Próximos pasos concretos
(2-3 acciones que puede hacer ahora mismo)

Sé específico. No uses frases genéricas. Máximo 250 palabras en total.
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
    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Análisis IA', style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
                Text(widget.vacante['titulo'] as String? ?? 'Vacante',
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
                  Icon(Icons.workspace_premium, size: 12,
                      color: AppColors.primaryPurple),
                  SizedBox(width: 4),
                  Text('Premium', style: TextStyle(fontSize: 11,
                      color: AppColors.primaryPurple,
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
                    gradient: AppColors.purpleGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 32)),
                const SizedBox(height: 20),
                Text('Analizando tu postulación...',
                    style: AppTextStyles.subtitle1.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('La IA está preparando tu feedback',
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
                  ])))
              : SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                          '${widget.vacante['empresa_nombre'] ?? ''} · '
                          '${widget.vacante['titulo'] ?? 'Vacante'}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text(_feedback, style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary, height: 1.7)),
                    const SizedBox(height: 24),
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
                              borderRadius: BorderRadius.circular(12))),
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