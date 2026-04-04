// lib/presentation/screens/student/profile/student_profile_screen.dart
// Agrega url_launcher: ^6.2.0 en pubspec.yaml

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../data/models/auth_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/perfil_provider.dart';
import '../../../providers/student_provider.dart';
import 'widgets/profile_header.dart';
import 'widgets/skills_section.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarPerfil());
  }

  void _cargarPerfil() {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) context.read<PerfilProvider>().cargarPerfil(id);
  }

  // ── Abrir CV ──────────────────────────────────────────────────────────────
  Future<void> _abrirCv(String? cvUrl) async {
    if (cvUrl == null || cvUrl.isEmpty) return;
    try {
      final uri = Uri.parse(cvUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se puede abrir el CV. Intenta más tarde.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al abrir el CV: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Consumer<PerfilProvider>(
              builder: (context, provider, _) {
                if (provider.cargando) {
                  return const SizedBox(height: 400,
                      child: Center(child: CircularProgressIndicator()));
                }
                if (provider.status == PerfilStatus.error) {
                  return _buildError(provider.error ?? 'Error desconocido');
                }
                final perfil = provider.perfil;
                if (perfil == null) return _buildError('No se encontró el perfil.');
                return _buildContent(context, perfil);
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) => SliverAppBar(
    expandedHeight: 200,
    floating: false, pinned: true,
    automaticallyImplyLeading: false,
    backgroundColor: AppColors.primaryPurple,
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
          decoration: const BoxDecoration(gradient: AppColors.purpleGradient)),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.edit, color: Colors.white),
        onPressed: () async {
          await context.push(AppRoutes.editProfile);
          if (mounted) _cargarPerfil();
        },
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (v) {
          if (v == 'settings') context.push(AppRoutes.settings);
          if (v == 'logout')   _handleLogout(context);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'settings',
              child: Row(children: [Icon(Icons.settings_outlined),
                SizedBox(width: 12), Text('Configuración')])),
          PopupMenuItem(value: 'logout',
              child: Row(children: [Icon(Icons.logout, color: AppColors.error),
                SizedBox(width: 12),
                Text('Cerrar sesión', style: TextStyle(color: AppColors.error))])),
        ],
      ),
    ],
  );

  Widget _buildContent(BuildContext context, PerfilEstudiante perfil) {
    final cardColor     = Theme.of(context).cardColor;
    final matchCount    = context.read<StudentProvider>().matches.length;
    final swipeCount    = context.read<StudentProvider>().historial.length;
    final likeCount     = context.read<StudentProvider>().historial
        .where((h) => h['tipo'] == 'like').length;

    final habilidades = (perfil.habilidades ?? '')
        .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return Column(children: [
      ProfileHeader(
        name:       perfil.nombreCompleto,
        email:      context.read<AuthProvider>().usuario?.email ?? '',
        university: perfil.institucionEducativa,
        major:      perfil.nivelAcademico,
        fotoUrl:    perfil.fotoPerfilUrl,
      ),
      const SizedBox(height: 16),

      // Edad si existe
      if (perfil.edad != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _chip(Icons.cake_outlined,
              '${perfil.edad} años', AppColors.accentBlue),
        ),
        const SizedBox(height: 12),
      ],

      _buildInfoRow(context, perfil),
      const SizedBox(height: 16),

      // Bio
      if (perfil.biografia != null && perfil.biografia!.isNotEmpty) ...[
        _buildCard(cardColor, Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sobre mí', style: AppTextStyles.h4),
            const SizedBox(height: 12),
            Text(perfil.biografia!, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
          ],
        )),
        const SizedBox(height: 16),
      ],

      // Stats
      _buildStats(cardColor, matchCount, likeCount, swipeCount),
      const SizedBox(height: 16),

      // Habilidades
      if (habilidades.isNotEmpty) ...[
        SkillsSection(skills: habilidades),
        const SizedBox(height: 16),
      ],

      // CV — con botón para abrirlo
      _buildCvSection(context, cardColor, perfil.cvUrl),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildInfoRow(BuildContext context, PerfilEstudiante perfil) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (perfil.ubicacion != null && perfil.ubicacion!.isNotEmpty)
          Expanded(child: _chip(Icons.location_on_outlined,
              perfil.ubicacion!, AppColors.accentBlue)),
        if (perfil.ubicacion != null && perfil.modalidadPreferida != null)
          const SizedBox(width: 12),
        if (perfil.modalidadPreferida != null)
          Expanded(child: _chip(Icons.work_outline,
              _lModal(perfil.modalidadPreferida!), AppColors.accentGreen)),
      ]),
    );

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color), const SizedBox(width: 6),
      Flexible(child: Text(label, style: AppTextStyles.bodySmall.copyWith(
          color: color, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _buildStats(Color cardColor, int matches, int likes, int swipes) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: _statCard(cardColor, Icons.favorite_outline,
            matches.toString(), 'Matches', AppColors.accentGreen)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(cardColor, Icons.thumb_up_outlined,
            likes.toString(), 'Likes', AppColors.primaryPurple)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(cardColor, Icons.history_outlined,
            swipes.toString(), 'Vistas', AppColors.accentBlue)),
      ]),
    );

  Widget _statCard(Color cardColor, IconData icon, String value,
      String label, Color color) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(height: 10),
        Text(value, style: AppTextStyles.h3.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]),
    );

  // ── CV con botón de apertura ──────────────────────────────────────────────
  Widget _buildCvSection(BuildContext context, Color cardColor, String? cvUrl) {
    final tieneCv = cvUrl != null && cvUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 2)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.description_outlined,
              size: 32, color: AppColors.primaryPurple)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Currículum',
              style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            tieneCv ? 'CV disponible para empresas' : 'Sin CV',
            style: AppTextStyles.bodySmall.copyWith(
                color: tieneCv ? AppColors.accentGreen : AppColors.textSecondary),
          ),
        ])),
        const SizedBox(width: 8),
        if (tieneCv)
          // Botón para abrir el PDF
          ElevatedButton.icon(
            onPressed: () => _abrirCv(cvUrl),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ver CV'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          )
        else
          TextButton(
            onPressed: () async {
              await context.push(AppRoutes.editProfile);
              if (mounted) _cargarPerfil();
            },
            child: const Text('Agregar'),
          ),
      ]),
    );
  }

  Widget _buildCard(Color cardColor, Widget child) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))]),
    child: child,
  );

  Widget _buildError(String msg) => SizedBox(height: 400,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
      const Icon(Icons.error_outline, size: 60, color: AppColors.error),
      const SizedBox(height: 16),
      Text(msg, style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _cargarPerfil, child: const Text('Reintentar')),
    ])));

  void _handleLogout(BuildContext context) =>
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres cerrar sesión?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            context.read<StudentProvider>().limpiar();
            context.read<AuthProvider>().logout();
            Navigator.pop(context);
            context.go(AppRoutes.welcome);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Salir'),
        ),
      ],
    ));

  String _lModal(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }
}