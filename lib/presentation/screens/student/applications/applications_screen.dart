// lib/presentation/screens/student/applications/applications_screen.dart
//
// Tab 1 - Matches:       ambos dieron like (datos de /matches/estudiante/{id})
// Tab 2 - Sin respuesta: estudiante dio like, vacante activa, empresa aún no responde
// Tab 3 - Rechazadas:    estudiante dio like, pero la vacante está cerrada/inactiva
//
// Retroalimentación:
//   - Premium: muestra roadmap del backend (generado por IA en servidor).
//     Backend llama IA cuando empresa rechaza + ingresa feedback.
//   - Sin premium: teaser con botón a pantalla premium.
//
// postulacion_id: se guarda en SharedPreferences cuando se crea postulación.
// Se recupera del historial enriquecido cuando se abre ApplicationsScreen.
//
// Flujo:
//   1. Empresa rechaza postulación + ingresa feedback
//   2. Backend crea retroalimentación + LLAMA IA (Claude)
//   3. Backend genera roadmap y lo guarda
//   4. Cliente: GET /retroalimentacion/postulacion/{id}
//   5. Cliente: muestra roadmap si está generado, o polling si pendiente

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../../data/repositories/retroalimentacion_repository.dart';

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

  Set<int> _matchIds(StudentProvider p) => p.matches.map((m) {
    final vacante = m['vacante'] as Map<String, dynamic>?;
    return vacante?['id'] as int? ?? m['vacante_id'] as int?;
  }).whereType<int>().toSet();

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

  List<Map<String, dynamic>> _getSinRespuesta(StudentProvider p) =>
      _getLikesEstudiante(p).where((h) {
        final estado = (h['estado'] as String? ?? 'activa').toLowerCase();
        return estado == 'activa' || estado == 'pausada' || estado.isEmpty;
      }).toList();

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
    // postulacion_id puede venir del match o del vacante enriquecido
    final postulacionId = match['postulacion_id'] as int?
        ?? vacante['postulacion_id'] as int?;

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
            _buildBotonRetro(context, vacante, esPremium,
                postulacionId: postulacionId,
                contextoPrompt: 'match — la empresa también los eligió'),
          ]),
        ),
      ]),
    ),
    );
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
    final esPremium   = context.read<AuthProvider>().usuario?.esPremium ?? false;
    final postulacionId = v['postulacion_id'] as int?;

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
            _buildBotonRetro(context, v, esPremium,
                postulacionId: postulacionId,
                contextoPrompt: 'postulación enviada, empresa aún no ha respondido'),
          ]),
        ),
      ]),
    ),
    );
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
    final esPremium   = context.read<AuthProvider>().usuario?.esPremium ?? false;
    final postulacionId = v['postulacion_id'] as int?;

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
                  'Esta vacante ya cerró. Con Premium obtienes un plan de acción '
                  'personalizado con IA para mejorar tu perfil.',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 12),

            // Tab de Cerradas: es donde más valor tiene el roadmap
            _buildBotonRetro(context, v, esPremium,
                postulacionId: postulacionId,
                contextoPrompt: 'la vacante ya cerró sin que hubiera match',
                labelBoton: 'Ver plan de acción IA'),
          ]),
        ),
      ]),
    ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BOTÓN DE RETROALIMENTACIÓN — lógica central
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Prioridad:
  //  1. Premium + postulacionId → intenta cargar retroalimentación real del backend.
  //     Si hay roadmap del backend → muestra _RetroBackendSheet.
  //     Si no hay datos del backend → fallback a IA (_AIFeedbackSheet).
  //  2. Premium sin postulacionId → fallback directo a IA.
  //  3. Sin premium → teaser.
  Widget _buildBotonRetro(
    BuildContext context,
    Map<String, dynamic> vacante,
    bool esPremium, {
    int? postulacionId,
    String? contextoPrompt,
    String? labelBoton,
  }) {
    if (esPremium) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showRetro(
            context, vacante, postulacionId, contextoPrompt,
          ),
          icon: const Icon(Icons.auto_awesome, size: 15, color: AppColors.primaryPurple),
          label: Text(labelBoton ?? 'Ver análisis y plan de acción',
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
            'Con Premium la IA genera un roadmap personalizado para mejorar tu perfil',
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

  void _showRetro(
    BuildContext context,
    Map<String, dynamic> vacante,
    int? postulacionId,
    String? contextoPrompt,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RetroSheet(
        vacante: vacante,
        postulacionId: postulacionId,
        contextoExtra: contextoPrompt,
      ),
    );
  }

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
// SHEET DE RETROALIMENTACIÓN — primero intenta el backend, luego IA como fallback
// ══════════════════════════════════════════════════════════════════════════════
class _RetroSheet extends StatefulWidget {
  final Map<String, dynamic> vacante;
  final int? postulacionId;
  final String? contextoExtra;

  const _RetroSheet({
    required this.vacante,
    this.postulacionId,
    this.contextoExtra,
  });

  @override
  State<_RetroSheet> createState() => _RetroSheetState();
}

class _RetroSheetState extends State<_RetroSheet> {
  final _retroRepo = RetroalimentacionRepository.instance;

  // Estado de carga
  bool _cargando = true;
  String _fase = 'Cargando retroalimentación...';
  RetroalimentacionRead? _retro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _fase = 'Consultando feedback del backend...'; });

    if (widget.postulacionId != null) {
      try {
        final retro = await _retroRepo.getRetroalimentacion(widget.postulacionId!);
        if (mounted) {
          setState(() {
            _retro = retro;
            _cargando = false;
            _fase = retro != null && retro.tieneContenido
                ? 'Análisis generado'
                : 'No hay retroalimentación disponible aún';
          });
        }
      } catch (e) {
        debugPrint('[RetroSheet] error: $e');
        if (mounted) {
          setState(() {
            _cargando = false;
            _fase = 'Error al cargar retroalimentación';
          });
        }
      }
    } else {
      if (mounted) setState(() { _cargando = false; _fase = 'No hay información de postulación'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo    = widget.vacante['titulo']       as String? ?? 'Vacante';
    final empNombre = widget.vacante['empresa_nombre'] as String? ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.97, minChildSize: 0.4,
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
                Text('Plan de acción IA', style: AppTextStyles.subtitle1.copyWith(
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
            ? _buildLoading()
            : SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                child: _retro != null
                    ? _buildBackendContent(_retro!)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(children: [
                            Icon(Icons.info_outline, size: 48,
                                color: AppColors.textTertiary),
                            const SizedBox(height: 16),
                            Text(_fase, style: AppTextStyles.subtitle1,
                                textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
              ),
          ),
        ]),
      ),
    );
  }

  Widget _buildLoading() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: AppColors.purpleGradient, shape: BoxShape.circle),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32)),
      const SizedBox(height: 20),
      Text(_fase, style: AppTextStyles.subtitle1.copyWith(
          color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text('Preparando tu feedback personalizado',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
      const SizedBox(height: 24),
      const CircularProgressIndicator(),
    ],
  );

  // ── Vista del contenido del BACKEND ──────────────────────────────────────
  Widget _buildBackendContent(RetroalimentacionRead retro) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Fuente: empresa
      if (retro.camposMejora != null || retro.sugerenciasPerfil != null)
        _seccionHeader('Feedback de la empresa', Icons.business_outlined,
            AppColors.accentOrange),

      if (retro.camposMejora != null && retro.camposMejora!.isNotEmpty) ...[
        const SizedBox(height: 8),
        _tarjetaInfo('Áreas de mejora', retro.camposMejora!,
            Icons.trending_up, AppColors.accentOrange),
        const SizedBox(height: 12),
      ],

      if (retro.sugerenciasPerfil != null && retro.sugerenciasPerfil!.isNotEmpty) ...[
        _tarjetaInfo('Sugerencias para tu perfil', retro.sugerenciasPerfil!,
            Icons.tips_and_updates_outlined, AppColors.accentBlue),
        const SizedBox(height: 20),
      ],

      // Roadmap generado por IA del backend
      if (retro.roadmapListo) ...[
        _seccionHeader('Tu plan de acción', Icons.map_outlined,
            AppColors.primaryPurple),
        const SizedBox(height: 12),

        // Badge tiempo y prioridad
        Row(children: [
          _badgeInfo(Icons.schedule, retro.roadmap!.tiempoEstimado,
              AppColors.accentGreen),
          const SizedBox(width: 8),
          _badgeInfo(Icons.flag_outlined,
              'Prioridad ${retro.roadmap!.prioridad}',
              _prioridadColor(retro.roadmap!.prioridad)),
        ]),
        const SizedBox(height: 16),

        // Habilidades clave
        if (retro.roadmap!.habilidades.isNotEmpty) ...[
          Text('Habilidades clave', style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: retro.roadmap!.habilidades
              .map((h) => _chipHabilidad(h)).toList()),
          const SizedBox(height: 16),
        ],

        // Roadmap semana a semana
        if (retro.roadmap!.roadmapDetallado.isNotEmpty) ...[
          Text('Semana a semana', style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...retro.roadmap!.roadmapDetallado.asMap().entries.map((e) =>
              _buildSemanaCard(e.value, e.key)),
          const SizedBox(height: 16),
        ],

        // Acciones rápidas
        if (retro.roadmap!.acciones.isNotEmpty) ...[
          Text('Acciones recomendadas', style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...retro.roadmap!.acciones.map((a) => _buildBulletItem(a,
              Icons.check_circle_outline, AppColors.accentGreen)),
          const SizedBox(height: 16),
        ],

        // Recursos
        if (retro.roadmap!.recursos.isNotEmpty) ...[
          Text('Recursos recomendados', style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...retro.roadmap!.recursos.map((r) => _buildBulletItem(r,
              Icons.library_books_outlined, AppColors.accentBlue)),
          const SizedBox(height: 16),
        ],
      ],

      // Si roadmap está pendiente (debería haberse resuelto con polling, pero por si acaso)
      if (retro.roadmapPendiente)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.4))),
          child: Row(children: [
            const Icon(Icons.pending_outlined, color: Colors.amber),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'El plan de acción está siendo generado. Vuelve en unos momentos.',
              style: TextStyle(color: Colors.amber),
            )),
          ]),
        ),

      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _cargar(),
          icon: const Icon(Icons.refresh, size: 16, color: AppColors.primaryPurple),
          label: const Text('Actualizar', style: TextStyle(color: AppColors.primaryPurple)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primaryPurple),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ── Helpers de UI del backend ─────────────────────────────────────────────

  Widget _seccionHeader(String titulo, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(titulo, style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.bold, color: color)),
    ]),
  );

  Widget _tarjetaInfo(String titulo, String contenido, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(titulo, style: AppTextStyles.bodySmall.copyWith(
                color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(contenido, style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary, height: 1.5)),
        ]),
      );

  Widget _badgeInfo(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _chipHabilidad(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontSize: 12,
        color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
  );

  Widget _buildSemanaCard(RoadmapStep step, int index) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text('${index + 1}', style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(step.semana, style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold))),
      ]),
      if (step.objetivo.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(step.objetivo, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary)),
      ],
      if (step.tareas.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...step.tareas.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.radio_button_unchecked,
                  size: 10, color: AppColors.primaryPurple),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(t, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary))),
          ]),
        )),
      ],
    ]),
  );

  Widget _buildBulletItem(String texto, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(texto, style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary, height: 1.4))),
    ]),
  );

  Color _prioridadColor(String p) {
    switch (p.toLowerCase()) {
      case 'alta':  return AppColors.error;
      case 'media': return AppColors.accentOrange;
      case 'baja':  return AppColors.accentGreen;
      default:      return AppColors.textSecondary;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DETALLE DE VACANTE + EMPRESA (sin cambios respecto al original)
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
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              logoEmpresa(),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(empNombre,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: accentColor, fontWeight: FontWeight.bold))),
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
                Text(titulo, style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.bold)),
              ])),
            ]),
          ),
          const Divider(height: 1),

          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (modalidad.isNotEmpty) _chipDetalle(lModal(modalidad), accentColor),
                if (ubicacion.isNotEmpty) _chipDetalle('📍 $ubicacion', AppColors.accentBlue),
                if (salario.isNotEmpty)   _chipDetalle('💰 $salario', AppColors.accentGreen),
                if (contrato.isNotEmpty)  _chipDetalle('📋 $contrato', AppColors.accentOrange),
              ]),
              const SizedBox(height: 20),

              if (descripcion.isNotEmpty) ...[
                sectionTitle('Descripción del puesto'),
                Text(descripcion, style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary, height: 1.6)),
                const SizedBox(height: 20),
              ],

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