// lib/presentation/screens/student/applications/applications_screen.dart
//
// FUENTE DE DATOS: GET /vacante/historial/estudiante/{estudiante_id}
// VacanteHistorialEstudiante: { ...vacante, le_dio_like, fecha_like,
//                               primera_visualizacion, ultima_visualizacion,
//                               total_visualizaciones }
//
// El historial del servidor da toda la actividad del estudiante.
// Para ver matches reales: los matches se generan cuando AMBOS dieron like.
// No hay endpoint de matches separado → usamos el historial + los matches
// en memoria de la sesión.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});
  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    // 3 tabs: Matches (ambos dieron like), Likes míos, Rechazados/Sin respuesta
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recargar());
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _recargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) {
      await context.read<StudentProvider>().cargarHistorial(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mis postulaciones'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: _recargar, tooltip: 'Actualizar'),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Matches 🎉'),
            Tab(text: 'Mis likes'),
            Tab(text: 'Descartados'),
          ],
        ),
      ),
      body: Consumer<StudentProvider>(
        builder: (context, p, _) {
          if (p.cargandoHistorial && p.historial.isEmpty)
            return const Center(child: CircularProgressIndicator());

          // Matches de sesión actual (cuando POST /swipes devolvió MatchResponse)
          final matchesSesion = p.matches;

          // Del historial del servidor: solo los que dieron like
          final likes = p.historial
              .where((h) => h['le_dio_like'] == true || h['tipo'] == 'like')
              .toList();

          // Descartados: vistas sin like
          final descartados = p.historial
              .where((h) => h['le_dio_like'] == false && h['tipo'] != 'like')
              .toList();

          // IDs de vacantes con match en sesión
          final matchVacanteIds = matchesSesion
              .map((m) => m['vacante_id'] as int?)
              .whereType<int>()
              .toSet();

          return RefreshIndicator(
            onRefresh: _recargar,
            child: TabBarView(
              controller: _tabs,
              children: [
                // Tab 1: Matches (sesión)
                _buildMatchesTab(context, matchesSesion),
                // Tab 2: Mis likes (del historial servidor)
                _buildLikesTab(context, likes, matchVacanteIds),
                // Tab 3: Descartados
                _buildDescartadosTab(context, descartados),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Tab Matches ───────────────────────────────────────────────────────────
  Widget _buildMatchesTab(BuildContext context,
      List<Map<String, dynamic>> matches) {
    if (matches.isEmpty) return _buildEmpty(
        '¡Aún no tienes matches!',
        'Cuando una empresa también te elija aparecerán aquí. '
        'Sigue dando likes a las vacantes que te interesen.',
        Icons.favorite_border);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (_, i) {
        final match   = matches[i];
        final vacante = match['vacante'] as Map<String, dynamic>? ?? {};
        return _buildMatchCard(context, match, vacante);
      },
    );
  }

  Widget _buildMatchCard(BuildContext context,
      Map<String, dynamic> match, Map<String, dynamic> vacante) {
    final titulo    = vacante['titulo']   as String? ?? 'Vacante';
    final modalidad = vacante['modalidad'] as String? ?? '';
    final ubicacion = vacante['ubicacion'] as String? ?? '';
    final minS      = vacante['sueldo_minimo'];
    final maxS      = vacante['sueldo_maximo'];
    final moneda    = vacante['moneda']   as String? ?? 'MXN';
    final fechaMatch = match['fecha_match'] as String? ?? '';
    String salario  = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.favorite, size: 15, color: AppColors.accentGreen),
            const SizedBox(width: 6),
            Text('¡Match!', style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (fechaMatch.isNotEmpty)
              Text(_formatFecha(fechaMatch), style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.business, color: AppColors.primaryPurple)),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (modalidad.isNotEmpty) _chip(Icons.work_outline,
                  _lModal(modalidad), AppColors.primaryPurple),
              if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined,
                  ubicacion, AppColors.accentBlue),
              if (salario.isNotEmpty) _chip(Icons.attach_money,
                  salario, AppColors.accentGreen),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => _showDetalles(context, vacante),
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('Ver detalles de la vacante'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
            )),
          ]),
        ),
      ]),
    );
  }

  // ── Tab Mis likes ─────────────────────────────────────────────────────────
  Widget _buildLikesTab(BuildContext context,
      List<Map<String, dynamic>> likes, Set<int> matchIds) {
    if (likes.isEmpty) return _buildEmpty(
        'Aún no has dado like',
        'Las vacantes a las que les des like aparecerán aquí.',
        Icons.thumb_up_outlined);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: likes.length,
      itemBuilder: (_, i) {
        final item     = likes[i];
        final vacanteId = item['id'] as int?;
        final esMatch  = vacanteId != null && matchIds.contains(vacanteId);
        return _buildHistorialCard(context, item, esMatch: esMatch);
      },
    );
  }

  // ── Tab Descartados ───────────────────────────────────────────────────────
  Widget _buildDescartadosTab(BuildContext context,
      List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) return _buildEmpty(
        'Sin vacantes descartadas',
        'Las vacantes que pases aparecerán aquí.',
        Icons.block_outlined);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (_, i) => _buildHistorialCard(context, lista[i],
          esDescartado: true),
    );
  }

  Widget _buildHistorialCard(BuildContext context, Map<String, dynamic> item, {
      bool esMatch = false, bool esDescartado = false}) {
    final titulo    = item['titulo']    as String? ?? 'Vacante';
    final modalidad = item['modalidad'] as String? ?? '';
    final ubicacion = item['ubicacion'] as String? ?? '';
    final ts        = item['timestamp'] ?? item['fecha_like'] ?? item['ultima_visualizacion'] ?? '';
    final totalViz  = item['total_visualizaciones'] as int?;

    Color borderColor = AppColors.borderLight;
    if (esMatch)     borderColor = AppColors.accentGreen;
    if (esDescartado) borderColor = AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: esMatch
            ? Border.all(color: borderColor.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: esMatch
                ? AppColors.accentGreen.withOpacity(0.12)
                : esDescartado
                    ? AppColors.error.withOpacity(0.08)
                    : AppColors.primaryPurple.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            esMatch ? Icons.favorite : esDescartado ? Icons.close : Icons.thumb_up_outlined,
            size: 18,
            color: esMatch ? AppColors.accentGreen
                : esDescartado ? AppColors.error : AppColors.primaryPurple,
          ),
        ),
        title: Text(titulo, style: AppTextStyles.subtitle1.copyWith(
            fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (esMatch) Text('¡Match con esta empresa!',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
          if (!esMatch && !esDescartado) Text('Le diste like',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryPurple)),
          if (esDescartado) Text('La descartaste',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: [
            if (modalidad.isNotEmpty) _chipMini(_lModal(modalidad),
                AppColors.primaryPurple),
            if (ubicacion.isNotEmpty) _chipMini(ubicacion,
                AppColors.accentBlue),
            if (totalViz != null && totalViz > 0)
              _chipMini('$totalViz vistas', AppColors.textTertiary),
          ]),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (ts.toString().isNotEmpty)
            Text(_formatFecha(ts.toString()),
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary, fontSize: 10)),
          const SizedBox(height: 4),
          const Icon(Icons.chevron_right, size: 16,
              color: AppColors.textTertiary),
        ]),
        onTap: () => _showDetalles(context, item),
      ),
    );
  }

  void _showDetalles(BuildContext context, Map<String, dynamic> v) {
    final titulo  = v['titulo']      as String? ?? 'Vacante';
    final desc    = v['descripcion'] as String? ?? '';
    final requi   = v['requisitos']  as String? ?? '';
    final modal   = v['modalidad']   as String? ?? '';
    final ubic    = v['ubicacion']   as String? ?? '';
    final minS    = v['sueldo_minimo'];
    final maxS    = v['sueldo_maximo'];
    final moneda  = v['moneda']      as String? ?? 'MXN';
    String sal    = '';
    if (minS != null && maxS != null) sal = '\$$minS – \$$maxS $moneda';

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),
            Expanded(child: SingleChildScrollView(
              controller: ctrl, padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: AppTextStyles.h3),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (modal.isNotEmpty) _chip(Icons.work_outline,
                      _lModal(modal), AppColors.primaryPurple),
                  if (ubic.isNotEmpty) _chip(Icons.location_on_outlined,
                      ubic, AppColors.accentBlue),
                  if (sal.isNotEmpty) _chip(Icons.attach_money,
                      sal, AppColors.accentGreen),
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
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String sub, IconData icon) =>
    ListView(children: [
      SizedBox(height: 400, child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 72, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub, style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _recargar(),
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ]),
      ))),
    ]);

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

  Widget _chipMini(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 11, color: color,
        fontWeight: FontWeight.w600)),
  );

  String _formatFecha(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month-1]}';
    } catch (_) { return ''; }
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