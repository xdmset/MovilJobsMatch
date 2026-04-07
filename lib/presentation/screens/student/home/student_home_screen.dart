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
        title: Consumer<StudentProvider>(builder: (_, p, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explorar vacantes', style: AppTextStyles.h4),
            Text(
              p.hasReachedLimit
                  ? 'Límite diario alcanzado'
                  : '${p.remainingSwipes} restantes hoy',
              style: AppTextStyles.bodySmall.copyWith(
                  color: p.hasReachedLimit
                      ? AppColors.error : AppColors.textTertiary),
            ),
          ],
        )),
        actions: [
          Consumer<StudentProvider>(builder: (_, p, __) {
            final activo = p.filtroModalidad != null ||
                p.filtroUbicacion != null || p.filtroSueldoMin != null;
            return Stack(children: [
              IconButton(
                icon: Icon(activo ? Icons.tune : Icons.tune_outlined),
                onPressed: () => _showFilters(context),
                tooltip: 'Filtros',
              ),
              if (activo) Positioned(right: 8, top: 8,
                child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryPurple, shape: BoxShape.circle))),
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
      body: Consumer<StudentProvider>(builder: (context, p, _) {
        if (p.cargandoVacantes && p.vacantes.isEmpty)
          return const Center(child: CircularProgressIndicator());
        if (p.vacantes.isEmpty)      return _buildEmpty(context, p);
        if (p.hasReachedLimit)       return _buildLimitReached(context);
        if (p.currentVacancy == null) return _buildAllSeen(context, p);
        return _buildSwipeStack(context, p);
      }),
    );
  }

  void _handleMenu(BuildContext context, String v) {
    switch (v) {
      case 'settings': context.push(AppRoutes.studentSettings); break;
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

  // ── Swipe stack ───────────────────────────────────────────────────────────
  Widget _buildSwipeStack(BuildContext context, StudentProvider p) {
    final v      = p.currentVacancy!;
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;

    return Column(children: [
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: _SwipeCard(
          key: ValueKey(v['id']),
          vacante: v,
          onLike:    () => _onLike(context, p, userId, v),
          onDislike: () => p.dislikeVacancy(userId),
        ),
      )),
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
            decoration: BoxDecoration(gradient: AppColors.purpleGradient,
                shape: BoxShape.circle),
            child: const Icon(Icons.favorite, color: Colors.white, size: 48)),
          const SizedBox(height: 16),
          Text('¡Es un Match! 🎉',
              style: AppTextStyles.h3.copyWith(color: AppColors.accentGreen)),
          const SizedBox(height: 8),
          Text('"${v['titulo'] ?? 'Esta empresa'}" también te eligió.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary), textAlign: TextAlign.center),
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
          Expanded(child: Text('Te gustó "${v['titulo'] ?? 'esta vacante'}"',
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
        decoration: BoxDecoration(color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2)),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );

  // ── Estados vacíos ────────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context, StudentProvider p) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.work_off_outlined, size: 80, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text('Sin vacantes disponibles', style: AppTextStyles.h4.copyWith(
          color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text('Vuelve más tarde o quita los filtros activos',
          style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ElevatedButton.icon(onPressed: () => p.cargarVacantes(),
            icon: const Icon(Icons.refresh), label: const Text('Recargar')),
        if (p.filtroModalidad != null || p.filtroUbicacion != null ||
            p.filtroSueldoMin != null) ...[
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () => p.limpiarFiltros(),
              child: const Text('Quitar filtros')),
        ],
      ]),
    ])),
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
      Text('Mejora a Premium para tener swipes ilimitados cada día.',
          style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      ElevatedButton.icon(onPressed: () => context.push(AppRoutes.premium),
          icon: const Icon(Icons.star), label: const Text('Mejorar a Premium')),
    ])),
  );

  Widget _buildAllSeen(BuildContext context, StudentProvider p) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.check_circle_outline, size: 80, color: AppColors.accentGreen),
      const SizedBox(height: 16),
      Text('¡Revisaste todas las vacantes disponibles!',
          style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('Vuelve mañana para ver nuevas oportunidades',
          style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
          onPressed: () => p.cargarVacantes(resetIndex: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Buscar de nuevo')),
    ])),
  );

  // ── Filtros ───────────────────────────────────────────────────────────────
  void _showFilters(BuildContext context) {
    final p = context.read<StudentProvider>();
    // Por defecto sin filtro de modalidad (muestra todas)
    String? modalidadTemp = p.filtroModalidad;
    String? ubicacionTemp = p.filtroUbicacion;
    double? sueldoTemp    = p.filtroSueldoMin;
    final ubicCtrl  = TextEditingController(text: p.filtroUbicacion ?? '');
    final sueldoCtrl = TextEditingController(
        text: p.filtroSueldoMin?.toStringAsFixed(0) ?? '');

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filtrar vacantes', style: AppTextStyles.h4),
                TextButton(
                  onPressed: () => setModal(() {
                    modalidadTemp = null; ubicacionTemp = null;
                    sueldoTemp = null; ubicCtrl.clear(); sueldoCtrl.clear();
                  }),
                  child: const Text('Limpiar todo'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Modalidad ─────────────────────────────────────────────
              Text('Modalidad de trabajo', style: AppTextStyles.subtitle1
                  .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Sin selección = muestra todas las modalidades',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _filterChip('Remoto', 'remoto', modalidadTemp,
                    Icons.home_work_outlined, (v) =>
                        setModal(() => modalidadTemp = v)),
                _filterChip('Presencial', 'presencial', modalidadTemp,
                    Icons.business_outlined, (v) =>
                        setModal(() => modalidadTemp = v)),
                _filterChip('Híbrido', 'hibrido', modalidadTemp,
                    Icons.sync_alt_outlined, (v) =>
                        setModal(() => modalidadTemp = v)),
              ]),
              const SizedBox(height: 24),

              // ── Ubicación ─────────────────────────────────────────────
              Text('Ubicación', style: AppTextStyles.subtitle1
                  .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: ubicCtrl,
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
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  suffixIcon: ubicCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close),
                          onPressed: () {
                            ubicCtrl.clear();
                            setModal(() => ubicacionTemp = null);
                          }) : null,
                ),
                onChanged: (v) => setModal(() =>
                    ubicacionTemp = v.trim().isEmpty ? null : v.trim()),
              ),
              const SizedBox(height: 24),

              // ── Sueldo mínimo ─────────────────────────────────────────
              Text('Sueldo mínimo mensual (MXN)', style: AppTextStyles.subtitle1
                  .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: sueldoCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Sin límite mínimo',
                  prefixIcon: const Icon(Icons.attach_money,
                      color: AppColors.primaryPurple),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryPurple, width: 2)),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  suffixIcon: sueldoCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close),
                          onPressed: () {
                            sueldoCtrl.clear();
                            setModal(() => sueldoTemp = null);
                          }) : null,
                ),
                onChanged: (v) => setModal(() => sueldoTemp = double.tryParse(v)),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [5000.0, 10000.0, 15000.0, 20000.0]
                  .map((s) {
                final sel = sueldoTemp == s;
                return ChoiceChip(
                  label: Text('\$${s.toStringAsFixed(0)}'),
                  selected: sel,
                  onSelected: (_) => setModal(() {
                    sueldoTemp = sel ? null : s;
                    sueldoCtrl.text = sel ? '' : s.toStringAsFixed(0);
                  }),
                  selectedColor: AppColors.primaryPurple,
                  labelStyle: TextStyle(
                      color: sel ? Colors.white : null,
                      fontWeight: FontWeight.w600),
                );
              }).toList()),
            ]),
          )),
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
                child: Text(modalidadTemp == null && ubicacionTemp == null &&
                    sueldoTemp == null
                    ? 'Ver todas las vacantes'
                    : 'Aplicar filtros'),
              ),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _filterChip(String label, String value, String? selected,
      IconData icon, void Function(String?) onChanged) {
    final sel = selected == value;
    return FilterChip(
      avatar: Icon(icon,
          size: 16, color: sel ? Colors.white : AppColors.textSecondary),
      label: Text(label),
      selected: sel,
      onSelected: (_) => onChanged(sel ? null : value),
      selectedColor: AppColors.primaryPurple,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
          color: sel ? Colors.white : null, fontWeight: FontWeight.w600),
    );
  }

}

