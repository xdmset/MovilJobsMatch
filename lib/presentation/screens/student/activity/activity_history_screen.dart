// lib/presentation/screens/student/activity/activity_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Actividad'),
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
          final todo      = p.historial;
          final likes     = todo.where((h) => h['tipo'] == 'like').toList();
          final dislikes  = todo.where((h) => h['tipo'] == 'dislike').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLista(context, todo),
              _buildLista(context, likes),
              _buildLista(context, dislikes),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLista(BuildContext context, List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text('Sin actividad aún', style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Empieza a explorar vacantes para ver tu historial aquí',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center),
        ],
      ));
    }

    final grupos = _agrupar(lista);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grupos.length,
      itemBuilder: (_, i) {
        final g = grupos[i];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 12),
            child: Text(g['fecha'] as String,
                style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
          ),
          ...(g['items'] as List<Map<String, dynamic>>)
              .map((item) => _buildItem(context, item)),
          const SizedBox(height: 8),
        ]);
      },
    );
  }

  Widget _buildItem(BuildContext context, Map<String, dynamic> item) {
    final tipo    = item['tipo'] as String? ?? 'like';
    final titulo  = item['titulo'] as String? ?? 'Vacante';
    final ts      = item['timestamp'] as String? ?? '';
    final esMatch = item['match'] == true;
    final isLike  = tipo == 'like';

    Color color;
    IconData icon;
    String subtitulo;

    if (isLike && esMatch) {
      color     = AppColors.accentGreen;
      icon      = Icons.favorite;
      subtitulo = '¡Match conseguido! 🎉';
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(titulo, style: AppTextStyles.subtitle1.copyWith(
            fontWeight: FontWeight.w600)),
        subtitle: Text(subtitulo, style: AppTextStyles.bodySmall.copyWith(
            color: esMatch ? AppColors.accentGreen : AppColors.textSecondary)),
        trailing: ts.isNotEmpty
            ? Text(_formatHora(ts), style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary))
            : null,
        onTap: esMatch ? () => _showMatchDetails(context, item) : null,
      ),
    );
  }

  void _showMatchDetails(BuildContext context, Map<String, dynamic> item) {
    final titulo    = item['titulo'] as String? ?? 'Vacante';
    final modalidad = item['modalidad'] as String? ?? '';
    final ubicacion = item['ubicacion'] as String? ?? '';
    final desc      = item['descripcion'] as String? ?? '';
    final ts        = item['timestamp'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.purpleGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('¡Es un match!', style: AppTextStyles.h4.copyWith(
                  color: AppColors.accentGreen)),
              Text(titulo, style: AppTextStyles.bodyMedium),
            ])),
          ]),
          const SizedBox(height: 20),
          if (modalidad.isNotEmpty || ubicacion.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (modalidad.isNotEmpty) _chipSmall(Icons.work_outline, _lModal(modalidad),
                  AppColors.primaryPurple),
              if (ubicacion.isNotEmpty) _chipSmall(Icons.location_on_outlined,
                  ubicacion, AppColors.accentBlue),
            ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(desc, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.5),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if (ts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Match el ${_formatFechaLarga(ts)}',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary)),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _chipSmall(IconData icon, String label, Color color) => Container(
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

  String _formatFechaLarga(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const meses = ['enero','febrero','marzo','abril','mayo','junio',
                     'julio','agosto','septiembre','octubre','noviembre','diciembre'];
      return '${d.day} de ${meses[d.month - 1]}, ${d.year}';
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