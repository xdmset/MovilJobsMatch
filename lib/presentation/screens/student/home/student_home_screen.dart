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
                p.filtroUbicacion != null || p.filtroSueldoMin != null ||
                p.filtroBusqueda != null || p.filtroContrato != null ||
                p.filtroEmpresa != null;
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
        if (p.hasReachedLimit) return _buildLimitReached(context);
        if (p.vacantes.isEmpty) return _buildEmpty(context, p);
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
        SizedBox(width: double.infinity,
          child: OutlinedButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              context.read<StudentProvider>().limpiar();
              context.read<AuthProvider>().logout();
              Navigator.pop(context);
              context.go(AppRoutes.welcome);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Salir'),
          ),
        ),
      ],
    ));

  // ── Swipe stack ───────────────────────────────────────────────────────────
  Widget _buildSwipeStack(BuildContext context, StudentProvider p) {
    final v      = p.currentVacancy!;
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;

    return Column(children: [
      _buildSwipeProgress(p),
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

  Widget _buildSwipeProgress(StudentProvider p) {
    final pct = (p.remainingSwipes / p.maxSwipes).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(children: [
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation(
                pct > 0.4 ? AppColors.accentGreen
                : pct > 0.2 ? AppColors.accentOrange
                : AppColors.error),
            minHeight: 4,
          ),
        )),
        const SizedBox(width: 8),
        Text('${p.remainingSwipes}/${p.maxSwipes}',
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary, fontSize: 11)),
      ]),
    );
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
          Text('"${v['empresa_nombre'] ?? v['titulo'] ?? 'Esta empresa'}" también te eligió.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary), textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context),
                  child: const Text('¡Genial!'))),
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

  // ── Estados vacíos — FIX: Column con mainAxisSize.min para no amontonar ──
  Widget _buildEmpty(BuildContext context, StudentProvider p) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.work_off_outlined, size: 72, color: AppColors.textTertiary),
        const SizedBox(height: 16),
        Text('Sin vacantes disponibles', style: AppTextStyles.h4.copyWith(
            color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Ajusta los filtros o vuelve más tarde para ver nuevas oportunidades.',
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(onPressed: () => p.cargarVacantes(),
              icon: const Icon(Icons.refresh), label: const Text('Recargar'))),
        if (p.filtroModalidad != null || p.filtroUbicacion != null ||
            p.filtroSueldoMin != null || p.filtroBusqueda != null ||
            p.filtroContrato != null || p.filtroEmpresa != null) ...[
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
            child: OutlinedButton(onPressed: () => p.limpiarFiltros(),
                child: const Text('Quitar todos los filtros'))),
        ],
      ]),
    ),
  );

  Widget _buildLimitReached(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: AppColors.purpleGradient,
                shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, size: 60, color: Colors.white)),
        const SizedBox(height: 24),
        Text('Límite diario alcanzado', style: AppTextStyles.h3,
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Vuelve mañana para seguir explorando, o mejora a Premium para swipes ilimitados.',
            style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        // Countdown hasta medianoche
        const _CountdownTimer(),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.studentPremium),
              icon: const Icon(Icons.star),
              label: const Text('Mejorar a Premium'))),
      ]),
    ),
  );

  Widget _buildAllSeen(BuildContext context, StudentProvider p) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 72, color: AppColors.accentGreen),
        const SizedBox(height: 16),
        Text('¡Revisaste todas las vacantes!',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Vuelve mañana para ver nuevas oportunidades.',
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            onPressed: () => p.cargarVacantes(resetIndex: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Buscar de nuevo')),
      ]),
    ),
  );

  // ── Filtros mejorados ─────────────────────────────────────────────────────
  void _showFilters(BuildContext context) {
    final p = context.read<StudentProvider>();
    String? modalidadTemp = p.filtroModalidad;
    String? ubicacionTemp = p.filtroUbicacion;
    double? sueldoTemp    = p.filtroSueldoMin;
    String? busquedaTemp  = p.filtroBusqueda;
    String? contratoTemp  = p.filtroContrato;
    String? empresaTemp   = p.filtroEmpresa;

    final ubicCtrl     = TextEditingController(text: p.filtroUbicacion ?? '');
    final sueldoCtrl   = TextEditingController(
        text: p.filtroSueldoMin?.toStringAsFixed(0) ?? '');
    final busquedaCtrl = TextEditingController(text: p.filtroBusqueda ?? '');
    final empresaCtrl  = TextEditingController(text: p.filtroEmpresa ?? '');

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setModal) {
        InputDecoration inputDeco(String hint, IconData icon, TextEditingController ctrl,
            void Function() onClear) => InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close), onPressed: onClear)
              : null,
        );

        Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(t, style: AppTextStyles.subtitle1.copyWith(
              fontWeight: FontWeight.bold)));

        Widget chip(String texto, String valor, String? sel,
            void Function(String?) cb) {
          final isS = sel == valor;
          return FilterChip(
            label: Text(texto), selected: isS,
            onSelected: (_) => cb(isS ? null : valor),
            selectedColor: AppColors.primaryPurple, checkmarkColor: Colors.white,
            labelStyle: TextStyle(color: isS ? Colors.white : null,
                fontWeight: FontWeight.w600),
          );
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
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
                      sueldoTemp = null; busquedaTemp = null;
                      contratoTemp = null; empresaTemp = null;
                      ubicCtrl.clear(); sueldoCtrl.clear();
                      busquedaCtrl.clear(); empresaCtrl.clear();
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

                label('🔍 Buscar por nombre o puesto'),
                TextField(
                  controller: busquedaCtrl,
                  decoration: inputDeco(
                    'Ej: Desarrollador, Diseñador, Marketing...',
                    Icons.search, busquedaCtrl,
                    () { busquedaCtrl.clear(); setModal(() => busquedaTemp = null); }),
                  onChanged: (v) => setModal(() =>
                      busquedaTemp = v.trim().isEmpty ? null : v.trim()),
                ),
                const SizedBox(height: 22),

                label('🏢 Empresa específica'),
                TextField(
                  controller: empresaCtrl,
                  decoration: inputDeco(
                    'Ej: Google, TechCorp, StartupMX...',
                    Icons.business_outlined, empresaCtrl,
                    () { empresaCtrl.clear(); setModal(() => empresaTemp = null); }),
                  onChanged: (v) => setModal(() =>
                      empresaTemp = v.trim().isEmpty ? null : v.trim()),
                ),
                const SizedBox(height: 22),

                label('💼 Modalidad de trabajo'),
                Text('Sin selección = todas las modalidades',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  chip('🏠 Remoto', 'remoto', modalidadTemp,
                      (v) => setModal(() => modalidadTemp = v)),
                  chip('🏢 Presencial', 'presencial', modalidadTemp,
                      (v) => setModal(() => modalidadTemp = v)),
                  chip('🔄 Híbrido', 'hibrido', modalidadTemp,
                      (v) => setModal(() => modalidadTemp = v)),
                ]),
                const SizedBox(height: 22),

                label('📋 Tipo de contrato'),
                Text('Sin selección = todos los tipos · Vacantes sin contrato definido quedan fuera',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  chip('Servicio social', 'Servicio social', contratoTemp,
                      (v) => setModal(() => contratoTemp = v)),
                  chip('Indefinido', 'Indefinido', contratoTemp,
                      (v) => setModal(() => contratoTemp = v)),
                  chip('Por proyecto', 'proyecto', contratoTemp,
                      (v) => setModal(() => contratoTemp = v)),
                  chip('Prácticas', 'practicas', contratoTemp,
                      (v) => setModal(() => contratoTemp = v)),
                  chip('Freelance', 'freelance', contratoTemp,
                      (v) => setModal(() => contratoTemp = v)),
                  chip('Tiempo completo', 'completo', contratoTemp,
                      (v) => setModal(() => contratoTemp = v)),
                  chip('Medio tiempo', 'medio', contratoTemp,
                      (v) => setModal(() => contratoTemp = v)),
                ]),
                const SizedBox(height: 22),

                label('📍 Ubicación'),
                TextField(
                  controller: ubicCtrl,
                  decoration: inputDeco(
                    'Ej: Tijuana, Ciudad de México...',
                    Icons.location_on_outlined, ubicCtrl,
                    () { ubicCtrl.clear(); setModal(() => ubicacionTemp = null); }),
                  onChanged: (v) => setModal(() =>
                      ubicacionTemp = v.trim().isEmpty ? null : v.trim()),
                ),
                const SizedBox(height: 22),

                label('💰 Sueldo mínimo mensual (MXN)'),
                TextField(
                  controller: sueldoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: inputDeco(
                    'Sin límite mínimo',
                    Icons.attach_money, sueldoCtrl,
                    () { sueldoCtrl.clear(); setModal(() => sueldoTemp = null); }),
                  onChanged: (v) => setModal(() => sueldoTemp = double.tryParse(v)),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  5000.0, 8000.0, 10000.0, 15000.0, 20000.0, 30000.0
                ].map((s) {
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
                      busqueda:  busquedaTemp,
                      contrato:  contratoTemp,
                      empresa:   empresaTemp,
                    );
                  },
                  child: Text((modalidadTemp ?? ubicacionTemp ?? sueldoTemp ??
                      busquedaTemp ?? contratoTemp ?? empresaTemp) != null
                      ? 'Aplicar filtros'
                      : 'Ver todas las vacantes'),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