// ── Tarjeta con swipe gestural + info de empresa ──────────────────────────────
class _SwipeCard extends StatefulWidget {
  final Map<String, dynamic> vacante;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  const _SwipeCard({super.key, required this.vacante,
      required this.onLike, required this.onDislike});
  @override
  State<_SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<_SwipeCard> {
  Offset _offset    = Offset.zero;
  bool   _dragging  = false;
  static const double _threshold = 100.0;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final angle   = (_offset.dx / screenW) * 0.4;
    final opacity = (_offset.dx.abs() / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onPanStart:  (_) => setState(() => _dragging = true),
      onPanUpdate: (d) => setState(() => _offset += d.delta),
      onPanEnd:    (_) {
        setState(() => _dragging = false);
        if (_offset.dx.abs() >= _threshold) {
          _offset.dx > 0 ? widget.onLike() : widget.onDislike();
        }
        setState(() => _offset = Offset.zero);
      },
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(_offset.dx, _offset.dy * 0.3)
          ..rotateZ(angle),
        child: Stack(children: [
          _buildCard(context),
          if (_offset.dx > 20) _indicator('ME GUSTA', AppColors.accentGreen,
              opacity, true),
          if (_offset.dx < -20) _indicator('PASO', AppColors.error,
              opacity, false),
        ]),
      ),
    );
  }

  Widget _indicator(String label, Color color, double opacity, bool left) =>
    Positioned(
      top: 30,
      left:  left  ? 20 : null,
      right: !left ? 20 : null,
      child: Opacity(opacity: opacity, child: Transform.rotate(
        angle: left ? -0.3 : 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2)),
          child: Text(label, style: AppTextStyles.h4.copyWith(
              color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      )),
    );

  Widget _buildCard(BuildContext context) {
    final v          = widget.vacante;
    final titulo     = v['titulo']       as String? ?? 'Vacante';
    final modalidad  = v['modalidad']    as String? ?? '';
    final ubicacion  = v['ubicacion']    as String? ?? '';
    final desc       = v['descripcion']  as String? ?? '';
    final requi      = v['requisitos']   as String? ?? '';
    final contrato   = v['tipo_contrato'] as String? ?? '';
    final minS       = v['sueldo_minimo'];
    final maxS       = v['sueldo_maximo'];
    final moneda     = v['moneda']        as String? ?? 'MXN';
    // Tipo de empresa — viene del perfil de la empresa embebido si existe
    final tipoEmpresa = v['tipo_empresa']  as String?
                     ?? v['sector']        as String?
                     ?? v['empresa']?['sector'] as String?;
    String salario   = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
            blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header empresa ──────────────────────────────────────────
          Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.business, color: AppColors.primaryPurple)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.bold)),
              if (tipoEmpresa != null && tipoEmpresa.isNotEmpty)
                Text('Empresa · $tipoEmpresa',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 16),

          // ── Info chips con etiquetas ─────────────────────────────────
          if (modalidad.isNotEmpty) _infoRow(
              Icons.work_outline, 'Modalidad', _lModal(modalidad),
              AppColors.primaryPurple),
          if (ubicacion.isNotEmpty) _infoRow(
              Icons.location_on_outlined, 'Ubicación', ubicacion,
              AppColors.accentBlue),
          if (salario.isNotEmpty) _infoRow(
              Icons.attach_money, 'Sueldo', salario,
              AppColors.accentGreen),
          if (contrato.isNotEmpty) _infoRow(
              Icons.badge_outlined, 'Contrato', contrato,
              AppColors.accentBlue),

          // ── Descripción ──────────────────────────────────────────────
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text('Descripción del puesto',
                style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(desc, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
          ],
          if (requi.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Requisitos', style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(requi, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
          ],
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text('$label: ', style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Flexible(child: Text(value, style: AppTextStyles.bodySmall.copyWith(
            color: color, fontWeight: FontWeight.w700))),
      ]),
    );

  String _lModal(String m) {
    switch (m) {
      case 'remoto': return 'Remoto (desde casa)';
      case 'presencial': return 'Presencial (en oficina)';
      case 'hibrido': return 'Híbrido (mixto)';
      default: return m.isNotEmpty ? m : 'No especificado';
    }
  }
}