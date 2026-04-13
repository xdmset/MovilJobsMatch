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
    if (userId != null) await context.read<StudentProvider>().cargarHistorial(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Consumer<StudentProvider>(builder: (_, p, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actividad'),
            Text('${p.historial.length} vacantes revisadas',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary)),
          ],
        )),
        actions: [
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: _refresh, tooltip: 'Actualizar'),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Consumer<StudentProvider>(builder: (_, p, __) =>
                Tab(text: 'Todo (${p.historial.length})')),
            Consumer<StudentProvider>(builder: (_, p, __) {
              final likes = p.historial.where((h) => h['tipo'] == 'like').length;
              return Tab(text: '❤️ Gustaron ($likes)');
            }),
            Consumer<StudentProvider>(builder: (_, p, __) {
              final dislikes = p.historial.where((h) => h['tipo'] == 'dislike').length;
              return Tab(text: '✕ Pasé ($dislikes)');
            }),
          ],
        ),
      ),
      body: Consumer<StudentProvider>(
        builder: (_, p, __) {
          if (p.cargandoHistorial && p.historial.isEmpty)
            return const Center(child: CircularProgressIndicator());

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
      return ListView(children: [
        SizedBox(height: 420, child: Center(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history, size: 52,
                  color: AppColors.textTertiary)),
            const SizedBox(height: 20),
            Text('Sin actividad aún', style: AppTextStyles.h4.copyWith(
                color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Explora vacantes para ver tu historial aquí',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary),
                textAlign: TextAlign.center),
          ]),
        ))),
      ]);
    }

    final grupos = _agrupar(lista);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: grupos.length,
      itemBuilder: (_, i) {
        final g     = grupos[i];
        final items = g['items'] as List<Map<String, dynamic>>;
        final startIdx = lista.indexWhere((x) => x == items.first);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Separador de fecha
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(g['fecha'] as String,
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryPurple)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(
                  color: AppColors.borderLight, height: 1)),
              const SizedBox(width: 8),
              Text('${items.length} vacante${items.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
            ]),
          ),
          ...items.asMap().entries.map((e) =>
              _buildItem(context, e.value, lista.indexOf(e.value), p)),
        ]);
      },
    );
  }

  Widget _buildItem(BuildContext context, Map<String, dynamic> item,
      int idx, StudentProvider p) {
    final tipo        = item['tipo']        as String? ?? 'dislike';
    final titulo      = item['titulo']      as String? ?? 'Vacante';
    final descripcion = item['descripcion'] as String? ?? '';
    final modalidad   = item['modalidad']   as String? ?? '';
    final ubicacion   = item['ubicacion']   as String? ?? '';
    final minS        = item['sueldo_minimo'];
    final maxS        = item['sueldo_maximo'];
    final moneda      = item['moneda']      as String? ?? 'MXN';
    final contrato    = item['tipo_contrato'] as String? ?? '';
    final ts          = item['timestamp']   as String? ?? '';
    final esMatch     = item['match'] == true;
    final isLike      = tipo == 'like';
    final totalViz    = item['total_visualizaciones'] as int?;
    final sector      = item['sector']      as String?
                     ?? item['tipo_empresa'] as String? ?? '';

    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    Color   accentColor;
    IconData accentIcon;
    String  estadoLabel;
    Color   bgColor;

    if (isLike && esMatch) {
      accentColor = AppColors.accentGreen;
      accentIcon  = Icons.favorite;
      estadoLabel = '¡Match! 🎉';
      bgColor     = AppColors.accentGreen.withOpacity(0.05);
    } else if (isLike) {
      accentColor = AppColors.primaryPurple;
      accentIcon  = Icons.thumb_up;
      estadoLabel = 'Te gustó';
      bgColor     = AppColors.primaryPurple.withOpacity(0.04);
    } else {
      accentColor = AppColors.textTertiary;
      accentIcon  = Icons.close;
      estadoLabel = 'Pasaste';
      bgColor     = Colors.transparent;
    }

    return GestureDetector(
      onTap: () => _showDetalles(context, item, idx, p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bgColor == Colors.transparent
              ? Theme.of(context).cardColor : bgColor,
          borderRadius: BorderRadius.circular(16),
          border: esMatch
              ? Border.all(color: AppColors.accentGreen.withOpacity(0.4), width: 1.5)
              : Border.all(color: AppColors.borderLight.withOpacity(0.5)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header con estado ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(accentIcon, size: 13, color: accentColor),
              const SizedBox(width: 6),
              Text(estadoLabel, style: TextStyle(
                  fontSize: 12, color: accentColor,
                  fontWeight: FontWeight.bold)),
              const Spacer(),
              if (ts.isNotEmpty)
                Text(_formatHora(ts), style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary, fontSize: 11)),
              if (totalViz != null && totalViz > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.visibility_outlined, size: 11,
                    color: AppColors.textTertiary),
                const SizedBox(width: 2),
                Text('$totalViz', style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary, fontSize: 11)),
              ],
            ]),
          ),

          // ── Cuerpo ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Logo empresa
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isLike
                      ? accentColor.withOpacity(0.12)
                      : AppColors.textTertiary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLike ? Icons.business : Icons.business_outlined,
                  color: isLike ? accentColor : AppColors.textTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLike ? null : AppColors.textSecondary)),
                if (sector.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sector, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
                ],
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (modalidad.isNotEmpty) _chipMini(
                      Icons.work_outline, _lModal(modalidad),
                      isLike ? accentColor : AppColors.textTertiary),
                  if (ubicacion.isNotEmpty) _chipMini(
                      Icons.location_on_outlined, ubicacion,
                      AppColors.accentBlue.withOpacity(isLike ? 1.0 : 0.5)),
                  if (salario.isNotEmpty) _chipMini(
                      Icons.attach_money, salario,
                      AppColors.accentGreen.withOpacity(isLike ? 1.0 : 0.5)),
                ]),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(descripcion,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary, height: 1.4)),
                ],
              ])),

              // Flecha ver más
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18,
                  color: AppColors.textTertiary),
            ]),
          ),

          // ── Acciones rápidas ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              // LIKE sin match → botón descartar
              if (isLike && !esMatch)
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _descartar(context, idx),
                  icon: const Icon(Icons.close, size: 14, color: AppColors.error),
                  label: const Text('Descartar',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                )),
              // MATCH → label informativo
              if (esMatch)
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle, size: 14,
                        color: AppColors.accentGreen),
                    SizedBox(width: 4),
                    Text('¡Match activo!', style: TextStyle(
                        fontSize: 12, color: AppColors.accentGreen,
                        fontWeight: FontWeight.w600)),
                  ]),
                )),
              // DISLIKE → botón me interesa
              if (!isLike) ...[
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _cambiarALike(context, idx, p),
                  icon: const Icon(Icons.favorite_outline, size: 14),
                  label: const Text('Me interesa', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                )),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Detalle completo al tocar una card ────────────────────────────────────
  void _showDetalles(BuildContext context, Map<String, dynamic> v,
      int idx, StudentProvider p) {
    final titulo      = v['titulo']        as String? ?? 'Vacante';
    final desc        = v['descripcion']   as String? ?? '';
    final requi       = v['requisitos']    as String? ?? '';
    final modalidad   = v['modalidad']     as String? ?? '';
    final ubicacion   = v['ubicacion']     as String? ?? '';
    final minS        = v['sueldo_minimo'];
    final maxS        = v['sueldo_maximo'];
    final moneda      = v['moneda']        as String? ?? 'MXN';
    final contrato    = v['tipo_contrato'] as String? ?? '';
    final sector      = v['sector']        as String?
                     ?? v['tipo_empresa']  as String? ?? '';
    final isLike      = (v['tipo'] == 'like') || (v['le_dio_like'] == true);
    final esMatch     = v['match'] == true;
    final totalViz    = v['total_visualizaciones'] as int?;
    final primeraViz  = v['primera_visualizacion'] as String? ?? '';

    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    Color accentColor = isLike
        ? (esMatch ? AppColors.accentGreen : AppColors.primaryPurple)
        : AppColors.textTertiary;
    String estadoLabel = esMatch ? '¡Match! 🎉'
        : isLike ? 'Te gustó esta vacante' : 'Pasaste esta vacante';

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
        builder: (__, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Container(width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: isLike ? AppColors.purpleGradient : null,
                    color: isLike ? null
                        : AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.business,
                      color: isLike ? Colors.white : AppColors.textTertiary,
                      size: 26)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.bold)),
                  if (sector.isNotEmpty)
                    Text(sector, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(estadoLabel, style: TextStyle(
                        fontSize: 11, color: accentColor,
                        fontWeight: FontWeight.bold)),
                  ),
                ])),
              ]),
            ),
            const Divider(height: 20),

            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                // Chips info
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (modalidad.isNotEmpty) _chip(Icons.work_outline,
                      _lModal(modalidad), AppColors.primaryPurple),
                  if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined,
                      ubicacion, AppColors.accentBlue),
                  if (salario.isNotEmpty) _chip(Icons.attach_money,
                      salario, AppColors.accentGreen),
                  if (contrato.isNotEmpty) _chip(Icons.badge_outlined,
                      contrato, AppColors.textSecondary),
                ]),
                const SizedBox(height: 16),

                // Stats de visualización
                if (totalViz != null || primeraViz.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      if (totalViz != null) ...[
                        const Icon(Icons.visibility_outlined, size: 14,
                            color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('$totalViz visualizaciones',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary)),
                        const SizedBox(width: 16),
                      ],
                      if (primeraViz.isNotEmpty) ...[
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text('Vista el ${_formatFechaLarga(primeraViz)}',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary)),
                      ],
                    ]),
                  ),
                const SizedBox(height: 16),

                if (desc.isNotEmpty) ...[
                  _sectionTitle('Descripción del puesto'),
                  const SizedBox(height: 8),
                  Text(desc, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 18),
                ],
                if (requi.isNotEmpty) ...[
                  _sectionTitle('Requisitos'),
                  const SizedBox(height: 8),
                  Text(requi, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 18),
                ],

                // ── Acciones al pie del detalle ─────────────────────
                if (!isLike)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _cambiarALike(context, idx, p);
                      },
                      icon: const Icon(Icons.favorite_outline),
                      label: const Text('Me interesa esta vacante'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                if (isLike && !esMatch)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _descartar(context, idx);
                      },
                      icon: const Icon(Icons.close, color: AppColors.error),
                      label: const Text('Descartar',
                          style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────
  void _descartar(BuildContext context, int idx) {
    context.read<StudentProvider>().deshacerLike(idx);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Vacante descartada'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _cambiarALike(BuildContext context, int idx,
      StudentProvider p) async {
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    final esMatch = await p.cambiarOpinion(userId, idx);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(esMatch ? '¡Es un match! 🎉' : '¡Agregado a tus likes!'),
      backgroundColor: esMatch ? AppColors.accentGreen : AppColors.primaryPurple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Widgets helper ────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(t,
      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold));

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

  // ── Agrupación por fecha ──────────────────────────────────────────────────
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
        if (dia == hoy) key = 'Hoy';
        else if (dia == hoy.subtract(const Duration(days: 1))) key = 'Ayer';
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

  String _formatFechaLarga(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} de ${m[d.month-1]}';
    } catch (_) { return ''; }
  }

  String _lModal(String m) {
    switch (m) {
      case 'remoto':     return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido':    return 'Híbrido';
      default: return m.isNotEmpty ? m : 'No especificado';
    }
  }
}