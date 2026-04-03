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
                  color: p.hasReachedLimit
                      ? AppColors.error : AppColors.textTertiary),
              ),
            ],
          ),
        ),
        actions: [
          // Botón de filtros con badge si hay filtros activos
          Consumer<StudentProvider>(builder: (_, p, __) {
            final hayFiltros = p.filtroModalidad != null ||
                p.filtroUbicacion != null || p.filtroSueldoMin != null;
            return Stack(children: [
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => _showFilters(context),
              ),
              if (hayFiltros)
                Positioned(right: 8, top: 8, child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryPurple, shape: BoxShape.circle),
                )),
            ]);
          }),
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
                  child: Row(children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Cerrar sesión',
                        style: TextStyle(color: AppColors.error))])),
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

  // ── Menú ──────────────────────────────────────────────────────────────────
  void _handleMenu(BuildContext context, String v) {
    switch (v) {
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
        _tOpt(context, 'Sistema', ThemeMode.system,
            Icons.brightness_auto_outlined, tp, sp),
        _tOpt(context, 'Claro',   ThemeMode.light,
            Icons.light_mode_outlined, tp, sp),
        _tOpt(context, 'Oscuro',  ThemeMode.dark,
            Icons.dark_mode_outlined, tp, sp),
      ]),
    ));
  }

  Widget _tOpt(BuildContext context, String label, ThemeMode mode,
      IconData icon, ThemeProvider tp, SettingsProvider sp) {
    final sel = tp.themeMode == mode;
    return ListTile(
      leading: Icon(icon,
          color: sel ? AppColors.primaryPurple : AppColors.textSecondary),
      title: Text(label),
      trailing: sel
          ? const Icon(Icons.check, color: AppColors.primaryPurple) : null,
      onTap: () { tp.setTheme(label); sp.setTheme(label); Navigator.pop(context); },
    );
  }

  void _handleLogout(BuildContext context) =>
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres salir?'),
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

  // ── Swipe stack con gestura real ──────────────────────────────────────────
  Widget _buildSwipeStack(BuildContext context, StudentProvider p) {
    final v      = p.currentVacancy!;
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;

    return Column(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _SwipeCard(
            key: ValueKey(v['id']),   // ← re-crea la tarjeta en cada vacante
            vacante: v,
            onLike:    () => _onLike(context, p, userId, v),
            onDislike: () => p.dislikeVacancy(userId),
          ),
        ),
      ),
      // Botones de swipe
      Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 48, right: 48),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _swipeBtn(Icons.close, AppColors.error, 56,
              () => p.dislikeVacancy(userId)),
          _swipeBtn(Icons.favorite, AppColors.accentGreen, 68,
              () => _onLike(context, p, userId, v)),
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
            decoration: BoxDecoration(
                gradient: AppColors.purpleGradient, shape: BoxShape.circle),
            child: const Icon(Icons.favorite, color: Colors.white, size: 48)),
          const SizedBox(height: 16),
          Text('¡Es un Match! 🎉',
              style: AppTextStyles.h3.copyWith(color: AppColors.accentGreen)),
          const SizedBox(height: 8),
          Text('"${v['titulo'] ?? 'Esta vacante'}" te eligió',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Seguir viendo')),
          ElevatedButton(onPressed: () => Navigator.pop(context),
              child: const Text('¡Genial!')),
        ],
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.thumb_up_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('Like enviado a "${v['titulo'] ?? 'esta vacante'}"',
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
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
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
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton.icon(
            onPressed: () => p.cargarVacantes(),
            icon: const Icon(Icons.refresh), label: const Text('Recargar')),
        const SizedBox(width: 12),
        if (p.filtroModalidad != null || p.filtroUbicacion != null ||
            p.filtroSueldoMin != null)
          OutlinedButton(
              onPressed: () => p.limpiarFiltros(),
              child: const Text('Quitar filtros')),
      ]),
    ]),
  );

  Widget _buildLimitReached(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              gradient: AppColors.purpleGradient, shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline, size: 60, color: Colors.white)),
      const SizedBox(height: 24),
      Text('Límite diario alcanzado', style: AppTextStyles.h3,
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text('Mejora a Premium para swipes ilimitados.',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),
      ElevatedButton.icon(
          onPressed: () => context.push(AppRoutes.premium),
          icon: const Icon(Icons.star), label: const Text('Mejorar a Premium')),
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
      ElevatedButton.icon(
          onPressed: () => p.cargarVacantes(resetIndex: true),
          icon: const Icon(Icons.refresh), label: const Text('Recargar vacantes')),
    ]),
  );

  // ── Filtros funcionales ───────────────────────────────────────────────────
  void _showFilters(BuildContext context) {
    final p = context.read<StudentProvider>();
    String? modalidadTemp = p.filtroModalidad;
    String? ubicacionTemp = p.filtroUbicacion;
    double? sueldoTemp    = p.filtroSueldoMin;
    final ubicacionCtrl   = TextEditingController(text: p.filtroUbicacion ?? '');
    final sueldoCtrl      = TextEditingController(
        text: p.filtroSueldoMin?.toStringAsFixed(0) ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filtros', style: AppTextStyles.h4),
                  TextButton(
                    onPressed: () {
                      setModal(() {
                        modalidadTemp = null;
                        ubicacionTemp = null;
                        sueldoTemp    = null;
                        ubicacionCtrl.clear();
                        sueldoCtrl.clear();
                      });
                    },
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // ── Modalidad ────────────────────────────────────────────
                Text('Modalidad', style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8,
                    children: ['remoto','presencial','hibrido'].map((m) {
                  final sel = modalidadTemp == m;
                  return ChoiceChip(
                    label: Text(_lModal(m)), selected: sel,
                    onSelected: (_) =>
                        setModal(() => modalidadTemp = sel ? null : m),
                    selectedColor: AppColors.primaryPurple,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : null,
                        fontWeight: FontWeight.w600),
                  );
                }).toList()),
                const SizedBox(height: 24),

                // ── Ubicación ────────────────────────────────────────────
                Text('Ubicación', style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: ubicacionCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ej: Tijuana, Ciudad de México',
                    prefixIcon: const Icon(Icons.location_on_outlined,
                        color: AppColors.primaryPurple),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryPurple, width: 2)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    suffixIcon: ubicacionCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              ubicacionCtrl.clear();
                              setModal(() => ubicacionTemp = null);
                            })
                        : null,
                  ),
                  onChanged: (v) =>
                      setModal(() => ubicacionTemp = v.isEmpty ? null : v),
                ),
                const SizedBox(height: 24),

                // ── Sueldo mínimo ────────────────────────────────────────
                Text('Sueldo mínimo (MXN)', style: AppTextStyles.subtitle1
                    .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: sueldoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ej: 10000',
                    prefixIcon: const Icon(Icons.attach_money,
                        color: AppColors.primaryPurple),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryPurple, width: 2)),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    suffixIcon: sueldoCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              sueldoCtrl.clear();
                              setModal(() => sueldoTemp = null);
                            })
                        : null,
                  ),
                  onChanged: (v) =>
                      setModal(() => sueldoTemp = double.tryParse(v)),
                ),
                const SizedBox(height: 8),
                // Rangos rápidos
                Wrap(spacing: 8, children: [5000.0, 10000.0, 15000.0, 20000.0]
                    .map((s) {
                  final sel = sueldoTemp == s;
                  return ChoiceChip(
                    label: Text('\$${s.toStringAsFixed(0)}'),
                    selected: sel,
                    onSelected: (_) {
                      setModal(() {
                        sueldoTemp = sel ? null : s;
                        sueldoCtrl.text = sel ? '' : s.toStringAsFixed(0);
                      });
                    },
                    selectedColor: AppColors.primaryPurple,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : null,
                        fontWeight: FontWeight.w600),
                  );
                }).toList()),
              ]),
            )),
            // Botón aplicar
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    p.aplicarFiltros(
                      modalidad: modalidadTemp,
                      ubicacion: ubicacionTemp,
                      sueldoMin: sueldoTemp,
                    );
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
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

