// lib/presentation/screens/company/candidates/candidates_screen.dart
//
// FUENTES DE DATOS:
// 1. _candidatosFeed  = GET /swipes/empresa/{id}/candidatos
//    Candidatos que dieron like y están esperando respuesta de la empresa
//    (pendientes de swipe de la empresa)
//
// 2. _postulaciones   = GET /postulaciones/empresa/{id}
//    Todas las postulaciones con su estado actual
//    estados: pendiente, aceptado, rechazado, match

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';

class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key});
  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _recargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) {
      await context.read<CompanyProvider>().recargarCandidatos(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Consumer<CompanyProvider>(
          builder: (_, p, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Candidatos'),
              Text('${p.totalCandidatos} total · ${p.pendientes} pendientes',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recargar,
            tooltip: 'Actualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Consumer<CompanyProvider>(builder: (_, p, __) => Tab(
              text: 'Por revisar (${p.candidatosFeed.length})',
            )),
            Consumer<CompanyProvider>(builder: (_, p, __) => Tab(
              text: 'Matches (${p.matches})',
            )),
            Consumer<CompanyProvider>(builder: (_, p, __) => Tab(
              text: 'Aceptados (${p.aceptados})',
            )),
            const Tab(text: 'Rechazados'),
          ],
        ),
      ),
      body: Consumer<CompanyProvider>(builder: (_, p, __) {
        if (p.cargando && p.postulaciones.isEmpty && p.candidatosFeed.isEmpty)
          return const Center(child: CircularProgressIndicator());

        final rechazados = p.postulaciones
            .where((c) => c['estado'] == 'rechazado').toList();
        final aceptados  = p.postulaciones
            .where((c) => c['estado'] == 'aceptado').toList();
        final matchesList = p.postulaciones
            .where((c) => c['estado'] == 'match').toList();

        return RefreshIndicator(
          onRefresh: _recargar,
          child: TabBarView(
            controller: _tabs,
            children: [
              // Tab 1: Feed — candidatos pendientes de respuesta de la empresa
              _buildFeedTab(context, p.candidatosFeed, p),
              // Tab 2: Matches — ambos dieron like
              _buildPostulacionesTab(context, matchesList, p, esMatch: true),
              // Tab 3: Aceptados
              _buildPostulacionesTab(context, aceptados, p),
              // Tab 4: Rechazados
              _buildPostulacionesTab(context, rechazados, p, esRechazado: true),
            ],
          ),
        );
      }),
    );
  }

  // ── Tab: Feed de candidatos pendientes ────────────────────────────────────
  // Fuente: GET /swipes/empresa/{id}/candidatos
  Widget _buildFeedTab(BuildContext context,
      List<Map<String, dynamic>> feed, CompanyProvider p) {
    if (feed.isEmpty) {
      return _buildEmpty(
        'Sin candidatos pendientes',
        'Cuando los estudiantes den like a tus vacantes aparecerán aquí para que puedas aceptarlos o rechazarlos.',
        Icons.people_outline,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: feed.length,
      itemBuilder: (_, i) => _buildFeedCard(context, feed[i], p),
    );
  }

  Widget _buildFeedCard(BuildContext context,
      Map<String, dynamic> candidato, CompanyProvider p) {
    // CandidateFeedItem puede tener: estudiante_id, vacante_id, y más campos
    final estudianteId = candidato['estudiante_id'] as int?
        ?? candidato['id'] as int? ?? 0;
    final vacanteId    = candidato['vacante_id'] as int? ?? 0;

    // Info de la vacante
    final vacante       = p.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloVacante = vacante['titulo'] as String?
        ?? candidato['vacante_titulo'] as String?
        ?? 'Vacante #$vacanteId';
    final modalidad     = vacante['modalidad'] as String?
        ?? candidato['modalidad'] as String? ?? '';

    // Info del candidato si el backend lo incluye
    final nombre    = candidato['nombre_completo'] as String?
        ?? candidato['nombre'] as String?;
    final nivelAcad = candidato['nivel_academico'] as String?;
    final instit    = candidato['institucion_educativa'] as String?;
    final ubicacion = candidato['ubicacion'] as String?;
    final fechaLike = candidato['fecha_like'] as String?
        ?? candidato['fecha'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.thumb_up_outlined, size: 14,
                color: AppColors.primaryPurple),
            const SizedBox(width: 6),
            Text('Le dio like a tu vacante',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (fechaLike != null)
              Text(_formatFecha(fechaLike),
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Candidato
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
                child: Text(
                  nombre != null && nombre.isNotEmpty
                      ? nombre[0].toUpperCase() : 'E',
                  style: AppTextStyles.h4.copyWith(
                      color: AppColors.primaryPurple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre ?? 'Candidato #$estudianteId',
                    style: AppTextStyles.subtitle1.copyWith(
                        fontWeight: FontWeight.bold)),
                if (nivelAcad != null)
                  Text(nivelAcad, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary)),
                if (instit != null)
                  Text(instit, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
              ])),
            ]),

            // Info de ubicación
            if (ubicacion != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 14,
                    color: AppColors.accentBlue),
                const SizedBox(width: 4),
                Text(ubicacion, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary)),
              ]),
            ],
            const SizedBox(height: 12),

            // Vacante que le interesa
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.work_outline, size: 16,
                    color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Interesado en:', style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
                  Text(tituloVacante,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.accentBlue,
                          fontWeight: FontWeight.w600)),
                  if (modalidad.isNotEmpty)
                    Text(_lModal(modalidad),
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary)),
                ])),
              ]),
            ),
            const SizedBox(height: 14),

            // Botones de acción
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _rechazar(context, p,
                    estudianteId: estudianteId, vacanteId: vacanteId),
                icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                label: const Text('Rechazar',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _aceptar(context, p,
                    estudianteId: estudianteId, vacanteId: vacanteId,
                    nombre: nombre),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Aceptar'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: AppColors.accentGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Tab: Postulaciones por estado ─────────────────────────────────────────
  // Fuente: GET /postulaciones/empresa/{id} filtradas por estado
  Widget _buildPostulacionesTab(BuildContext context,
      List<Map<String, dynamic>> lista, CompanyProvider p, {
      bool esMatch = false, bool esRechazado = false}) {
    if (lista.isEmpty) {
      final (icon, msg) = esMatch
          ? (Icons.favorite_outline,
             'Aún no hay matches\nCuando aceptes a un candidato que también te eligió, aparecerá aquí')
          : esRechazado
          ? (Icons.cancel_outlined, 'No hay candidatos rechazados')
          : (Icons.check_circle_outline, 'No hay candidatos aceptados');
      return _buildEmpty(esMatch ? 'Sin matches aún'
          : esRechazado ? 'Sin rechazados' : 'Sin aceptados', msg, icon);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (_, i) => _buildPostulacionCard(
          context, lista[i], p,
          esMatch: esMatch, esRechazado: esRechazado),
    );
  }

  Widget _buildPostulacionCard(BuildContext context,
      Map<String, dynamic> post, CompanyProvider p, {
      bool esMatch = false, bool esRechazado = false}) {
    final estudianteId  = post['estudiante_id'] as int? ?? 0;
    final vacanteId     = post['vacante_id']    as int? ?? 0;
    final estado        = post['estado']        as String? ?? '';
    final fechaStr      = post['fecha_creacion'] as String? ?? '';

    final vacante       = p.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloVacante = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';

    Color headerColor = AppColors.textSecondary;
    IconData headerIcon = Icons.pending_outlined;
    String headerLabel = 'Pendiente';

    if (estado == 'match') {
      headerColor = AppColors.accentGreen;
      headerIcon  = Icons.favorite;
      headerLabel = '¡Match!';
    } else if (estado == 'aceptado') {
      headerColor = AppColors.accentBlue;
      headerIcon  = Icons.check_circle;
      headerLabel = 'Aceptado';
    } else if (estado == 'rechazado') {
      headerColor = AppColors.error;
      headerIcon  = Icons.cancel;
      headerLabel = 'Rechazado';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: esMatch ? Border.all(
            color: AppColors.accentGreen.withOpacity(0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: headerColor.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(headerIcon, size: 14, color: headerColor),
            const SizedBox(width: 6),
            Text(headerLabel, style: AppTextStyles.bodySmall.copyWith(
                color: headerColor, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (fechaStr.isNotEmpty)
              Text(_formatFecha(fechaStr), style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(radius: 22,
                backgroundColor: headerColor.withOpacity(0.1),
                child: Text('E$estudianteId',
                    style: TextStyle(color: headerColor,
                        fontWeight: FontWeight.bold, fontSize: 11))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Candidato #$estudianteId',
                  style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold)),
              Text(tituloVacante, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
            ])),
            if (esMatch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.favorite,
                    color: AppColors.accentGreen, size: 18)),
          ]),
        ),
      ]),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────
  Future<void> _aceptar(BuildContext context, CompanyProvider p, {
    required int estudianteId, required int vacanteId, String? nombre,
  }) async {
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    final esMatch = await p.swipeEstudiante(
      empresaId: userId, estudianteId: estudianteId,
      vacanteId: vacanteId, interes: true,
    );
    if (!context.mounted) return;
    if (esMatch) {
      showDialog(context: context, builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: AppColors.purpleGradient,
                  shape: BoxShape.circle),
              child: const Icon(Icons.favorite, color: Colors.white, size: 44)),
          const SizedBox(height: 14),
          Text('¡Es un Match! 🎉', style: AppTextStyles.h3,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('${nombre ?? 'El candidato'} también te eligió. '
              '¡Están conectados!',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
        actions: [SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('¡Excelente!'),
        ))],
      ));
    } else {
      _snack(context, 'Candidato aceptado ✓', AppColors.accentGreen);
    }
  }

  Future<void> _rechazar(BuildContext context, CompanyProvider p, {
    required int estudianteId, required int vacanteId,
  }) async {
    final ok = await showDialog<bool>(context: context, builder: (_) =>
      AlertDialog(
        title: const Text('¿Rechazar candidato?'),
        content: const Text('Esta acción notificará al candidato que no fue seleccionado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    await p.swipeEstudiante(
      empresaId: userId, estudianteId: estudianteId,
      vacanteId: vacanteId, interes: false,
    );
    if (context.mounted) _snack(context, 'Candidato rechazado', AppColors.error);
  }

  void _snack(BuildContext ctx, String msg, Color color) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

  Widget _buildEmpty(String title, String sub, IconData icon) =>
    ListView(children: [
      SizedBox(height: 400, child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 72, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub, style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary), textAlign: TextAlign.center),
        ]),
      ))),
    ]);

  String _formatFecha(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month-1]}, ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ts; }
  }

  String _lModal(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }
}