// ── Countdown hasta medianoche ────────────────────────────────────────────────
class _CountdownTimer extends StatefulWidget {
  const _CountdownTimer();
  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calcular();
    _tick();
  }

  void _calcular() {
    final now    = DateTime.now();
    final manana = DateTime(now.year, now.month, now.day + 1);
    _remaining   = manana.difference(now);
  }

  void _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(minutes: 1));
      if (!mounted) return;
      setState(_calcular);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.textTertiary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_outlined, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Text('Nuevo lote de swipes en ${h}h ${m}m',
            style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Tarjeta con swipe gestural ────────────────────────────────────────────────
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
  Offset _offset   = Offset.zero;
  bool   _dragging = false;
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
      top: 30, left: left ? 20 : null, right: !left ? 20 : null,
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
    final v = widget.vacante;
    final titulo          = v['titulo']             as String? ?? 'Vacante';
    final modalidad       = v['modalidad']          as String? ?? '';
    final ubicacion       = v['ubicacion']          as String? ?? '';
    final desc            = v['descripcion']        as String? ?? '';
    final requi           = v['requisitos']         as String? ?? '';
    final contrato        = v['tipo_contrato']      as String? ?? '';
    final minS            = v['sueldo_minimo'];
    final maxS            = v['sueldo_maximo'];
    final moneda          = v['moneda']             as String? ?? 'MXN';
    final estado          = v['estado']             as String? ?? '';
    final empresaNombre   = v['empresa_nombre']     as String? ?? 'Empresa';
    final empresaSector   = v['empresa_sector']     as String?;
    final empresaFotoUrl  = v['empresa_foto_url']   as String?;
    final empresaDesc     = v['empresa_descripcion']as String?;
    final empresaUbic     = v['empresa_ubicacion']  as String?;

    String salario = '';
    if (minS != null && maxS != null)
      salario = '\$${_fmt(minS)} – \$${_fmt(maxS)} $moneda/mes';
    else if (minS != null) salario = 'Desde \$${_fmt(minS)} $moneda/mes';
    else if (maxS != null) salario = 'Hasta \$${_fmt(maxS)} $moneda/mes';

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
          // ── Header empresa ──────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 60, height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primaryPurple.withOpacity(0.15))),
              child: empresaFotoUrl != null
                  ? Image.network(empresaFotoUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _logoFallback(empresaNombre))
                  : _logoFallback(empresaNombre),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(empresaNombre, style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryPurple, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(titulo, style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.bold, height: 1.2)),
              if (empresaSector != null && empresaSector.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.category_outlined, size: 12,
                      color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(empresaSector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
                ]),
              ],
            ])),
            if (estado == 'activa')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Activa', style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.w700, fontSize: 10)),
              ),
          ]),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // ── Info ──────────────────────────────────────────────────────────
          if (modalidad.isNotEmpty)
            _row(Icons.work_outline, 'Modalidad', _lModal(modalidad),
                AppColors.primaryPurple),
          if (ubicacion.isNotEmpty)
            _row(Icons.location_on_outlined, 'Ubicación', ubicacion,
                AppColors.accentBlue),
          if (empresaUbic != null && empresaUbic.isNotEmpty &&
              empresaUbic != ubicacion)
            _row(Icons.apartment_outlined, 'Sede', empresaUbic,
                AppColors.accentBlue),
          if (salario.isNotEmpty)
            _row(Icons.payments_outlined, 'Sueldo', salario,
                AppColors.accentGreen),
          if (contrato.isNotEmpty)
            _row(Icons.badge_outlined, 'Contrato', contrato,
                AppColors.accentOrange),

          // ── Sobre empresa ─────────────────────────────────────────────────
          if (empresaDesc != null && empresaDesc.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _seccion(Icons.business_outlined, 'Sobre la empresa'),
            const SizedBox(height: 6),
            Text(empresaDesc, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6),
                maxLines: 4, overflow: TextOverflow.ellipsis),
          ],

          // ── Descripción ───────────────────────────────────────────────────
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _seccion(Icons.description_outlined, 'Descripción del puesto'),
            const SizedBox(height: 6),
            Text(desc, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
          ],

          // ── Requisitos ────────────────────────────────────────────────────
          if (requi.isNotEmpty) ...[
            const SizedBox(height: 12),
            _seccion(Icons.checklist_outlined, 'Requisitos'),
            const SizedBox(height: 6),
            Text(requi, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _logoFallback(String nombre) {
    final ini = nombre.trim().split(' ').where((w) => w.isNotEmpty)
        .take(2).map((w) => w[0].toUpperCase()).join();
    return Center(child: Text(ini, style: TextStyle(
        color: AppColors.primaryPurple, fontWeight: FontWeight.bold,
        fontSize: ini.length == 1 ? 22 : 18)));
  }

  String _fmt(dynamic n) {
    final d = double.tryParse(n.toString()) ?? 0;
    return d.truncate().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _row(IconData icon, String label, String val, Color color) =>
    Padding(padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color)),
        const SizedBox(width: 8),
        Text('$label: ', style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Flexible(child: Text(val, style: AppTextStyles.bodySmall.copyWith(
            color: color, fontWeight: FontWeight.w700))),
      ]));

  Widget _seccion(IconData icon, String label) =>
    Row(children: [
      Icon(icon, size: 14, color: AppColors.primaryPurple),
      const SizedBox(width: 6),
      Text(label, style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.bold)),
    ]);

  String _lModal(String m) {
    switch (m) {
      case 'remoto':     return '🏠 Remoto (desde casa)';
      case 'presencial': return '🏢 Presencial (en oficina)';
      case 'hibrido':    return '🔄 Híbrido (mixto)';
      default:           return m.isNotEmpty ? m : 'No especificado';
    }
  }
}