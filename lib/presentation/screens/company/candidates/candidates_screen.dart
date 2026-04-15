// lib/presentation/screens/company/candidates/candidates_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../home/company_home_screen.dart' show CompanyShellNotifier;

class CandidatesScreen extends StatefulWidget {
  final CompanyShellNotifier notifier;

  const CandidatesScreen({super.key, required this.notifier});

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    // Escuchar cambios en el filtro de vacante
    widget.notifier.vacanteIdFiltro.addListener(_onFiltroChanged);
  }

  void _onFiltroChanged() {
    // Cuando cambia el filtro, ir al tab "Por revisar"
    if (mounted) {
      _tabs.animateTo(0);
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.notifier.vacanteIdFiltro.removeListener(_onFiltroChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) {
      await context.read<CompanyProvider>().recargarCandidatos(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: widget.notifier.vacanteIdFiltro,
      builder: (_, vacanteIdFiltro, __) {
        return ValueListenableBuilder<String?>(
          valueListenable: widget.notifier.vacanteTituloFiltro,
          builder: (_, vacanteTitulo, __) {
            final tieneFiltre = vacanteIdFiltro != null;

            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Consumer<CompanyProvider>(builder: (_, p, __) {
                  // Candidatos visibles según el filtro
                  final feedFiltrado = tieneFiltre
                      ? p.candidatosFeed
                          .where((c) {
                            final cVacId = c['vacante_id'];
                            final cVacInt = cVacId is int
                                ? cVacId
                                : int.tryParse(cVacId?.toString() ?? '');
                            return cVacInt == vacanteIdFiltro;
                          })
                          .toList()
                      : p.candidatosFeed;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tieneFiltre
                          ? 'Candidatos: ${vacanteTitulo ?? ''}'
                          : 'Candidatos',
                          style: AppTextStyles.h4,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '${feedFiltrado.length} por revisar · ${p.matches} matches',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary)),
                    ],
                  );
                }),
                actions: [
                  if (tieneFiltre)
                    TextButton.icon(
                      onPressed: () => widget.notifier.limpiarFiltro(),
                      icon: const Icon(Icons.clear, size: 16,
                          color: AppColors.primaryPurple),
                      label: const Text('Ver todos',
                          style: TextStyle(color: AppColors.primaryPurple)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _recargar,
                    tooltip: 'Actualizar',
                  ),
                ],
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Consumer<CompanyProvider>(builder: (_, p, __) {
                      final count = tieneFiltre
                          ? p.candidatosFeed
                              .where((c) {
                                final cVacId = c['vacante_id'];
                                final cVacInt = cVacId is int
                                    ? cVacId
                                    : int.tryParse(cVacId?.toString() ?? '');
                                return cVacInt == vacanteIdFiltro;
                              })
                              .length
                          : p.candidatosFeed.length;
                      return Tab(text: 'Por revisar ($count)');
                    }),
                    Consumer<CompanyProvider>(builder: (_, p, __) =>
                        Tab(text: 'Matches (${p.matches})')),
                    Consumer<CompanyProvider>(builder: (_, p, __) =>
                        Tab(text: 'Aceptados (${p.aceptados})')),
                    const Tab(text: 'Rechazados'),
                  ],
                ),
              ),
              body: Consumer<CompanyProvider>(builder: (_, p, __) {
                if (p.cargando && p.postulaciones.isEmpty && p.candidatosFeed.isEmpty)
                  return const Center(child: CircularProgressIndicator());

                // Aplicar filtro de vacante al feed
                // FIX: normalizar comparación como int para evitar mismatch String/int
                final feedFiltrado = tieneFiltre
                    ? p.candidatosFeed
                        .where((c) {
                          final cVacId = c['vacante_id'];
                          final cVacInt = cVacId is int
                              ? cVacId
                              : int.tryParse(cVacId?.toString() ?? '');
                          return cVacInt == vacanteIdFiltro;
                        })
                        .toList()
                    : p.candidatosFeed;

                final rechazados = p.postulaciones
                    .where((c) => c['estado'] == 'rechazado').toList();
                final aceptados  = p.postulaciones
                    .where((c) => c['estado'] == 'aceptado').toList();
                final matchesList = p.postulaciones
                    .where((c) => c['estado'] == 'match').toList();

                return RefreshIndicator(
                  onRefresh: _recargar,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildFeedTab(context, feedFiltrado, p),
                      _buildPostulacionesTab(context, matchesList, p,
                          esMatch: true),
                      _buildPostulacionesTab(context, aceptados, p),
                      _buildPostulacionesTab(context, rechazados, p,
                          esRechazado: true),
                    ],
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  // ── Tab: Por revisar (feed de swipes) ─────────────────────────────────────
  Widget _buildFeedTab(BuildContext context,
      List<Map<String, dynamic>> feed, CompanyProvider p) {
    if (feed.isEmpty) {
      return _buildEmpty(
        'Sin candidatos por revisar',
        'Cuando los estudiantes den like a tus vacantes aparecerán aquí.',
        Icons.people_outline,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: feed.length,
      itemBuilder: (_, i) => _buildFeedCard(context, feed[i], p),
    );
  }

  Widget _buildFeedCard(BuildContext context,
      Map<String, dynamic> candidato, CompanyProvider p) {
    final estudianteId = candidato['estudiante_id'] as int?
        ?? candidato['usuario_id'] as int? ?? 0;
    final vacanteId    = candidato['vacante_id'] as int? ?? 0;
    final nombre       = candidato['nombre_completo'] as String?;
    final nivel        = candidato['nivel_academico'] as String? ?? '';
    final institucion  = candidato['institucion_educativa'] as String? ?? '';
    final fotoUrl      = candidato['foto_perfil_url'] as String?;
    final fechaLike    = candidato['fecha_like'] as String? ?? '';

    final vacante    = p.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloV    = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';
    final inicial    = nombre != null && nombre.isNotEmpty
        ? nombre[0].toUpperCase() : 'E';

    return GestureDetector(
      onTap: () => _mostrarPerfil(context, candidato, p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.thumb_up_outlined, size: 14,
                  color: AppColors.primaryPurple),
              const SizedBox(width: 6),
              Expanded(child: Text('Le dio like a: $tituloV',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (fechaLike.isNotEmpty)
                Text(_formatFecha(fechaLike),
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                _avatarCandidato(fotoUrl, inicial, 26),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre ?? 'Candidato #$estudianteId',
                      style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.bold)),
                  if (nivel.isNotEmpty)
                    Text(nivel, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
                  if (institucion.isNotEmpty)
                    Text(institucion, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary, fontSize: 11)),
                ])),
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _rechazar(context, p,
                      estudianteId: estudianteId, vacanteId: vacanteId,
                      nombre: nombre),
                  icon: const Icon(Icons.close, size: 15,
                      color: AppColors.error),
                  label: const Text('Rechazar',
                      style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _aceptar(context, p,
                      estudianteId: estudianteId, vacanteId: vacanteId,
                      nombre: nombre),
                  icon: const Icon(Icons.check, size: 15),
                  label: const Text('Aceptar'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Tab: Postulaciones (matches/aceptados/rechazados) ─────────────────────
  Widget _buildPostulacionesTab(BuildContext context,
      List<Map<String, dynamic>> lista, CompanyProvider p,
      {bool esMatch = false, bool esRechazado = false}) {
    if (lista.isEmpty) {
      final msg = esMatch ? 'Sin matches aún'
          : esRechazado ? 'Sin rechazados' : 'Sin aceptados';
      return _buildEmpty(msg, '', Icons.people_outline);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (_, i) => _buildPostulacionCard(
          context, lista[i], p,
          esMatch: esMatch, esRechazado: esRechazado),
    );
  }

  Widget _buildPostulacionCard(BuildContext context,
      Map<String, dynamic> post, CompanyProvider p,
      {bool esMatch = false, bool esRechazado = false}) {
    final estudianteId = post['estudiante_id'] as int? ?? 0;
    final vacanteId    = post['vacante_id']    as int? ?? 0;
    final estado       = post['estado']        as String? ?? '';
    final fechaStr     = post['fecha_creacion'] as String? ?? '';

    final vacante    = p.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloV    = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';

    // Buscar datos del candidato en el feed para mostrar nombre/foto
    final candidatoData = p.candidatosFeed.firstWhere(
        (c) => (c['estudiante_id'] ?? c['usuario_id']) == estudianteId,
        orElse: () => {});
    final nombre  = candidatoData['nombre_completo'] as String?;
    final fotoUrl = candidatoData['foto_perfil_url'] as String?;
    final inicial = nombre != null && nombre.isNotEmpty
        ? nombre[0].toUpperCase() : 'E';

    Color headerColor = AppColors.textSecondary;
    IconData headerIcon = Icons.pending_outlined;
    String headerLabel = 'Pendiente';

    if (estado == 'match') {
      headerColor = AppColors.accentGreen;
      headerIcon  = Icons.favorite;
      headerLabel = '¡Match!';
    } else if (estado == 'aceptado') {
      headerColor = AppColors.accentBlue;
      headerIcon  = Icons.check_circle;
      headerLabel = 'Aceptado';
    } else if (estado == 'rechazado') {
      headerColor = AppColors.error;
      headerIcon  = Icons.cancel;
      headerLabel = 'Rechazado';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: esMatch ? Border.all(
            color: AppColors.accentGreen.withOpacity(0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: headerColor.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(headerIcon, size: 14, color: headerColor),
            const SizedBox(width: 6),
            Text(headerLabel, style: AppTextStyles.bodySmall.copyWith(
                color: headerColor, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Mostrar vacante en cada postulación
            Flexible(child: Text(tituloV,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (fechaStr.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(_formatFecha(fechaStr),
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary)),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            _avatarCandidato(fotoUrl, inicial, 22),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre ?? 'Candidato #$estudianteId',
                  style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold)),
              Text(tituloV, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
            ])),
            if (esMatch)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.favorite,
                    color: AppColors.accentGreen, size: 18)),
          ]),
        ),
      ]),
    );
  }

  // ── Perfil completo del candidato ─────────────────────────────────────────
  void _mostrarPerfil(BuildContext context,
      Map<String, dynamic> candidato, CompanyProvider p) {
    // empresaId obtenido de auth.usuario?.id ?? 0

    final estudianteId = candidato['estudiante_id'] as int?
        ?? candidato['usuario_id'] as int? ?? 0;
    final vacanteId    = candidato['vacante_id']    as int? ?? 0;
    final nombre       = candidato['nombre_completo'] as String? ?? 'Candidato';
    final nivel        = candidato['nivel_academico'] as String? ?? '';
    final institucion  = candidato['institucion_educativa'] as String? ?? '';
    final ubicacion    = candidato['ubicacion']      as String? ?? '';
    final modalPref    = candidato['modalidad_preferida'] as String? ?? '';
    final habilidades  = candidato['habilidades'];
    final biografia    = candidato['biografia']      as String? ?? '';
    final cvUrl        = candidato['cv_url']         as String?;
    final fotoUrl      = candidato['foto_perfil_url'] as String?;
    final email        = candidato['email']          as String? ?? '';
    final esPremium    = candidato['es_premium']     as bool? ?? false;

    final vacante  = p.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloV  = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';
    final inicial  = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24))),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                _avatarCandidato(fotoUrl, inicial, 32),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(nombre,
                        style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold))),
                    if (esPremium) Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          gradient: AppColors.purpleGradient,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Premium',
                          style: TextStyle(fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  if (nivel.isNotEmpty)
                    Text(nivel, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
                  if (institucion.isNotEmpty)
                    Text(institucion, style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary)),
                ])),
              ]),
            ),

            // Vacante
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.work_outline, size: 14,
                    color: AppColors.primaryPurple),
                const SizedBox(width: 6),
                Expanded(child: Text('Aplicó a: $tituloV',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600))),
              ]),
            ),
            const Divider(height: 20),

            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [

                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (ubicacion.isNotEmpty)
                    _infoChip(Icons.location_on_outlined,
                        ubicacion, AppColors.accentBlue),
                  if (modalPref.isNotEmpty)
                    _infoChip(Icons.work_outline,
                        _lModal(modalPref), AppColors.primaryPurple),
                  if (email.isNotEmpty)
                    _infoChip(Icons.email_outlined,
                        email, AppColors.textSecondary),
                ]),
                const SizedBox(height: 16),

                if (biografia.isNotEmpty) ...[
                  _secTitulo('Sobre mí'),
                  const SizedBox(height: 8),
                  Text(biografia, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 16),
                ],

                if (habilidades != null &&
                    habilidades.toString().isNotEmpty) ...[
                  _secTitulo('Habilidades'),
                  const SizedBox(height: 8),
                  Text(habilidades.toString(),
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 16),
                ],

                if (cvUrl != null && cvUrl.isNotEmpty) ...[
                  _secTitulo('Currículum Vitae'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.tryParse(cvUrl);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accentBlue.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.picture_as_pdf,
                            color: AppColors.accentBlue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Abrir CV del candidato',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.w600))),
                        const Icon(Icons.open_in_new, size: 16,
                            color: AppColors.accentBlue),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _rechazar(context, p,
                          estudianteId: estudianteId,
                          vacanteId: vacanteId);
                    },
                    icon: const Icon(Icons.close, color: AppColors.error),
                    label: const Text('Rechazar',
                        style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _aceptar(context, p,
                          estudianteId: estudianteId,
                          vacanteId: vacanteId,
                          nombre: nombre);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ]),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────
  Future<void> _aceptar(BuildContext context, CompanyProvider p, {
    required int estudianteId, required int vacanteId, String? nombre,
  }) async {
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    final esMatch = await p.swipeEstudiante(
      empresaId: userId, estudianteId: estudianteId,
      vacanteId: vacanteId, interes: true,
    );
    if (!context.mounted) return;
    if (esMatch) {
      showDialog(context: context, builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  shape: BoxShape.circle),
              child: const Icon(Icons.favorite,
                  color: Colors.white, size: 44)),
          const SizedBox(height: 14),
          Text('¡Es un Match! 🎉', style: AppTextStyles.h3,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('${nombre ?? 'El candidato'} también te eligió.',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('¡Excelente!'),
          )),
        ],
      ));
    } else {
      _snack(context, 'Candidato aceptado ✓', AppColors.accentGreen);
    }
  }

  Future<void> _rechazar(BuildContext context, CompanyProvider p, {
    required int estudianteId, required int vacanteId, String? nombre,
  }) async {
    final ok = await showDialog<bool>(context: context, builder: (_) =>
      AlertDialog(
        title: const Text('¿Rechazar candidato?'),
        content: Text(
            '${nombre != null ? '"$nombre"' : 'Este candidato'} '
            'será notificado que no fue seleccionado.'),
        actions: [
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.primaryPurple),
              foregroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancelar'),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Rechazar'),
          )),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    await p.swipeEstudiante(
      empresaId: userId, estudianteId: estudianteId,
      vacanteId: vacanteId, interes: false,
    );
    if (context.mounted) _snack(context, 'Candidato rechazado', AppColors.error);
  }

  void _snack(BuildContext ctx, String msg, Color color) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

  // ── Widgets helper ────────────────────────────────────────────────────────
  Widget _avatarCandidato(String? fotoUrl, String inicial, double radius) {
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(fotoUrl),
        onBackgroundImageError: (_, __) {},
        backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
      child: Text(inicial, style: TextStyle(
          color: AppColors.primaryPurple,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.65)),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _secTitulo(String t) => Text(t,
      style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold));

  Widget _buildEmpty(String title, String sub, IconData icon) =>
    ListView(children: [
      SizedBox(height: 400, child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 72, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.h4.copyWith(
              color: AppColors.textSecondary), textAlign: TextAlign.center),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(sub, style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary), textAlign: TextAlign.center),
          ],
        ]),
      ))),
    ]);

  String _formatFecha(String ts) {
    try {
      final d = DateTime.parse(ts).toLocal();
      const m = ['ene','feb','mar','abr','may','jun',
                  'jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${m[d.month-1]}';
    } catch (_) { return ''; }
  }

  String _lModal(String m) {
    switch (m.toLowerCase()) {
      case 'remoto':     return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido':    return 'Híbrido';
      default:           return m;
    }
  }
}