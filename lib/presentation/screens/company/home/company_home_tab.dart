// lib/presentation/screens/company/home/company_home_screen.dart
//
// NOTA: La clase se llama CompanyHomeTab (no Screen) porque ya no
// es una ruta independiente — vive dentro del CompanyShellScreen.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/theme_provider.dart';

class CompanyHomeTab extends StatelessWidget {
  const CompanyHomeTab({super.key});

  Future<void> _cargar(BuildContext context) async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) await context.read<CompanyProvider>().cargarDashboard(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<CompanyProvider>(
        builder: (_, company, __) {
          if (company.cargando && company.perfil == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => _cargar(context),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildWelcomeCard(context, company),
                const SizedBox(height: 24),
                _buildStatsGrid(context, company),
                const SizedBox(height: 24),
                if (company.postulaciones.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Postulaciones recientes',
                      onViewAll: () => context.push(AppRoutes.companyCandidates)),
                  const SizedBox(height: 12),
                  ...company.postulaciones.take(3).map(_buildPostulacionCard),
                  const SizedBox(height: 24),
                ],
                _buildSectionHeader(context, 'Vacantes activas',
                    onViewAll: () => context.push(AppRoutes.companyVacancies)),
                const SizedBox(height: 12),
                _buildVacantesSection(context, company),
                const SizedBox(height: 80), // espacio para el FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.companyCreateVacancy),
        icon: const Icon(Icons.add),
        label: const Text('Publicar vacante'),
        backgroundColor: AppColors.primaryPurple,
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Consumer<CompanyProvider>(
        builder: (_, company, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(company.perfil?.nombreComercial ?? 'Mi empresa',
                style: AppTextStyles.h4),
            Text('Panel de reclutamiento',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary)),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _cargar(context),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) => _handleMenu(context, v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings_outlined), SizedBox(width: 12),
                  Text('Configuración'),
                ])),
            const PopupMenuItem(value: 'theme',
                child: Row(children: [
                  Icon(Icons.dark_mode_outlined), SizedBox(width: 12),
                  Text('Tema'),
                ])),
            const PopupMenuItem(value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, color: AppColors.error), SizedBox(width: 12),
                  Text('Cerrar sesión', style: TextStyle(color: AppColors.error)),
                ])),
          ],
        ),
      ],
    );
  }

  void _handleMenu(BuildContext context, String value) {
    switch (value) {
      case 'settings': context.push(AppRoutes.companySettings); break;
      case 'theme':    _showThemeDialog(context); break;
      case 'logout':   _handleLogout(context); break;
    }
  }

  // ── Welcome card ──────────────────────────────────────────────────────────
  Widget _buildWelcomeCard(BuildContext context, CompanyProvider company) {
    final nuevas = company.postulaciones
        .where((p) => (p['estado'] as String? ?? '') == 'pendiente')
        .length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: AppColors.primaryPurple.withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 10),
        )],
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¡Bienvenido! 👋',
                style: AppTextStyles.h3.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              nuevas > 0
                  ? 'Tienes $nuevas postulaciones pendientes'
                  : 'No hay postulaciones nuevas',
              style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.9)),
            ),
          ],
        )),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.business_center, color: Colors.white, size: 32),
        ),
      ]),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(BuildContext context, CompanyProvider company) {
    return Row(children: [
      Expanded(child: _statCard(context, Icons.work_outline,
          company.vacantes.length.toString(), 'Vacantes', AppColors.accentBlue)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(context, Icons.people_outline,
          company.postulaciones.length.toString(), 'Postulaciones', AppColors.accentGreen)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(context, Icons.pending_outlined,
          company.postulaciones
              .where((p) => (p['estado'] as String? ?? '') == 'pendiente')
              .length.toString(),
          'Pendientes', AppColors.primaryPurple)),
    ]);
  }

  Widget _statCard(BuildContext context, IconData icon, String value,
      String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 2),
        )],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 12),
        Text(value, style: AppTextStyles.h3.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Postulaciones ─────────────────────────────────────────────────────────
  Widget _buildPostulacionCard(Map<String, dynamic> p) {
    final estado  = p['estado'] as String? ?? 'pendiente';
    final nombre  = p['estudiante_nombre'] as String? ?? 'Candidato';
    final vacante = p['vacante_titulo'] as String? ?? 'Vacante';

    Color color;
    switch (estado) {
      case 'aceptado':  color = AppColors.accentGreen; break;
      case 'rechazado': color = AppColors.error; break;
      default:          color = AppColors.accentBlue;
    }

    return Builder(builder: (context) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: AppColors.primaryPurple.withOpacity(0.15),
          child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(nombre,
              style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(vacante,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(estado, style: AppTextStyles.bodySmall.copyWith(
              color: color, fontWeight: FontWeight.bold)),
        ),
      ]),
    ));
  }

  // ── Vacantes ──────────────────────────────────────────────────────────────
  Widget _buildVacantesSection(BuildContext context, CompanyProvider company) {
    if (company.vacantes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(Icons.work_off_outlined, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('Sin vacantes activas',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.companyCreateVacancy),
            icon: const Icon(Icons.add),
            label: const Text('Publicar primera vacante'),
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        children: company.vacantes.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          final id = v['id'];
          return Column(children: [
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_outline, color: AppColors.accentBlue),
              ),
              title: Text(v['titulo'] as String? ?? 'Vacante',
                  style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${v['modalidad'] ?? ''} · ${v['ubicacion'] ?? ''}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary),
              ),
              trailing: id != null
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.primaryPurple),
                      onPressed: () =>
                          context.push(AppRoutes.editVacancyPath(id as int)),
                    )
                  : null,
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title,
      {VoidCallback? onViewAll}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: AppTextStyles.h4),
      if (onViewAll != null)
        TextButton(onPressed: onViewAll, child: const Text('Ver todo')),
    ]);
  }

  // ── Tema ──────────────────────────────────────────────────────────────────
  void _showThemeDialog(BuildContext context) {
    final theme    = context.read<ThemeProvider>();
    final settings = context.read<SettingsProvider>();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tema'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _themeOpt(context, 'Sistema', ThemeMode.system,
            Icons.brightness_auto_outlined, theme, settings),
        _themeOpt(context, 'Claro', ThemeMode.light,
            Icons.light_mode_outlined, theme, settings),
        _themeOpt(context, 'Oscuro', ThemeMode.dark,
            Icons.dark_mode_outlined, theme, settings),
      ]),
    ));
  }

  Widget _themeOpt(BuildContext context, String label, ThemeMode mode,
      IconData icon, ThemeProvider tp, SettingsProvider sp) {
    final sel = tp.themeMode == mode;
    return ListTile(
      leading: Icon(icon,
          color: sel ? AppColors.primaryPurple : AppColors.textSecondary),
      title: Text(label),
      trailing: sel
          ? const Icon(Icons.check, color: AppColors.primaryPurple) : null,
      onTap: () {
        tp.setTheme(label);
        sp.setTheme(label);
        Navigator.pop(context);
      },
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void _handleLogout(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres salir?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
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
    ));
  }
}