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
        automaticallyImplyLeading: false,
        title: const Text('Perfil de empresa'),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar perfil',
              onPressed: () => context.push(AppRoutes.companyEditProfile)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') context.push(AppRoutes.companySettings);
              if (v == 'theme')    _showThemeDialog();
              if (v == 'logout')   _handleLogout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings',
                  child: Row(children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 12),
                    Text('Configuración')])),
              const PopupMenuItem(value: 'theme',
                  child: Row(children: [
                    Icon(Icons.dark_mode_outlined),
                    SizedBox(width: 12),
                    Text('Tema')])),
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
      body: Consumer<CompanyProvider>(builder: (_, company, __) {
        final perfil = company.perfil;
        if (perfil == null && company.cargando) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async {
            final id = context.read<AuthProvider>().usuario?.id;
            if (id != null) await company.cargarDashboard(id);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildHeader(perfil),
              const SizedBox(height: 20),
              if (company.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(company.error!,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error))),
                  ]),
                ),
              _buildInfo(perfil),
              const SizedBox(height: 20),
              _buildStats(company),
              const SizedBox(height: 20),
              // Botón editar perfil
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.companyEditProfile),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar perfil'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildHeader(perfil) {
    final nombre   = perfil?.nombreComercial ?? 'Mi empresa';
    final sector   = perfil?.sector as String?;
    final sede     = perfil?.ubicacionSede as String?;
    // Intentar ambos nombres por compatibilidad con versiones del modelo
    // final fotoUrl = (perfil?.fotoPerfilUrl as String? )
    //     ?? (perfil?.fotoPerfigUrl as String?);
    final fotoUrl = perfil?.fotoPerfilUrl;
    final initials = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.purpleGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [

        // Foto de perfil real o avatar con iniciales
        Stack(children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: Colors.white.withOpacity(0.2),
            ),
            child: fotoUrl != null && fotoUrl.isNotEmpty
                ? ClipOval(child: Image.network(
                    fotoUrl,
                    width: 88, height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(initials,
                          style: AppTextStyles.h2.copyWith(
                              color: Colors.white))),
                  ))
                : Center(child: Text(initials,
                    style: AppTextStyles.h2.copyWith(color: Colors.white))),
          ),
          // Botón de editar foto
          Positioned(bottom: 0, right: 0,
            child: GestureDetector(
              onTap: () => context.push(AppRoutes.companyEditProfile),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt,
                    size: 16, color: AppColors.primaryPurple),
              ),
            )),
        ]),
        const SizedBox(height: 14),

        Text(nombre,
            style: AppTextStyles.h3.copyWith(color: Colors.white),
            textAlign: TextAlign.center),

        if (sector != null && sector.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(sector,
                style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],

        if (sede != null && sede.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on_outlined,
                color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(sede, style: AppTextStyles.bodySmall.copyWith(
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
        _infoCard('Sitio web', Icons.language_outlined, perfil.sitioWeb!,
            isLink: true),
      if (perfil.sector != null && perfil.sector!.isNotEmpty)
        _infoCard('Sector', Icons.category_outlined, perfil.sector!),
      if (perfil.ubicacionSede != null && perfil.ubicacionSede!.isNotEmpty)
        _infoCard('Sede', Icons.location_on_outlined, perfil.ubicacionSede!),
    ]);
  }

  Widget _infoCard(String label, IconData icon, String value,
      {bool isLink = false}) =>
    Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primaryPurple, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(
              color: isLink ? AppColors.accentBlue : null,
              decoration: isLink ? TextDecoration.underline : null)),
        ])),
      ]),
    );

  Widget _buildStats(CompanyProvider company) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Estadísticas', style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _statCard(
            Icons.work_outline,
            company.vacantes.length.toString(),
            'Vacantes', AppColors.accentBlue)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(
            Icons.people_outline,
            company.candidatosFeed.length.toString(),
            'Pendientes', Colors.orange)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(
            Icons.favorite_outline,
            company.matches.toString(),
            'Matches', AppColors.accentGreen)),
      ]),
    ]),
  );

  Widget _statCard(IconData icon, String value, String label, Color color) =>
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.h3.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );

  // ── Menú ──────────────────────────────────────────────────────────────────
  void _showThemeDialog() {
    final theme    = context.read<ThemeProvider>();
    final settings = context.read<SettingsProvider>();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tema'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _themeOpt('Sistema', ThemeMode.system,
            Icons.brightness_auto_outlined, theme, settings),
        _themeOpt('Claro',   ThemeMode.light,
            Icons.light_mode_outlined,      theme, settings),
        _themeOpt('Oscuro',  ThemeMode.dark,
            Icons.dark_mode_outlined,       theme, settings),
      ]),
    ));
  }

  Widget _themeOpt(String label, ThemeMode mode, IconData icon,
      ThemeProvider tp, SettingsProvider sp) {
    final sel = tp.themeMode == mode;
    return ListTile(
      leading: Icon(icon,
          color: sel ? AppColors.primaryPurple : AppColors.textSecondary),
      title: Text(label),
      trailing: sel ? const Icon(Icons.check,
          color: AppColors.primaryPurple) : null,
      onTap: () {
        tp.setTheme(label); sp.setTheme(label); Navigator.pop(context);
      },
    );
  }

  void _handleLogout() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres cerrar sesión?'),
      actions: [
        // FIX: Cancelar primero, con estilo propio igual que Salir
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primaryPurple),
              foregroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              context.read<CompanyProvider>().limpiar();
              context.read<AuthProvider>().logout();
              Navigator.pop(context);
              context.go(AppRoutes.welcome);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Salir'),
          ),
        ),
      ],
    ),
  );
}