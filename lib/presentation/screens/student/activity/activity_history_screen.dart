// lib/presentation/screens/student/activity/activity_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    final userId = context.read<AuthProvider>().usuario?.id;
    if (userId != null) {
      await context.read<StudentProvider>().cargarHistorial(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Actividad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Actualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todo'),
            Tab(text: 'Likes'),
            Tab(text: 'Descartados'),
          ],
        ),
      ),
      body: Consumer<StudentProvider>(
        builder: (_, p, __) {
          if (p.cargandoHistorial && p.historial.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final todo     = List<Map<String, dynamic>>.from(p.historial);
          final likes    = todo.where((h) => h['tipo'] == 'like').toList();
          final dislikes = todo.where((h) => h['tipo'] == 'dislike').toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLista(context, todo, p),
                _buildLista(context, likes, p),
                _buildLista(context, dislikes, p),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLista(BuildContext context,
      List<Map<String, dynamic>> lista, StudentProvider p) {
    if (lista.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 400,
            child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('Sin actividad aún',
                    style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('Explora vacantes para ver tu historial aquí',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                    textAlign: TextAlign.center),
              ],
            )),
          ),
        ],
      );
    }

    final grupos = _agrupar(lista);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grupos.length,
      itemBuilder: (_, i) {
        final g     = grupos[i];
        final items = g['items'] as List<Map<String, dynamic>>;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 12),
            child: Text(g['fecha'] as String,
                style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
          ),
          ...items.map((item) => _buildItem(context, item, lista.indexOf(item), p)),
          const SizedBox(height: 8),
        ]);
      },
    );
  }

  Widget _buildItem(BuildContext context, Map<String, dynamic> item,
      int idx, StudentProvider p) {
    final tipo    = item['tipo'] as String? ?? 'dislike';
    final titulo  = item['titulo'] as String? ?? 'Vacante';
    final ts      = item['timestamp'] as String? ?? '';
    final esMatch = item['match'] == true;
    final isLike  = tipo == 'like';
    final totalViz = item['total_visualizaciones'] as int?;

    Color   color;
    IconData icon;
    String  subtitulo;

    if (isLike && esMatch) {
      color     = AppColors.accentGreen;
      icon      = Icons.favorite;
      subtitulo = '¡Match! 🎉';
    } else if (isLike) {
      color     = AppColors.primaryPurple;
      icon      = Icons.thumb_up_outlined;
      subtitulo = 'Le diste like';
    } else {
      color     = AppColors.error;
      icon      = Icons.close;
      subtitulo = 'Descartaste esta vacante';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: esMatch
            ? Border.all(color: AppColors.accentGreen.withOpacity(0.4), width: 1.5)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header del item ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.w600)),
              Row(children: [
                Text(subtitulo, style: AppTextStyles.bodySmall.copyWith(
                    color: esMatch ? AppColors.accentGreen : AppColors.textSecondary)),
                if (totalViz != null && totalViz > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.visibility_outlined, size: 12,
                      color: AppColors.textTertiary),
                  const SizedBox(width: 2),
                  Text('$totalViz', style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
                ],
              ]),
            ])),
            // Chips de modalidad/ubicación
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (ts.isNotEmpty)
                Text(_formatHora(ts), style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary)),
              if ((item['modalidad'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _chipMini(Icons.work_outline,
                      _lModal(item['modalidad']!), AppColors.primaryPurple),
                ),
            ]),
          ]),
        ),

        // ── Botones de acción ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _showVacanteDetails(context, item),
              icon: const Icon(Icons.visibility_outlined, size: 15),
              label: const Text('Ver oferta'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            )),
            const SizedBox(width: 8),
            if (!isLike)
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _cambiarOpinion(context, idx),
                icon: const Icon(Icons.favorite_outline, size: 15),
                label: const Text('Me interesa'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: AppColors.primaryPurple,
                ),
              )),
            if (isLike && !esMatch)
              Expanded(child: OutlinedButton.icon(
                onPressed: () => p.deshacerLike(idx),
                icon: const Icon(Icons.close, size: 15, color: AppColors.error),
                label: const Text('Deshacer',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: const BorderSide(color: AppColors.error),
                ),
              )),
          ]),
        ),
      ]),
    );
  }

  // ── Ver detalles de la vacante ────────────────────────────────────────────
  void _showVacanteDetails(BuildContext context, Map<String, dynamic> v) {
    final titulo   = v['titulo']      as String? ?? 'Vacante';
    final desc     = v['descripcion'] as String? ?? '';
    final requi    = v['requisitos']  as String? ?? '';
    final minS     = v['sueldo_minimo'];
    final maxS     = v['sueldo_maximo'];
    final moneda   = v['moneda']      as String? ?? 'MXN';
    final modalidad = v['modalidad']  as String? ?? '';
    final ubicacion = v['ubicacion']  as String? ?? '';
    String salario  = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    // Stats del servidor
    final totalViz   = v['total_visualizaciones']    as int?;
    final leDioLike  = v['le_dio_like']              as bool? ?? false;
    final fechaLike  = v['fecha_like']               as String?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),
            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // Header
                Row(children: [
                  Container(width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.business,
                        color: AppColors.primaryPurple)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(titulo, style: AppTextStyles.h4)),
                ]),
                const SizedBox(height: 16),

                // Chips
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (modalidad.isNotEmpty) _chip(Icons.work_outline,
                      _lModal(modalidad), AppColors.primaryPurple),
                  if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined,
                      ubicacion, AppColors.accentBlue),
                  if (salario.isNotEmpty)   _chip(Icons.attach_money,
                      salario, AppColors.accentGreen),
                ]),

                // Stats del servidor
                if (totalViz != null || leDioLike) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      if (totalViz != null) ...[
                        Icon(Icons.visibility_outlined, size: 16,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('$totalViz vista${totalViz == 1 ? '' : 's'}',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary)),
                        const SizedBox(width: 16),
                      ],
                      if (leDioLike) ...[
                        const Icon(Icons.thumb_up_outlined, size: 16,
                            color: AppColors.primaryPurple),
                        const SizedBox(width: 4),
                        Text('Le diste like${fechaLike != null ? ' el ${_formatFechaCorta(fechaLike)}' : ''}',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryPurple)),
                      ],
                    ]),
                  ),
                ],

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
            )),
          ]),
        ),
      ),
    );
  }

  // ── Cambiar opinión ───────────────────────────────────────────────────────
  Future<void> _cambiarOpinion(BuildContext context, int idx) async {
    final p      = context.read<StudentProvider>();
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    final esMatch = await p.cambiarOpinion(userId, idx);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(esMatch ? '¡Es un match! 🎉' : '¡Cambiado a "Me interesa"!'),
      backgroundColor: esMatch ? AppColors.accentGreen : AppColors.primaryPurple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _chipMini(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color), const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );

  List<Map<String, dynamic>> _agrupar(List<Map<String, dynamic>> lista) {
    final Map<String, List<Map<String, dynamic>>> mapa = {};
    for (final item in lista) {
      final ts  = item['timestamp'] as String? ?? '';
      String key;
      try {
        final d   = DateTime.parse(ts).toLocal();
        final now = DateTime.now();
        final hoy = DateTime(now.year, now.month, now.day);
        final dia = DateTime(d.year, d.month, d.day);
        if (dia == hoy)
          key = 'Hoy';
        else if (dia == hoy.subtract(const Duration(days: 1)))
          key = 'Ayer';
        else {
          const m = ['ene','feb','mar','abr','may','jun',
                     'jul','ago','sep','oct','nov','dic'];
          key = '${d.day} de ${m[d.month - 1]}';
        }
      } catch (_) { key = 'Sin fecha'; }
      mapa.putIfAbsent(key, () => []).add(item);
    }
    return mapa.entries.map((e) => {'fecha': e.key, 'items': e.value}).toList();
  }

  String _formatHora(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  String _formatFechaCorta(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} de ${m[d.month - 1]}';
    } catch (_) { return ts; }
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