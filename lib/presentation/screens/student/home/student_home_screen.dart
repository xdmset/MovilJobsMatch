// lib/presentation/screens/student/home/student_home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/theme_provider.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Consumer<StudentProvider>(
          builder: (_, p, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Encuentra tu match', style: AppTextStyles.h4),
              Text(
                p.hasReachedLimit
                    ? 'Límite diario alcanzado'
                    : '${p.remainingSwipes} swipes disponibles',
                style: AppTextStyles.bodySmall.copyWith(
                  color: p.hasReachedLimit ? AppColors.error : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.tune),
              onPressed: () => _showFilters(context)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _handleMenu(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings',
                  child: Row(children: [Icon(Icons.settings_outlined),
                    SizedBox(width: 12), Text('Configuración')])),
              PopupMenuItem(value: 'theme',
                  child: Row(children: [Icon(Icons.dark_mode_outlined),
                    SizedBox(width: 12), Text('Tema')])),
              PopupMenuItem(value: 'logout',
                  child: Row(children: [Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Cerrar sesión', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
      body: Consumer<StudentProvider>(
        builder: (context, p, _) {
          if (p.cargandoVacantes && p.vacantes.isEmpty)
            return const Center(child: CircularProgressIndicator());
          if (p.vacantes.isEmpty)     return _buildEmpty(context, p);
          if (p.hasReachedLimit)      return _buildLimitReached(context);
          if (p.currentVacancy == null) return _buildAllSeen(context, p);
          return _buildSwipeStack(context, p);
        },
      ),
    );
  }

  void _handleMenu(BuildContext context, String value) {
    switch (value) {
      case 'settings': context.push(AppRoutes.settings); break;
      case 'theme':    _showThemeDialog(context); break;
      case 'logout':   _handleLogout(context); break;
    }
  }

  void _showThemeDialog(BuildContext context) {
    final tp = context.read<ThemeProvider>();
    final sp = context.read<SettingsProvider>();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tema'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _tOpt(context, 'Sistema', ThemeMode.system, Icons.brightness_auto_outlined, tp, sp),
        _tOpt(context, 'Claro',   ThemeMode.light,  Icons.light_mode_outlined,      tp, sp),
        _tOpt(context, 'Oscuro',  ThemeMode.dark,   Icons.dark_mode_outlined,       tp, sp),
      ]),
    ));
  }

  Widget _tOpt(BuildContext context, String label, ThemeMode mode,
      IconData icon, ThemeProvider tp, SettingsProvider sp) {
    final sel = tp.themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: sel ? AppColors.primaryPurple : AppColors.textSecondary),
      title: Text(label),
      trailing: sel ? const Icon(Icons.check, color: AppColors.primaryPurple) : null,
      onTap: () { tp.setTheme(label); sp.setTheme(label); Navigator.pop(context); },
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres salir?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
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

  // ── Swipe stack ───────────────────────────────────────────────────────────
  Widget _buildSwipeStack(BuildContext context, StudentProvider p) {
    final v      = p.currentVacancy!;
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _VacancyCard(vacante: v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 28, left: 48, right: 48),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _swipeBtn(Icons.close, AppColors.error, 56,
              () => p.dislikeVacancy(userId)),
          _swipeBtn(Icons.favorite, AppColors.accentGreen, 68,
              () => _onLike(context, p, userId, v)),
          _swipeBtn(Icons.bookmark_border, AppColors.accentBlue, 48, () {}),
        ]),
      ),
    ]);
  }

  Future<void> _onLike(BuildContext context, StudentProvider p,
      int userId, Map<String, dynamic> v) async {
    final esMatch = await p.likeVacancy(userId);
    if (!context.mounted) return;

    if (esMatch) {
      showDialog(context: context, builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.purpleGradient,
                shape: BoxShape.circle),
            child: const Icon(Icons.favorite, color: Colors.white, size: 48)),
          const SizedBox(height: 16),
          Text('¡Es un Match! 🎉', style: AppTextStyles.h3.copyWith(
              color: AppColors.accentGreen)),
          const SizedBox(height: 8),
          Text('Tú y "${v['titulo'] ?? 'esta empresa'}" se gustaron mutuamente.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Seguir viendo')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ver match'),
          ),
        ],
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.thumb_up_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('Le diste like a "${v['titulo'] ?? 'esta vacante'}"',
              style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: AppColors.primaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _swipeBtn(IconData icon, Color color, double size, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(width: size, height: size,
        decoration: BoxDecoration(color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2)),
        child: Icon(icon, color: color, size: size * 0.45)),
    );

  // ── Estados ───────────────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context, StudentProvider p) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.work_off_outlined, size: 80, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text('Sin vacantes disponibles',
          style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text('Vuelve más tarde para nuevas oportunidades',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: () => p.cargarVacantes(),
          icon: const Icon(Icons.refresh), label: const Text('Recargar')),
    ]),
  );

  Widget _buildLimitReached(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: AppColors.purpleGradient,
              shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline, size: 60, color: Colors.white)),
      const SizedBox(height: 24),
      Text('Límite diario alcanzado', style: AppTextStyles.h3,
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text('Mejora a Premium para swipes ilimitados.',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),
      ElevatedButton.icon(onPressed: () => context.push(AppRoutes.premium),
          icon: const Icon(Icons.star, size: 20),
          label: const Text('Mejorar a Premium')),
    ])),
  );

  Widget _buildAllSeen(BuildContext context, StudentProvider p) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.check_circle_outline, size: 80, color: AppColors.accentGreen),
      const SizedBox(height: 16),
      Text('¡Viste todas las vacantes!',
          style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text('Vuelve mañana para nuevas oportunidades',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: () => p.cargarVacantes(),
          child: const Text('Recargar vacantes')),
    ]),
  );

  void _showFilters(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Filtros', style: AppTextStyles.h4),
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('Listo')),
            ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Modalidad', style: AppTextStyles.subtitle1),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: ['Remoto','Híbrido','Presencial']
                  .map((l) => FilterChip(label: Text(l), selected: false,
                      onSelected: (_) {})).toList()),
              const SizedBox(height: 16),
              Text('Tipo', style: AppTextStyles.subtitle1),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: ['Tiempo completo','Prácticas','Medio tiempo']
                  .map((l) => FilterChip(label: Text(l), selected: false,
                      onSelected: (_) {})).toList()),
            ])),
        ]),
      ),
    );
  }
}

