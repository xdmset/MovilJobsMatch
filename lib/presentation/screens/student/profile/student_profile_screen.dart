// lib/presentation/screens/student/profile/student_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../data/models/auth_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/perfil_provider.dart';
import '../../../widgets/bottom_nav_bar.dart';
import 'widgets/profile_header.dart';
import 'widgets/skills_section.dart';
import 'student_edit_profile_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarPerfil());
  }

  void _cargarPerfil() {
    final auth = context.read<AuthProvider>();
    if (auth.usuario != null) {
      context.read<PerfilProvider>().cargarPerfil(auth.usuario!.id);
    }
  }

  void _onNavBarTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0: context.go(AppRoutes.studentHome); break;
      case 1: context.go(AppRoutes.studentApplications); break;
      case 2: context.go(AppRoutes.studentActivity); break;
      case 3: break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Consumer<PerfilProvider>(
              builder: (context, provider, _) {
                if (provider.cargando) {
                  return const SizedBox(
                    height: 400,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (provider.status == PerfilStatus.error) {
                  return _buildError(provider.error ?? 'Error desconocido');
                }
                final perfil = provider.perfil;
                if (perfil == null) {
                  return _buildError('No se encontró el perfil.');
                }
                return _buildContent(perfil);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavBarTap,
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryPurple,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.purpleGradient),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: () async {
            await context.push(AppRoutes.editProfile);
            // Recargar perfil al volver del editor
            if (mounted) _cargarPerfil();
          },
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'settings',
              child: Row(children: [
                Icon(Icons.settings_outlined),
                SizedBox(width: 12),
                Text('Settings'),
              ]),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(children: [
                Icon(Icons.logout, color: AppColors.error),
                SizedBox(width: 12),
                Text('Logout', style: TextStyle(color: AppColors.error)),
              ]),
            ),
          ],
          onSelected: (value) {
            if (value == 'logout') _handleLogout();
            if (value == 'settings') context.push(AppRoutes.settings);
          },
        ),
      ],
    );
  }

  // ── Contenido principal ───────────────────────────────────────────────────
  Widget _buildContent(PerfilEstudiante perfil) {
    final habilidades = (perfil.habilidades ?? '')
        .split(',')
        .map<String>((s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    return Column(
      children: [
        ProfileHeader(
          name: perfil.nombreCompleto,
          email: context.read<AuthProvider>().usuario?.email ?? '',
          university: perfil.institucionEducativa,
          major: perfil.nivelAcademico,
          fotoUrl: perfil.fotoPerfilUrl,
        ),
        const SizedBox(height: 16),
        _buildInfoRow(perfil),
        const SizedBox(height: 16),
        if (perfil.biografia != null && perfil.biografia!.isNotEmpty) ...[
          _buildBioSection(perfil.biografia!),
          const SizedBox(height: 16),
        ],
        _buildStatsSection(),
        const SizedBox(height: 16),
        if (habilidades.isNotEmpty) ...[
          SkillsSection(skills: habilidades),
          const SizedBox(height: 16),
        ],
        _buildCvSection(perfil.cvUrl),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Fila de info (ubicación + modalidad) ──────────────────────────────────
  Widget _buildInfoRow(perfil) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (perfil.ubicacion != null && perfil.ubicacion!.isNotEmpty)
            Expanded(
              child: _buildChip(
                Icons.location_on_outlined,
                perfil.ubicacion!,
                AppColors.accentBlue,
              ),
            ),
          if (perfil.ubicacion != null && perfil.modalidadPreferida != null)
            const SizedBox(width: 12),
          if (perfil.modalidadPreferida != null)
            Expanded(
              child: _buildChip(
                Icons.work_outline,
                _labelModalidad(perfil.modalidadPreferida!),
                AppColors.accentGreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _labelModalidad(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }

  // ── Bio ───────────────────────────────────────────────────────────────────
  Widget _buildBioSection(String bio) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sobre mí', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          Text(
            bio,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats (mock por ahora — conectar cuando haya endpoints) ───────────────
  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(Icons.work_outline, '–', 'Postulaciones', AppColors.accentBlue)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(Icons.favorite_outline, '–', 'Matches', AppColors.accentGreen)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(Icons.visibility_outlined, '–', 'Vistas', AppColors.primaryPurple)),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.h3.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── CV — solo visualización, la edición va en edit profile ──────────────
  Widget _buildCvSection(String? cvUrl) {
    final tieneCv = cvUrl != null && cvUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tieneCv ? Icons.description_outlined : Icons.description_outlined,
              size: 32, color: AppColors.primaryPurple,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Currículum', style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  tieneCv ? 'CV disponible para empresas' : 'Sin CV — agrégalo en Editar perfil',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: tieneCv ? AppColors.accentGreen : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (tieneCv)
            Icon(Icons.check_circle, color: AppColors.accentGreen, size: 24),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  Widget _buildError(String msg) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(msg, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _cargarPerfil,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
              context.go(AppRoutes.welcome);
            },
            child: const Text('Salir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
}