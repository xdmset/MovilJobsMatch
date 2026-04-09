// lib/presentation/screens/company/home/company_home_tab.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/settings_provider.dart';

class CompanyHomeTab extends StatelessWidget {
  const CompanyHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final comp = context.watch<CompanyProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hola, ${comp.perfil?.nombreComercial ?? 'Empresa'}',
              style: AppTextStyles.h4),
          Text('Panel de reclutamiento',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _handleMenu(context, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings',
                  child: Row(children: [Icon(Icons.settings_outlined),
                    SizedBox(width: 12), Text('Configuración')])),
              const PopupMenuItem(value: 'theme',
                  child: Row(children: [Icon(Icons.dark_mode_outlined),
                    SizedBox(width: 12), Text('Tema')])),
              const PopupMenuItem(value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Cerrar sesión',
                        style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final id = context.read<AuthProvider>().usuario?.id;
          if (id != null) await context.read<CompanyProvider>().cargarDashboard(id);
        },
        child: comp.cargando && comp.perfil == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [

                  // ── Resumen de métricas ──────────────────────────────
                  _buildMetrics(context, comp),
                  const SizedBox(height: 20),

                  // ── Acciones rápidas ─────────────────────────────────
                  _buildAccionesRapidas(context),
                  const SizedBox(height: 20),

                  // ── Candidatos recientes ─────────────────────────────
                  _buildSeccionCandidatos(context, comp),
                  const SizedBox(height: 20),

                  // ── Vacantes recientes ───────────────────────────────
                  _buildSeccionVacantes(context, comp),
                  const SizedBox(height: 24),
                ]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.companyCreateVacancy),
        icon: const Icon(Icons.add),
        label: const Text('Nueva vacante'),
        backgroundColor: AppColors.accentBlue,
      ),
    );
  }

  // ── Métricas ──────────────────────────────────────────────────────────────
  // FIX: usar los getters del provider en lugar de recalcular manualmente.
  // pendientes = candidatosFeed.length (swipes de estudiantes sin respuesta)
  // totalCandidatos = postulaciones + candidatosFeed
  Widget _buildMetrics(BuildContext context, CompanyProvider comp) {
    final vacantes         = comp.vacantes.length;
    final totalCandidatos  = comp.totalCandidatos;  // postulaciones + feed
    final pendientes       = comp.pendientes;        // candidatosFeed.length
    final matches          = comp.matches;           // postulaciones con estado 'match'

    debugPrint('[CompanyHomeTab] Métricas: '
        'vacantes=$vacantes, total_candidatos=$totalCandidatos, '
        'pendientes=$pendientes, matches=$matches');

    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _metricCard(context, Icons.work_outline, vacantes.toString(),
            'Vacantes activas', AppColors.accentBlue),
        _metricCard(context, Icons.people_outline, totalCandidatos.toString(),
            'Total candidatos', AppColors.primaryPurple),
        _metricCard(context, Icons.pending_outlined, pendientes.toString(),
            'Pendientes de revisar', Colors.orange),
        _metricCard(context, Icons.favorite_outline, matches.toString(),
            'Matches', AppColors.accentGreen),
      ],
    );
  }

  Widget _metricCard(BuildContext context, IconData icon, String value,
      String label, Color color) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(value, style: AppTextStyles.h3.copyWith(color: color)),
          Text(label, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary), maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );

  // ── Acciones rápidas ──────────────────────────────────────────────────────
  Widget _buildAccionesRapidas(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Acciones rápidas', style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _accionBtn(context, Icons.add_circle_outline,
            'Publicar vacante', AppColors.accentBlue,
            () => context.push(AppRoutes.companyCreateVacancy))),
        const SizedBox(width: 10),
        Expanded(child: _accionBtn(context, Icons.edit_outlined,
            'Editar perfil', AppColors.primaryPurple,
            () => context.push(AppRoutes.companyEditProfile))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _accionBtn(context, Icons.workspace_premium,
            'Ver Business', AppColors.accentGreen,
            () => context.push(AppRoutes.companyPremium))),
        const SizedBox(width: 10),
        Expanded(child: _accionBtn(context, Icons.settings_outlined,
            'Configuración', AppColors.textSecondary,
            () => context.push(AppRoutes.companySettings))),
      ]),
    ]),
  );

  Widget _accionBtn(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall.copyWith(
              color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );

  // ── Candidatos recientes ──────────────────────────────────────────────────
  // FIX: mostrar candidatosFeed (swipes pendientes) en lugar de postulaciones
  Widget _buildSeccionCandidatos(BuildContext context, CompanyProvider comp) {
    // Mostrar los 3 candidatos más recientes del feed de swipes pendientes
    final recientes = comp.candidatosFeed.take(3).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Candidatos recientes', style: AppTextStyles.h4),
        const Spacer(),
        if (comp.pendientes > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${comp.pendientes} por revisar',
                style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.orange, fontWeight: FontWeight.w600)),
          ),
      ]),
      const SizedBox(height: 12),
      if (recientes.isEmpty)
        _emptyCard(context,
            'Aún no hay candidatos\nCuando los estudiantes den like a tus vacantes aparecerán aquí',
            Icons.people_outline)
      else
        ...recientes.map((c) => _candidatoMini(context, c, comp)),
    ]);
  }

  Widget _candidatoMini(BuildContext context,
      Map<String, dynamic> candidato, CompanyProvider comp) {
    final estudianteId = candidato['estudiante_id'] as int?
        ?? candidato['usuario_id'] as int? ?? 0;
    final vacanteId    = candidato['vacante_id'] as int? ?? 0;
    final nombre       = candidato['nombre_completo'] as String?;
    final nivel        = candidato['nivel_academico'] as String? ?? '';
    final fechaStr     = candidato['fecha_like'] as String? ?? '';

    final vacante   = comp.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloV   = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';

    final inicial = nombre != null && nombre.isNotEmpty
        ? nombre[0].toUpperCase() : 'E';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
          child: Text(inicial, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(nombre ?? 'Candidato #$estudianteId',
              style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600)),
          Text(tituloV, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary)),
          if (nivel.isNotEmpty)
            Text(nivel, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary, fontSize: 10)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Pendiente',
                style: TextStyle(fontSize: 10, color: Colors.orange,
                    fontWeight: FontWeight.w600)),
          ),
          if (fechaStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(_formatFecha(fechaStr), style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary, fontSize: 10)),
          ],
        ]),
      ]),
    );
  }

  // ── Vacantes recientes ────────────────────────────────────────────────────
  Widget _buildSeccionVacantes(BuildContext context, CompanyProvider comp) {
    final vacantes = comp.vacantes.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mis vacantes', style: AppTextStyles.h4),
      const SizedBox(height: 12),
      if (vacantes.isEmpty)
        _emptyCard(context,
            'Aún no has publicado vacantes\nPresiona el botón + para crear tu primera vacante',
            Icons.work_outline)
      else
        ...vacantes.map((v) => _vacanteMini(context, v)),
    ]);
  }

  Widget _vacanteMini(BuildContext context, Map<String, dynamic> v) {
    final titulo    = v['titulo']    as String? ?? 'Vacante';
    final estado    = v['estado']    as String? ?? 'activo';
    final modalidad = v['modalidad'] as String? ?? '';

    // Mostrar likes reales del historial si están disponibles
    final likesEstudiantes = v['total_likes_estudiantes'] as int?;

    Color estadoColor = AppColors.accentGreen;
    if (estado == 'inactivo' || estado == 'cerrada') estadoColor = AppColors.error;
    if (estado == 'pausada')  estadoColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.work_outline,
                color: AppColors.accentBlue, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(titulo, style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600)),
          Row(children: [
            if (modalidad.isNotEmpty) Text(_lModal(modalidad),
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary)),
            if (likesEstudiantes != null && likesEstudiantes > 0) ...[
              const SizedBox(width: 8),
              Icon(Icons.thumb_up, size: 11, color: AppColors.primaryPurple),
              const SizedBox(width: 2),
              Text('$likesEstudiantes',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryPurple, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ]),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: estadoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text(_lEstado(estado), style: TextStyle(
              fontSize: 11, color: estadoColor, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _emptyCard(BuildContext context, String msg, IconData icon) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(children: [
        Icon(icon, size: 40, color: AppColors.textTertiary),
        const SizedBox(height: 10),
        Text(msg, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]),
    );

  // ── Menú ──────────────────────────────────────────────────────────────────
  void _handleMenu(BuildContext context, String v) {
    switch (v) {
      case 'settings': context.push(AppRoutes.companySettings); break;
      case 'theme':    _showTheme(context); break;
      case 'logout':   _logout(context); break;
    }
  }

  void _showTheme(BuildContext context) {
    final tp = context.read<ThemeProvider>();
    final sp = context.read<SettingsProvider>();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tema'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _tOpt(context, 'Claro',  ThemeMode.light,  Icons.light_mode_outlined,  tp, sp),
        _tOpt(context, 'Oscuro', ThemeMode.dark,   Icons.dark_mode_outlined,   tp, sp),
        _tOpt(context, 'Sistema',ThemeMode.system, Icons.brightness_auto_outlined, tp, sp),
      ]),
    ));
  }

  Widget _tOpt(BuildContext context, String label, ThemeMode mode,
      IconData icon, ThemeProvider tp, SettingsProvider sp) {
    final sel = tp.themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: sel ? AppColors.accentBlue : AppColors.textSecondary),
      title: Text(label),
      trailing: sel ? const Icon(Icons.check, color: AppColors.accentBlue) : null,
      onTap: () { tp.setTheme(label); sp.setTheme(label); Navigator.pop(context); },
    );
  }

  void _logout(BuildContext context) => showDialog(
    context: context, builder: (_) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres salir?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            context.read<CompanyProvider>().limpiar();
            context.read<AuthProvider>().logout();
            Navigator.pop(context);
            context.go(AppRoutes.welcome);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Salir'),
        ),
      ],
    ),
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
      case 'remoto': return 'Remoto'; case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido'; default: return m;
    }
  }

  String _lEstado(String e) {
    switch (e) {
      case 'activa':    return 'Activa';
      case 'activo':    return 'Activa';
      case 'inactivo':  return 'Inactiva';
      case 'pausada':   return 'Pausada';
      case 'cerrada':   return 'Cerrada';
      default: return e;
    }
  }
}