// ── Tarjeta de vacante ────────────────────────────────────────────────────────
class _VacancyCard extends StatelessWidget {
  final Map<String, dynamic> vacante;
  const _VacancyCard({required this.vacante});

  @override
  Widget build(BuildContext context) {
    final titulo    = vacante['titulo'] as String? ?? 'Vacante';
    final modalidad = vacante['modalidad'] as String? ?? '';
    final ubicacion = vacante['ubicacion'] as String? ?? '';
    final desc      = vacante['descripcion'] as String? ?? '';
    final requi     = vacante['requisitos'] as String? ?? '';
    final minS      = vacante['sueldo_minimo'];
    final maxS      = vacante['sueldo_maximo'];
    final moneda    = vacante['moneda'] as String? ?? 'MXN';
    String salario  = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
            blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.business, color: AppColors.primaryPurple, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: AppTextStyles.h4.copyWith(
                fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (modalidad.isNotEmpty) _chip(Icons.work_outline, _lModal(modalidad),
                AppColors.primaryPurple),
            if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined, ubicacion,
                AppColors.accentBlue),
            if (salario.isNotEmpty)   _chip(Icons.attach_money, salario,
                AppColors.accentGreen),
          ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Descripción', style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(desc, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
          ],
          if (requi.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Requisitos', style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(requi, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
          ],
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );

  String _lModal(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }
}