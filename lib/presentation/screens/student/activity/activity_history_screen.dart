// lib/presentation/screens/student/activity/activity_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../../data/repositories/retroalimentacion_repository.dart';

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
    // 5 tabs: Todo / ❤️ Likes / ✕ Pasé / 🎉 Matches / ✗ Rechazados
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarRechazados());
  }

  Future<void> _cargarRechazados() async {
    final userId = context.read<AuthProvider>().usuario?.id;
    if (userId == null) return;
    final p = context.read<StudentProvider>();
    // Solo cargar si aún no hay datos de rechazadas
    if (p.rechazadasPorEmpresa.isEmpty) {
      await p.cargarRechazadoPorEmpresa(userId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final userId = context.read<AuthProvider>().usuario?.id;
    if (userId == null) return;
    final p = context.read<StudentProvider>();
    await Future.wait([
      p.cargarHistorial(userId),
      p.cargarRechazadoPorEmpresa(userId),
    ]);
    await p.cargarMatches(userId);
  }

  // ── Helpers para clasificar items ─────────────────────────────────────────

  /// Un item es "match" si tiene match:true O su id aparece en matches del servidor.
  /// FIX: los matches tienen el vacante_id en distintos lugares segun su origen:
  ///   - matchesServidor: { vacante_id: int, vacante: {...} }
  ///   - matchesSesion:   { vacante: { id: int, ... } }
  bool _esMatch(Map<String, dynamic> item, StudentProvider p) {
    if (item['match'] == true) return true;
    final vacanteId = item['id'] as int?;
    if (vacanteId == null) return false;
    return p.matches.any((m) {
      // Caso 1: vacante_id directo (matchesServidor)
      final mid = m['vacante_id'] as int?;
      if (mid != null && mid == vacanteId) return true;
      // Caso 2: id dentro de vacante anidado (matchesSesion)
      final vacante = m['vacante'] as Map<String, dynamic>?;
      final vid = vacante?['id'] as int? ?? vacante?['vacante_id'] as int?;
      return vid == vacanteId;
    });
  }

  /// Un item fue "rechazado por empresa" si aparece en rechazadasPorEmpresa del provider.
  /// También detecta rechazos por estado de la vacante como fallback.
  bool _esRechazado(Map<String, dynamic> item, StudentProvider p) {
    // Si hay match, no es rechazo
    if (_esMatch(item, p)) return false;
    // Si el estudiante no dio like, tampoco es rechazo (es solo dislike)
    final leDioLike = item['le_dio_like'] as bool? ?? (item['tipo'] == 'like');
    if (!leDioLike) return false;

    final vacanteId = item['id'] as int?;

    // Fuente 1: aparece en la lista de rechazadasPorEmpresa (más fiable)
    if (vacanteId != null) {
      final enRechazadas = p.rechazadasPorEmpresa.any(
        (r) => (r['id'] as int?) == vacanteId,
      );
      if (enRechazadas) return true;
    }

    // Fuente 2: estado_interaccion del propio item (de la API de interacciones)
    final estadoInteraccion = (item['estado_interaccion'] as String? ?? '').toLowerCase();
    if (estadoInteraccion == 'rechazado' ||
        estadoInteraccion == 'rechazado_por_empresa') return true;

    // Fuente 3 (fallback): vacante cerrada/inactiva
    final estadoVacante = (item['estado'] as String? ?? '').toLowerCase();
    return estadoVacante == 'cerrada' || estadoVacante == 'inactiva' || estadoVacante == 'archivada';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentProvider>(builder: (context, p, _) {
      // Clasificar listas
      final todo      = List<Map<String, dynamic>>.from(p.historial);
      final likes     = todo.where((h) => (h['tipo'] == 'like') && !_esMatch(h, p) && !_esRechazado(h, p)).toList();
      final dislikes  = todo.where((h) => h['tipo'] == 'dislike').toList();
      final matches   = todo.where((h) => _esMatch(h, p)).toList();
      final rechazados = todo.where((h) => _esRechazado(h, p)).toList();

      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Actividad'),
              Text('${todo.length} vacantes revisadas',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
            ],
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
                tooltip: 'Actualizar'),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Todo (${todo.length})'),
              Tab(text: '❤️ Likes (${likes.length})'),
              Tab(text: '✕ Pasé (${dislikes.length})'),
              _buildMatchTab(matches.length),
              _buildRechazadoTab(rechazados.length),
            ],
          ),
        ),
        body: p.cargandoHistorial && todo.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLista(context, todo,      p),
                    _buildLista(context, likes,     p),
                    _buildLista(context, dislikes,  p),
                    _buildLista(context, matches,   p, emptyMsg: 'Aún no tienes matches',
                        emptyDesc: 'Cuando una empresa también te dé like, aparecerá aquí 🎉'),
                    _buildLista(context, rechazados, p, emptyMsg: 'Sin rechazos',
                        emptyDesc: 'Las postulaciones rechazadas por la empresa aparecerán aquí'),
                  ],
                ),
              ),
      );
    });
  }

  Widget _buildMatchTab(int count) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🎉 Matches'),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.accentGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    ]),
  );

  Widget _buildRechazadoTab(int count) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('✗ Rechazados'),
      if (count > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    ]),
  );

  // ── Lista con agrupación por fecha ────────────────────────────────────────
  Widget _buildLista(BuildContext context,
      List<Map<String, dynamic>> lista, StudentProvider p, {
        String emptyMsg  = 'Sin actividad aún',
        String emptyDesc = 'Explora vacantes para ver tu historial aquí',
      }) {
    if (lista.isEmpty) {
      return ListView(children: [
        SizedBox(
          height: 420,
          child: Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, size: 52,
                    color: AppColors.textTertiary),
              ),
              const SizedBox(height: 20),
              Text(emptyMsg, style: AppTextStyles.h4.copyWith(
                  color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(emptyDesc,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary),
                  textAlign: TextAlign.center),
            ]),
          )),
        ),
      ]);
    }

    final grupos = _agrupar(lista);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: grupos.length,
      itemBuilder: (_, i) {
        final g     = grupos[i];
        final items = g['items'] as List<Map<String, dynamic>>;
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
              const Expanded(child: Divider(color: AppColors.borderLight, height: 1)),
              const SizedBox(width: 8),
              Text('${items.length} vacante${items.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
            ]),
          ),
          ...items.map((item) =>
              _buildItem(context, item, lista.indexOf(item), p)),
        ]);
      },
    );
  }

  // ── Card de item ─────────────────────────────────────────────────────────
  Widget _buildItem(BuildContext context, Map<String, dynamic> item,
      int idx, StudentProvider p) {
    final tipo          = item['tipo']          as String? ?? 'dislike';
    final titulo        = item['titulo']        as String? ?? 'Vacante';
    final descripcion   = item['descripcion']   as String? ?? '';
    final modalidad     = item['modalidad']     as String? ?? '';
    final ubicacion     = item['ubicacion']     as String? ?? '';
    final minS          = item['sueldo_minimo'];
    final maxS          = item['sueldo_maximo'];
    final moneda        = item['moneda']        as String? ?? 'MXN';
    final ts            = item['timestamp']     as String? ?? '';
    final totalViz      = item['total_visualizaciones'] as int?;
    final empresaNombre = item['empresa_nombre'] as String? ?? '';
    final empresaSector = item['empresa_sector'] as String?
                       ?? item['sector']         as String?
                       ?? item['tipo_empresa']   as String? ?? '';
    final esMatch       = _esMatch(item, p);
    final esRechazado   = _esRechazado(item, p);
    final isLike        = tipo == 'like';

    String salario = '';
    if (minS != null && maxS != null) {
      salario = '\$$minS – \$$maxS $moneda';
    } else if (minS != null)            salario = 'Desde \$$minS $moneda';

    // Colores según estado
    Color    accentColor;
    IconData accentIcon;
    String   estadoLabel;
    Color    bgColor;

    if (esRechazado) {
      accentColor = AppColors.error;
      accentIcon  = Icons.cancel_outlined;
      estadoLabel = 'Rechazado por la empresa';
      bgColor     = AppColors.error.withOpacity(0.04);
    } else if (esMatch) {
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
              : esRechazado
                  ? Border.all(color: AppColors.error.withOpacity(0.3), width: 1.5)
                  : Border.all(color: AppColors.borderLight.withOpacity(0.5)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header estado ────────────────────────────────────────────
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

          // ── Cuerpo ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Logo empresa
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isLike || esMatch
                      ? accentColor.withOpacity(0.12)
                      : AppColors.textTertiary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLike || esMatch ? Icons.business : Icons.business_outlined,
                  color: isLike || esMatch ? accentColor : AppColors.textTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLike ? null : AppColors.textSecondary)),
                if (empresaNombre.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(empresaNombre, style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
                ],
                if (empresaSector.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(empresaSector, style: AppTextStyles.bodySmall.copyWith(
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
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18,
                  color: AppColors.textTertiary),
            ]),
          ),

          // ── Acciones rápidas ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              if (isLike && !esMatch && !esRechazado)
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
              if (esRechazado)
                Expanded(child: GestureDetector(
                  onTap: () => _showRetroActivity(context, item, p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.error),
                      SizedBox(width: 4),
                      Text('Ver feedback', style: TextStyle(
                          fontSize: 12, color: AppColors.error,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
              if (!isLike && !esRechazado) ...[
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _cambiarALike(context, idx, p),
                  icon: const Icon(Icons.favorite_outline, size: 14),
                  label: const Text('Me interesa',
                      style: TextStyle(fontSize: 12)),
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

  // ── Retro sheet para items rechazados ────────────────────────────────────
  void _showRetroActivity(BuildContext context, Map<String, dynamic> item,
      StudentProvider p) {
    final vacanteId = item['id'] as int?;
    // Buscar postulacion_id desde la lista de rechazadasPorEmpresa
    int? postulacionId;
    if (vacanteId != null) {
      final match = p.rechazadasPorEmpresa.firstWhere(
        (r) => (r['id'] as int?) == vacanteId,
        orElse: () => {},
      );
      postulacionId = match['postulacion_id'] as int?;
    }

    if (postulacionId == null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.accentOrange.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.info_outline,
                  color: AppColors.accentOrange, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Sin retroalimentación disponible',
                style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'La empresa rechazó tu solicitud sin postulación formal, '
              'por lo que no hay feedback disponible.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RetroActivitySheet(vacante: item, postulacionId: postulacionId!),
    );
  }

  // ── Bottom sheet de detalles ──────────────────────────────────────────────
  void _showDetalles(BuildContext context, Map<String, dynamic> v,
      int idx, StudentProvider p) {
    final titulo        = v['titulo']         as String? ?? 'Vacante';
    final desc          = v['descripcion']    as String? ?? '';
    final requi         = v['requisitos']     as String? ?? '';
    final modalidad     = v['modalidad']      as String? ?? '';
    final ubicacion     = v['ubicacion']      as String? ?? '';
    final minS          = v['sueldo_minimo'];
    final maxS          = v['sueldo_maximo'];
    final moneda        = v['moneda']         as String? ?? 'MXN';
    final contrato      = v['tipo_contrato']  as String? ?? '';
    final empresaNombre = v['empresa_nombre'] as String?
                       ?? v['empresa']        as String? ?? '';
    final empresaSector = v['empresa_sector'] as String?
                       ?? v['sector']         as String?
                       ?? v['tipo_empresa']   as String? ?? '';
    final empresaDesc   = v['empresa_descripcion'] as String? ?? '';
    final empresaWeb    = v['empresa_sitio_web']   as String? ?? '';
    final empresaUbic   = v['empresa_ubicacion']   as String? ?? '';
    final isLike        = (v['tipo'] == 'like') || (v['le_dio_like'] == true);
    final esMatch       = _esMatch(v, p);
    final esRechazado   = _esRechazado(v, p);
    final totalViz      = v['total_visualizaciones'] as int?;
    final primeraViz    = v['primera_visualizacion'] as String? ?? '';
    final feedback      = v['feedback']       as Map<String, dynamic>?;
    final camposMejora  = v['campos_mejora']  as String?
                       ?? feedback?['campos_mejora'] as String? ?? '';
    final sugerencias   = v['sugerencias_perfil'] as String?
                       ?? feedback?['sugerencias_perfil'] as String? ?? '';

    String salario = '';
    if (minS != null && maxS != null) {
      salario = '\$$minS – \$$maxS $moneda';
    } else if (minS != null)            salario = 'Desde \$$minS $moneda';

    Color accentColor;
    String estadoLabel;
    if (esRechazado) {
      accentColor = AppColors.error;
      estadoLabel = 'Rechazado por la empresa';
    } else if (esMatch) {
      accentColor = AppColors.accentGreen;
      estadoLabel = '¡Match! 🎉';
    } else if (isLike) {
      accentColor = AppColors.primaryPurple;
      estadoLabel = 'Te gustó esta vacante';
    } else {
      accentColor = AppColors.textTertiary;
      estadoLabel = 'Pasaste esta vacante';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (__, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2)),
            ),

            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: (isLike || esMatch) ? AppColors.purpleGradient : null,
                    color: (isLike || esMatch) ? null
                        : AppColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.business,
                      color: (isLike || esMatch) ? Colors.white
                          : AppColors.textTertiary,
                      size: 26)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.bold)),
                  if (empresaNombre.isNotEmpty)
                    Text(empresaNombre,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  if (empresaSector.isNotEmpty)
                    Text(empresaSector, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary)),
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

                // ── Chips de la vacante ───────────────────────────────
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

                // ── Stats visualización ───────────────────────────────
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

                // ── Descripción vacante ───────────────────────────────
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

                // ── Sección empresa ───────────────────────────────────
                if (empresaNombre.isNotEmpty || empresaDesc.isNotEmpty ||
                    empresaWeb.isNotEmpty || empresaUbic.isNotEmpty) ...[
                  _sectionTitle('Sobre la empresa'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.accentBlue.withOpacity(0.15)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Nombre + sector
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.business,
                              color: AppColors.accentBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          if (empresaNombre.isNotEmpty)
                            Text(empresaNombre,
                                style: AppTextStyles.subtitle1.copyWith(
                                    fontWeight: FontWeight.bold)),
                          if (empresaSector.isNotEmpty)
                            Text(empresaSector,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textTertiary)),
                        ])),
                      ]),

                      if (empresaDesc.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(empresaDesc,
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary, height: 1.5)),
                      ],

                      if (empresaUbic.isNotEmpty || empresaWeb.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        if (empresaUbic.isNotEmpty)
                          _empresaInfoRow(
                              Icons.location_on_outlined, empresaUbic),
                        if (empresaWeb.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _empresaInfoRow(
                              Icons.language_outlined, empresaWeb,
                              color: AppColors.accentBlue),
                        ],
                      ],
                    ]),
                  ),
                  const SizedBox(height: 18),
                ],

                // ── Feedback de rechazo ───────────────────────────────
                if (esRechazado && (camposMejora.isNotEmpty || sugerencias.isNotEmpty)) ...[
                  _sectionTitle('Feedback de la empresa'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.2)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Icon(Icons.lightbulb_outline,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Text('Áreas de mejora',
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error)),
                      ]),
                      if (camposMejora.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(camposMejora,
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary, height: 1.5)),
                      ],
                      if (sugerencias.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.tips_and_updates_outlined,
                              color: AppColors.accentBlue, size: 18),
                          const SizedBox(width: 8),
                          Text('Sugerencias de perfil',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentBlue)),
                        ]),
                        const SizedBox(height: 8),
                        Text(sugerencias,
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary, height: 1.5)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 18),
                ],

                // ── Acciones al pie ───────────────────────────────────
                if (!isLike && !esRechazado)
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
                if (isLike && !esMatch && !esRechazado)
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
                if (esMatch)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Ver postulación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
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
      backgroundColor:
          esMatch ? AppColors.accentGreen : AppColors.primaryPurple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Widgets helper ────────────────────────────────────────────────────────
  Widget _sectionTitle(String t) => Text(t,
      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold));

  Widget _empresaInfoRow(IconData icon, String text, {Color? color}) =>
      Row(children: [
        Icon(icon, size: 14,
            color: color ?? AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(child: Text(text,
            style: AppTextStyles.bodySmall.copyWith(
                color: color ?? AppColors.textSecondary))),
      ]);

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(
          fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _chipMini(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color), const SizedBox(width: 3),
      Text(label, style: TextStyle(
          fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  // ── Agrupación por fecha ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _agrupar(List<Map<String, dynamic>> lista) {
    final Map<String, List<Map<String, dynamic>>> mapa = {};
    for (final item in lista) {
      final ts = item['timestamp'] as String? ?? '';
      String key;
      try {
        final d   = DateTime.parse(ts).toLocal();
        final now = DateTime.now();
        final hoy = DateTime(now.year, now.month, now.day);
        final dia = DateTime(d.year, d.month, d.day);
        if (dia == hoy) {
          key = 'Hoy';
        } else if (dia == hoy.subtract(const Duration(days: 1))) key = 'Ayer';
        else {
          const m = ['ene','feb','mar','abr','may','jun',
                     'jul','ago','sep','oct','nov','dic'];
          key = '${d.day} de ${m[d.month - 1]}';
        }
      } catch (_) { key = 'Sin fecha'; }
      mapa.putIfAbsent(key, () => []).add(item);
    }
    return mapa.entries
        .map((e) => {'fecha': e.key, 'items': e.value})
        .toList();
  }

  String _formatHora(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  String _formatFechaLarga(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} de ${m[d.month - 1]}';
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

// ── Retro sheet reutilizable para activity screen ─────────────────────────────

class _RetroActivitySheet extends StatefulWidget {
  final Map<String, dynamic> vacante;
  final int postulacionId;
  const _RetroActivitySheet({required this.vacante, required this.postulacionId});

  @override
  State<_RetroActivitySheet> createState() => _RetroActivitySheetState();
}

class _RetroActivitySheetState extends State<_RetroActivitySheet> {
  final _retroRepo = RetroalimentacionRepository.instance;
  bool _cargando = true;
  bool _generando = false;
  RetroalimentacionRead? _retro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final retro = await _retroRepo.getRetroalimentacion(widget.postulacionId);
    if (mounted) setState(() { _retro = retro; _cargando = false; });
  }

  Future<void> _generarRoadmap() async {
    debugPrint('[RetroActivitySheet] _generarRoadmap → postulacion=${widget.postulacionId}');
    setState(() => _generando = true);
    final retro = await _retroRepo.generarRoadmap(widget.postulacionId);
    debugPrint('[RetroActivitySheet] generarRoadmap resultado: ${retro == null ? 'null' : 'estado=${retro.roadmapEstado}'}');
    if (mounted) {
      setState(() { _generando = false; if (retro != null) _retro = retro; });
      if (retro != null && retro.roadmapPendiente) {
        debugPrint('[RetroActivitySheet] roadmap pendiente → iniciando polling via _cargar()');
        await _cargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.vacante['titulo'] as String? ?? 'Vacante';
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.97, minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome, color: AppColors.primaryPurple, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Retroalimentación', style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold)),
                Text(titulo, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary)),
              ])),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 20),
          Expanded(child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: _retro == null || !_retro!.tieneContenido
                  ? _buildSinRetro()
                  : _buildConRetro(_retro!),
              ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSinRetro() => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.feedback_outlined, size: 52, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text('Sin retroalimentación aún',
          style: AppTextStyles.subtitle1.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text('La empresa aún no ha dejado feedback para esta postulación.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary, height: 1.5),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _buildConRetro(RetroalimentacionRead retro) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (retro.camposMejora != null && retro.camposMejora!.isNotEmpty) ...[
      _header('Áreas de mejora', Icons.trending_up, AppColors.accentOrange),
      const SizedBox(height: 8),
      _tarjeta(retro.camposMejora!, AppColors.accentOrange),
      const SizedBox(height: 16),
    ],
    if (retro.sugerenciasPerfil != null && retro.sugerenciasPerfil!.isNotEmpty) ...[
      _header('Sugerencias de perfil', Icons.tips_and_updates_outlined, AppColors.accentBlue),
      const SizedBox(height: 8),
      _tarjeta(retro.sugerenciasPerfil!, AppColors.accentBlue),
      const SizedBox(height: 20),
    ],
    if (retro.roadmapListo) ...[
      _header('Plan de acción', Icons.map_outlined, AppColors.primaryPurple),
      const SizedBox(height: 12),
      if (retro.roadmap!.habilidades.isNotEmpty) ...[
        Text('Habilidades clave', style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: retro.roadmap!.habilidades
            .map((h) => _chip(h)).toList()),
        const SizedBox(height: 16),
      ],
      if (retro.roadmap!.acciones.isNotEmpty) ...[
        Text('Acciones recomendadas', style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...retro.roadmap!.acciones.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.accentGreen),
            const SizedBox(width: 8),
            Expanded(child: Text(a, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.4))),
          ]),
        )),
        const SizedBox(height: 16),
      ],
    ],
    if (!retro.roadmapListo && !retro.roadmapPendiente) ...[
      _header('Plan de acción IA', Icons.auto_awesome, AppColors.primaryPurple),
      const SizedBox(height: 12),
      if (retro.roadmapError) ...[
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
          child: const Row(children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Hubo un problema al generar el plan. Puedes intentarlo de nuevo.',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            )),
          ]),
        ),
      ],
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _generando ? null : _generarRoadmap,
          icon: _generando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Icon(retro.roadmapError ? Icons.refresh : Icons.auto_awesome, size: 16),
          label: Text(_generando
              ? 'Generando plan...'
              : retro.roadmapError
                  ? 'Reintentar generación'
                  : 'Generar plan de acción personalizado'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
      const SizedBox(height: 20),
    ],
    if (retro.roadmapPendiente)
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4))),
        child: const Row(children: [
          Icon(Icons.pending_outlined, color: Colors.amber),
          SizedBox(width: 10),
          Expanded(child: Text('El plan de acción está siendo generado. Vuelve en unos momentos.',
              style: TextStyle(color: Colors.amber))),
        ]),
      ),
  ]);

  Widget _header(String titulo, IconData icon, Color color) => Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(titulo, style: AppTextStyles.subtitle1.copyWith(
        fontWeight: FontWeight.bold, color: color)),
  ]);

  Widget _tarjeta(String texto, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Text(texto, style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary, height: 1.5)),
  );

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontSize: 12,
        color: AppColors.primaryPurple, fontWeight: FontWeight.w600)),
  );
}