// lib/presentation/screens/student/profile/student_profile_screen.dart

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

  Future<void> _abrirCv(String? cvUrl) async {
    if (cvUrl == null || cvUrl.isEmpty) return;
    try {
      final uri = Uri.parse(cvUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) _snack('No se puede abrir el CV', isError: true);
      }
    } catch (_) {
      if (mounted) _snack('Error al abrir el CV', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar perfil',
            onPressed: () async {
              await context.push(AppRoutes.editProfile);
              if (mounted) _cargarPerfil();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'settings') context.push(AppRoutes.studentSettings);
              if (v == 'logout')   _handleLogout(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings',
                  child: Row(children: [Icon(Icons.settings_outlined),
                    SizedBox(width: 12), Text('Configuración')])),
              PopupMenuItem(value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Cerrar sesión',
                        style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
      body: Consumer<PerfilProvider>(
        builder: (context, prov, _) {
          if (prov.cargando) return const Center(child: CircularProgressIndicator());
          if (prov.status == PerfilStatus.error) {
            return _buildError(prov.error ?? 'Error desconocido');
          }
          final perfil = prov.perfil;
          if (perfil == null) return _buildError('No se encontró el perfil.');
          return _buildContent(context, perfil);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, PerfilEstudiante perfil) {
    final card    = Theme.of(context).cardColor;
    final sp      = context.read<StudentProvider>();
    final matches = sp.matches.length;
    final likes   = sp.historial.where((h) => h['tipo'] == 'like').length;
    final swipes  = sp.historial.length;

    final skills  = (perfil.habilidades ?? '')
        .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return RefreshIndicator(
      onRefresh: () async => _cargarPerfil(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ─────────────────────────────────────────────────────
          ProfileHeader(
            name:       perfil.nombreCompleto,
            email:      context.read<AuthProvider>().usuario?.email ?? '',
            university: perfil.institucionEducativa,
            major:      perfil.nivelAcademico,
            fotoUrl:    perfil.fotoPerfilUrl,
          ),
          const SizedBox(height: 16),

          // ── Info personal — con etiquetas descriptivas ────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildInfoCard(card, perfil),
          ),
          const SizedBox(height: 12),

          // ── Estadísticas ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _statCard(card, Icons.favorite,
                  matches.toString(), 'Matches', AppColors.accentGreen)),
              const SizedBox(width: 10),
              Expanded(child: _statCard(card, Icons.thumb_up_outlined,
                  likes.toString(), 'Me gustó', AppColors.primaryPurple)),
              const SizedBox(width: 10),
              Expanded(child: _statCard(card, Icons.history_outlined,
                  swipes.toString(), 'Revisadas', AppColors.accentBlue)),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Sobre mí ──────────────────────────────────────────────────
          if (perfil.biografia != null && perfil.biografia!.isNotEmpty) ...[
            _buildSection(card, 'Acerca de mí', Icons.person_outline,
              Text(perfil.biografia!,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6))),
            const SizedBox(height: 12),
          ],

          // ── Habilidades / Top skills ───────────────────────────────────
          if (skills.isNotEmpty) ...[
            _buildSection(card, 'Habilidades destacadas', Icons.bolt_outlined,
              Wrap(spacing: 8, runSpacing: 8, children: skills.map((s) =>
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    // ← Usa el color del tema, no hardcoded
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.primaryPurple.withOpacity(0.25)
                        : AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryPurple.withOpacity(0.3)),
                  ),
                  child: Text(s, style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  )),
                )
              ).toList()),
            ),
            const SizedBox(height: 12),
          ],

          // ── Currículum ────────────────────────────────────────────────
          _buildSection(card, 'Currículum Vitae', Icons.description_outlined,
            _cvContent(context, perfil.cvUrl)),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // Tarjeta de info con etiquetas descriptivas
  Widget _buildInfoCard(Color card, PerfilEstudiante perfil) {
    final rows = <Widget>[];

    if (perfil.edad != null) {
      rows.add(_infoRow(Icons.cake_outlined, 'Edad',
          '${perfil.edad} años', AppColors.accentBlue));
    }

    if (perfil.ubicacion != null && perfil.ubicacion!.isNotEmpty) {
      rows.add(_infoRow(Icons.location_on_outlined, 'Ubicación',
          perfil.ubicacion!, AppColors.accentGreen));
    }

    if (perfil.modalidadPreferida != null) {
      rows.add(_infoRow(Icons.work_outline, 'Modalidad preferida',
          _lModal(perfil.modalidadPreferida!), AppColors.primaryPurple));
    }

    if (perfil.nivelAcademico.isNotEmpty) {
      rows.add(_infoRow(Icons.school_outlined, 'Nivel académico',
          perfil.nivelAcademico, AppColors.accentBlue));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(color: card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8)]),
      child: Column(
        children: rows.asMap().entries.map((e) => Column(children: [
          e.value,
          if (e.key < rows.length - 1)
            const Divider(height: 1, indent: 52),
        ])).toList(),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary)),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600)),
        ])),
      ]),
    );

  Widget _buildSection(Color card, String title, IconData icon, Widget child) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: AppColors.primaryPurple),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );

  Widget _cvContent(BuildContext context, String? cvUrl) {
    final tieneCv = cvUrl != null && cvUrl.isNotEmpty;
    return Row(children: [
      Icon(
        tieneCv ? Icons.check_circle : Icons.warning_amber_rounded,
        color: tieneCv ? AppColors.accentGreen : AppColors.textTertiary,
        size: 20,
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(
        tieneCv ? 'CV disponible para las empresas que te buscan'
                : 'Aún no has subido tu CV — agrégalo para mejorar tu perfil',
        style: AppTextStyles.bodyMedium.copyWith(
            color: tieneCv ? AppColors.textPrimary : AppColors.textSecondary),
      )),
      const SizedBox(width: 8),
      if (tieneCv)
        ElevatedButton.icon(
          onPressed: () => _abrirCv(cvUrl),
          icon: const Icon(Icons.open_in_new, size: 14),
          label: const Text('Ver CV'),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12)),
        )
      else
        TextButton(
          onPressed: () async {
            await context.push(AppRoutes.editProfile);
            if (mounted) _cargarPerfil();
          },
          child: const Text('Agregar'),
        ),
    ]);
  }

  Widget _statCard(Color card, IconData icon, String value,
      String label, Color color) =>
    Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: card,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8)]),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.h4.copyWith(color: color)),
        Text(label, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]),
    );

  Widget _buildError(String msg) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 60, color: AppColors.error),
      const SizedBox(height: 16),
      Text(msg, style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _cargarPerfil, child: const Text('Reintentar')),
    ]),
  ));

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
      case 'remoto': return 'Remoto (desde casa)';
      case 'presencial': return 'Presencial (en oficina)';
      case 'hibrido': return 'Híbrido (mixto)';
      default: return m;
    }
  }
}