// ── Tarjeta con swipe gestural ────────────────────────────────────────────────
class _SwipeCard extends StatefulWidget {
  final Map<String, dynamic> vacante;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const _SwipeCard({
    super.key,
    required this.vacante,
    required this.onLike,
    required this.onDislike,
  });

  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard>
    with SingleTickerProviderStateMixin {
  Offset _offset = Offset.zero;
  bool   _isDragging = false;

  static const double _swipeThreshold = 100.0;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final angle   = (_offset.dx / screenW) * 0.4;
    final opacity = (_offset.dx.abs() / _swipeThreshold).clamp(0.0, 1.0);
    final isRight = _offset.dx > 0;

    return GestureDetector(
      onPanStart:  (_) => setState(() => _isDragging = true),
      onPanUpdate: (d) => setState(() => _offset += d.delta),
      onPanEnd:    (_) {
        setState(() => _isDragging = false);
        if (_offset.dx.abs() >= _swipeThreshold) {
          // Swipe completado
          if (_offset.dx > 0) {
            widget.onLike();
          } else {
            widget.onDislike();
          }
          setState(() => _offset = Offset.zero);
        } else {
          // Regresar al centro
          setState(() => _offset = Offset.zero);
        }
      },
      child: AnimatedContainer(
        duration: _isDragging
            ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(_offset.dx, _offset.dy * 0.3)
          ..rotateZ(angle),
        child: Stack(children: [
          // Tarjeta de contenido
          _buildCardContent(context),

          // Indicador LIKE
          if (_offset.dx > 20)
            Positioned(top: 30, left: 20,
              child: Opacity(opacity: opacity, child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('LIKE',
                      style: AppTextStyles.h4.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ))),

          // Indicador PASS
          if (_offset.dx < -20)
            Positioned(top: 30, right: 20,
              child: Opacity(opacity: opacity, child: Transform.rotate(
                angle: 0.3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('PASS',
                      style: AppTextStyles.h4.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ))),
        ]),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final v       = widget.vacante;
    final titulo   = v['titulo']      as String? ?? 'Vacante';
    final modalidad = v['modalidad']  as String? ?? '';
    final ubicacion = v['ubicacion']  as String? ?? '';
    final desc     = v['descripcion'] as String? ?? '';
    final requi    = v['requisitos']  as String? ?? '';
    final minS     = v['sueldo_minimo'];
    final maxS     = v['sueldo_maximo'];
    final moneda   = v['moneda']      as String? ?? 'MXN';
    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 20, offset: const Offset(0, 8),
        )],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.business,
                  color: AppColors.primaryPurple, size: 28)),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo,
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (modalidad.isNotEmpty)
              _chip(Icons.work_outline, _lModal(modalidad),
                  AppColors.primaryPurple),
            if (ubicacion.isNotEmpty)
              _chip(Icons.location_on_outlined, ubicacion,
                  AppColors.accentBlue),
            if (salario.isNotEmpty)
              _chip(Icons.attach_money, salario, AppColors.accentGreen),
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
          const SizedBox(height: 80), // espacio para no tapar los botones
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(
          fontSize: 12, color: color, fontWeight: FontWeight.w600)),
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