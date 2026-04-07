// lib/presentation/screens/company/profile/company_profile_screen.dart

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

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de empresa'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.companyEditProfile)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') context.push(AppRoutes.companySettings);
              if (v == 'theme')    _showThemeDialog();
              if (v == 'logout')   _handleLogout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings',
                  child: Row(children: [Icon(Icons.settings_outlined), SizedBox(width: 12), Text('Configuración')])),
              const PopupMenuItem(value: 'theme',
                  child: Row(children: [Icon(Icons.dark_mode_outlined), SizedBox(width: 12), Text('Tema')])),
              const PopupMenuItem(value: 'logout',
                  child: Row(children: [Icon(Icons.logout, color: AppColors.error), SizedBox(width: 12),
                    Text('Cerrar sesión', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
      body: Consumer<CompanyProvider>(builder: (_, company, __) {
        final perfil = company.perfil;
        if (perfil == null && company.cargando) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _buildHeader(perfil),
            const SizedBox(height: 24),
            if (company.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(company.error!,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
              ),
            _buildInfo(perfil),
            const SizedBox(height: 24),
            _buildStats(company),
          ]),
        );
      }),
    );
  }

  Widget _buildHeader(perfil) {
    final nombre = perfil?.nombreComercial ?? 'Mi empresa';
    final initials = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white.withOpacity(0.2),
          child: Text(initials, style: AppTextStyles.h2.copyWith(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Text(nombre, style: AppTextStyles.h3.copyWith(color: Colors.white),
            textAlign: TextAlign.center),
        if (perfil?.sector != null) ...[
          const SizedBox(height: 4),
          Text(perfil!.sector!, style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.85))),
        ],
        if (perfil?.ubicacionSede != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(perfil!.ubicacionSede!, style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white70)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildInfo(perfil) {
    if (perfil == null) return const SizedBox.shrink();
    return Column(children: [
      if (perfil.descripcion != null && perfil.descripcion!.isNotEmpty)
        _infoCard('Descripción', Icons.description_outlined, perfil.descripcion!),
      if (perfil.sitioWeb != null && perfil.sitioWeb!.isNotEmpty)
        _infoCard('Sitio web', Icons.language_outlined, perfil.sitioWeb!),
      if (perfil.sector != null && perfil.sector!.isNotEmpty)
        _infoCard('Sector', Icons.category_outlined, perfil.sector!),
      if (perfil.ubicacionSede != null && perfil.ubicacionSede!.isNotEmpty)
        _infoCard('Sede', Icons.location_on_outlined, perfil.ubicacionSede!),
    ]);
  }

  Widget _infoCard(String label, IconData icon, String value) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))],
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primaryPurple, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyMedium),
      ])),
    ]),
  );

  Widget _buildStats(CompanyProvider company) => Row(children: [
    Expanded(child: _statCard(Icons.work_outline,
        company.vacantes.length.toString(), 'Vacantes', AppColors.accentBlue)),
    const SizedBox(width: 12),
    Expanded(child: _statCard(Icons.people_outline,
        company.postulaciones.length.toString(), 'Postulaciones', AppColors.accentGreen)),
    const SizedBox(width: 12),
    Expanded(child: _statCard(Icons.check_circle_outline,
        company.postulaciones.where((p) =>
            (p['estado'] as String? ?? '') == 'aceptado').length.toString(),
        'Aceptados', AppColors.primaryPurple)),
  ]);

  Widget _statCard(IconData icon, String value, String label, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))],
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      Text(value, style: AppTextStyles.h3.copyWith(color: color)),
      const SizedBox(height: 4),
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center),
    ]),
  );

  void _showThemeDialog() {
    final theme = context.read<ThemeProvider>();
    final settings = context.read<SettingsProvider>();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tema'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _themeOpt('Sistema', ThemeMode.system, Icons.brightness_auto_outlined, theme, settings),
        _themeOpt('Claro',   ThemeMode.light,  Icons.light_mode_outlined,      theme, settings),
        _themeOpt('Oscuro',  ThemeMode.dark,   Icons.dark_mode_outlined,       theme, settings),
      ]),
    ));
  }

  Widget _themeOpt(String label, ThemeMode mode, IconData icon, ThemeProvider tp, SettingsProvider sp) {
    final sel = tp.themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: sel ? AppColors.primaryPurple : AppColors.textSecondary),
      title: Text(label),
      trailing: sel ? const Icon(Icons.check, color: AppColors.primaryPurple) : null,
      onTap: () { tp.setTheme(label); sp.setTheme(label); Navigator.pop(context); },
    );
  }

  void _handleLogout() => showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Cerrar sesión'),
    content: const Text('¿Seguro que quieres salir?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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