// lib/presentation/screens/company/candidates/candidates_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../home/company_home_screen.dart' show CompanyShellNotifier;
import '../../../../data/repositories/retroalimentacion_repository.dart';

class CandidatesScreen extends StatefulWidget {
  final CompanyShellNotifier notifier;

  const CandidatesScreen({super.key, required this.notifier});

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _rechazados = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    widget.notifier.vacanteIdFiltro.addListener(_onFiltroChanged);
  }

  void _onFiltroChanged() {
    if (mounted) {
      _tabs.animateTo(0);
      setState(() {});
      _recargar();
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
      final vacanteIdFiltro = widget.notifier.vacanteIdFiltro.value;
      final p = context.read<CompanyProvider>();
      await p.recargarCandidatos(id, vacanteId: vacanteIdFiltro);

      // Cargar rechazados desde el endpoint de estado (que trae perfil_estudiante)
      final rechazadosList = await p.cargarRechazados(id);
      setState(() => _rechazados = rechazadosList);
    }
  }

  // ── Normalización de tipos ─────────────────────────────────────────────────
  // El JSON puede deserializar los IDs como int o String dependiendo del endpoint.
  // Siempre comparar como int para evitar mismatch.
  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  bool _matchesVacante(Map<String, dynamic> item, int? vacanteIdFiltro) {
    if (vacanteIdFiltro == null) return true;
    return _toInt(item['vacante_id']) == vacanteIdFiltro;
  }

  List<Map<String, dynamic>> _filtrarPorVacante(
    Iterable<Map<String, dynamic>> items,
    int? vacanteIdFiltro,
  ) {
    return items.where((item) => _matchesVacante(item, vacanteIdFiltro)).toList();
  }

  // ── BUG 1 FIX: estados del API ─────────────────────────────────────────────
  // El backend devuelve: "pendiente" | "aceptada" | "rechazada" | "entrevista"
  // Los matches son postulaciones con estado "pendiente" que además tienen match_id != null,
  // o bien el provider los marca de otra forma — usar los estados reales del API.
  //
  // Regla:
  //   Matches      → estado == "pendiente" y match_id != null  (o como los marque el provider)
  //   Aceptados    → estado == "aceptada"   (CON 'a' al final)
  //   Rechazados   → estado == "rechazada"  (CON 'a' al final)
  //
  // Si el provider ya normaliza a "match" / "aceptado" / "rechazado" (sin 'a'),
  // se cubre con _esEstado() que acepta ambas formas.
  bool _esEstado(Map<String, dynamic> post, String estadoBuscado) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    // Aceptar tanto "aceptada"/"aceptado", "rechazada"/"rechazado", "match", etc.
    return estado == estadoBuscado ||
        estado == '${estadoBuscado}a' || // masculino → femenino
        estado == estadoBuscado.replaceAll('a', ''); // femenino → masculino
  }

  bool _esMatch(Map<String, dynamic> post) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    if (estado == 'match') return true;
    if (estado == 'enviado') return true; // Nuevo estado del backend para postulaciones creadas
    final matchId = post['match_id'];
    return matchId != null && matchId != 0 && estado == 'pendiente';
  }

  bool _esAceptada(Map<String, dynamic> post) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    return estado == 'aceptada' || estado == 'aceptado' || estado == 'entrevista';
  }

  bool _esRechazada(Map<String, dynamic> post) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    return estado == 'rechazada' || estado == 'rechazado';
  }

  // Empresa aceptó al candidato pero aún está pendiente respuesta del estudiante
  bool _esPendienteAceptadoPorEmpresa(Map<String, dynamic> post) {
    final estado = (post['estado'] as String? ?? '').toLowerCase().trim();
    if (estado != 'pendiente') return false;
    // Si tiene match_id es un match real, _esMatch lo captura
    final matchId = post['match_id'];
    if (matchId != null && matchId != 0) return false;
    // La empresa aceptó si interes_empresa == true
    final interes = post['interes_empresa'];
    if (interes is bool) return interes;
    return interes?.toString().toLowerCase() == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: widget.notifier.vacanteIdFiltro,
      builder: (_, vacanteIdFiltro, __) {
        return ValueListenableBuilder<String?>(
          valueListenable: widget.notifier.vacanteTituloFiltro,
          builder: (_, vacanteTitulo, __) {
            final tieneFiltro = vacanteIdFiltro != null;

            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Consumer<CompanyProvider>(builder: (_, p, __) {
                  final feedFiltrado = _filtrarPorVacante(
                    p.candidatosFeed,
                    vacanteIdFiltro,
                  );
                  final favoritosFiltrado = _filtrarPorVacante(
                    p.postulaciones.where((post) => _esMatch(post) || _esAceptada(post) || _esPendienteAceptadoPorEmpresa(post)),
                    vacanteIdFiltro,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Candidatos',
                          style: AppTextStyles.h4,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '${feedFiltrado.length} por revisar · ${favoritosFiltrado.length} favoritos',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary)),
                    ],
                  );
                }),
                actions: [
                  if (tieneFiltro)
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
                      final count = _filtrarPorVacante(
                        p.candidatosFeed,
                        vacanteIdFiltro,
                      ).length;
                      return Tab(text: 'Por revisar ($count)');
                    }),
                    Consumer<CompanyProvider>(builder: (_, p, __) {
                      final count = _filtrarPorVacante(
                        p.postulaciones.where((post) => _esMatch(post) || _esAceptada(post) || _esPendienteAceptadoPorEmpresa(post)),
                        vacanteIdFiltro,
                      ).length;
                      return Tab(text: 'Candidatos favoritos ($count)');
                    }),
                    Consumer<CompanyProvider>(builder: (_, p, __) {
                      final count = _filtrarPorVacante(_rechazados, vacanteIdFiltro).length;
                      return Tab(text: 'Rechazados ($count)');
                    }),
                  ],
                ),
              ),
              body: Consumer<CompanyProvider>(builder: (_, p, __) {
                if (p.cargando && p.postulaciones.isEmpty && p.candidatosFeed.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final feedFiltrado = _filtrarPorVacante(
                  p.candidatosFeed,
                  vacanteIdFiltro,
                );

                final rechazados = _filtrarPorVacante(_rechazados, vacanteIdFiltro);

                final favoritosFiltrado = _filtrarPorVacante(
                  p.postulaciones.where((post) => _esMatch(post) || _esAceptada(post) || _esPendienteAceptadoPorEmpresa(post)),
                  vacanteIdFiltro,
                );

                return RefreshIndicator(
                  onRefresh: _recargar,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildFeedTab(context, feedFiltrado, p),
                      _buildPostulacionesTab(context, favoritosFiltrado, p),
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
    final estudianteId = _toInt(post['estudiante_id']) ?? 0;
    final vacanteId    = _toInt(post['vacante_id']) ?? 0;
    final estado       = post['estado'] as String? ?? '';
    final fechaStr     = post['fecha_creacion'] as String? ?? '';

    final vacante    = p.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloV    = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';

    // Para rechazados, los datos vienen en perfil_estudiante anidado
    final perfilAnidado = post['perfil_estudiante'] as Map<String, dynamic>?;
    final candidatoData = p.candidatosFeed.firstWhere(
        (c) => _toInt(c['estudiante_id'] ?? c['usuario_id']) == estudianteId &&
            _toInt(c['vacante_id']) == vacanteId,
        orElse: () => {});

    final nombre   = post['nombre_completo'] as String?
        ?? perfilAnidado?['nombre_completo'] as String?
        ?? candidatoData['nombre_completo'] as String?;
    final fotoUrl  = post['foto_perfil_url'] as String?
        ?? perfilAnidado?['foto_perfil_url'] as String?
        ?? candidatoData['foto_perfil_url'] as String?;
    final nivel      = post['nivel_academico'] as String?
        ?? perfilAnidado?['nivel_academico'] as String?
        ?? candidatoData['nivel_academico'] as String? ?? '';
    final institucion = post['institucion_educativa'] as String?
        ?? perfilAnidado?['institucion_educativa'] as String?
        ?? candidatoData['institucion_educativa'] as String? ?? '';
    final email    = post['email'] as String?
        ?? perfilAnidado?['email'] as String?
        ?? candidatoData['email'] as String? ?? '';
    final cvUrl    = post['cv_url'] as String?
        ?? perfilAnidado?['cv_url'] as String?
        ?? candidatoData['cv_url'] as String?;
    final inicial  = nombre != null && nombre.isNotEmpty
        ? nombre[0].toUpperCase() : 'E';

    Color headerColor = AppColors.textSecondary;
    IconData headerIcon = Icons.pending_outlined;
    String headerLabel = 'Pendiente';

    final estadoNorm = estado.toLowerCase().trim();
    if (_esMatch(post)) {
      headerColor = AppColors.accentGreen;
      headerIcon  = Icons.favorite;
      headerLabel = 'Match';
    } else if (estadoNorm == 'aceptada' || estadoNorm == 'aceptado') {
      headerColor = AppColors.accentBlue;
      headerIcon  = Icons.check_circle;
      headerLabel = 'Aceptado';
    } else if (estadoNorm == 'rechazada' || estadoNorm == 'rechazado') {
      headerColor = AppColors.error;
      headerIcon  = Icons.cancel;
      headerLabel = 'Rechazado';
    } else if (estadoNorm == 'entrevista') {
      headerColor = AppColors.accentOrange;
      headerIcon  = Icons.event_outlined;
      headerLabel = 'Entrevista';
    }

    // Mapa enriquecido para pasar al sheet de perfil
    final candidatoEnriquecido = {
      ...candidatoData,
      if (perfilAnidado != null) ...perfilAnidado,
      ...post,
      'estudiante_id': estudianteId,
      'vacante_id': vacanteId,
    };

    return GestureDetector(
      onTap: () => _mostrarPerfil(context, candidatoEnriquecido, p, soloVer: true),
      child: Container(
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: [
              Icon(headerIcon, size: 14, color: headerColor),
              const SizedBox(width: 6),
              Text(headerLabel, style: AppTextStyles.bodySmall.copyWith(
                  color: headerColor, fontWeight: FontWeight.bold)),
              const Spacer(),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _avatarCandidato(fotoUrl, inicial, 22),
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
                if (esMatch)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.favorite,
                        color: AppColors.accentGreen, size: 18)),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ]),
              // Chips de info rápida
              if (email.isNotEmpty || cvUrl != null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (email.isNotEmpty)
                    _infoChip(Icons.email_outlined, email, AppColors.textSecondary),
                  if (cvUrl != null && cvUrl.isNotEmpty)
                    _infoChip(Icons.picture_as_pdf, 'CV disponible', AppColors.accentBlue),
                ]),
              ],
              if (esRechazado) ...[
                const SizedBox(height: 10),
                _buildBotonVerFeedback(context, post),
                const SizedBox(height: 8),
                _buildBotonesRechazado(context, post, p, estudianteId, vacanteId, nombre),
              ] else ...[
                const SizedBox(height: 10),
                _buildBotonesFavorito(context, post, p, estudianteId, vacanteId, nombre),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Botones de acción en card de favoritos ────────────────────────────────
  Widget _buildBotonesFavorito(
    BuildContext context, Map<String, dynamic> post,
    CompanyProvider p, int estudianteId, int vacanteId, String? nombre,
  ) {
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('¿Rechazar candidato?'),
              content: Text(
                'Moverás a ${nombre ?? "este candidato"} a rechazados. '
                'Podrás darle feedback desde esa sección.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Rechazar',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          );
          if (confirmar != true || !context.mounted) return;
          debugPrint('[CandidatesScreen] reswipe negativo est=$estudianteId vac=$vacanteId');
          final ok = await p.reswipeCandidato(
            empresaId:    userId,
            estudianteId: estudianteId,
            vacanteId:    vacanteId,
            interes:      false,
          );
          debugPrint('[CandidatesScreen] reswipe negativo resultado: $ok → recargando...');
          if (!context.mounted) return;
          await _recargar();
          debugPrint('[CandidatesScreen] recargar completado tras reswipe negativo');
          if (!context.mounted) return;
          _snack(context, ok ? 'Candidato movido a rechazados' : 'Error al rechazar',
              ok ? AppColors.textSecondary : AppColors.error);
        },
        icon: const Icon(Icons.close, size: 14, color: AppColors.error),
        label: const Text('Rechazar candidato',
            style: TextStyle(color: AppColors.error, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ── Botones de acción en card de rechazados ───────────────────────────────
  Widget _buildBotonesRechazado(
    BuildContext context, Map<String, dynamic> post,
    CompanyProvider p, int estudianteId, int vacanteId, String? nombre,
  ) {
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    return Row(children: [
      // Dar feedback
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _darFeedback(context, p,
            empresaId:    userId,
            estudianteId: estudianteId,
            vacanteId:    vacanteId,
            nombre:       nombre),
        icon: const Icon(Icons.feedback_outlined, size: 14,
            color: AppColors.primaryPurple),
        label: const Text('Dar feedback',
            style: TextStyle(color: AppColors.primaryPurple, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          side: const BorderSide(color: AppColors.primaryPurple),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      )),
      const SizedBox(width: 8),
      // Arrepentirse — dar match
      Expanded(child: ElevatedButton.icon(
        onPressed: () async {
          final confirmar = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('¿Aceptar candidato?'),
              content: Text(
                'Cambiarás el estado de ${nombre ?? "este candidato"} a favorito.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Aceptar',
                      style: TextStyle(color: AppColors.accentGreen)),
                ),
              ],
            ),
          );
          if (confirmar != true || !context.mounted) return;
          debugPrint('[CandidatesScreen] reswipe positivo est=$estudianteId vac=$vacanteId');
          final ok = await p.reswipeCandidato(
            empresaId:    userId,
            estudianteId: estudianteId,
            vacanteId:    vacanteId,
            interes:      true,
          );
          debugPrint('[CandidatesScreen] reswipe positivo resultado: $ok → recargando...');
          if (!context.mounted) return;
          await _recargar();
          debugPrint('[CandidatesScreen] recargar completado tras reswipe positivo');
          if (!context.mounted) return;
          _snack(context,
              ok ? 'Candidato movido a favoritos ✓' : 'Error al aceptar',
              ok ? AppColors.accentGreen : AppColors.error);
        },
        icon: const Icon(Icons.favorite_outline, size: 14),
        label: const Text('Aceptar', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 34),
          backgroundColor: AppColors.accentGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      )),
    ]);
  }

  // ── Dar feedback a candidato rechazado ────────────────────────────────────
  Future<void> _darFeedback(BuildContext context, CompanyProvider p, {
    required int empresaId,
    required int estudianteId,
    required int vacanteId,
    String? nombre,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedbackRechazadoSheet(
        empresaId:    empresaId,
        estudianteId: estudianteId,
        vacanteId:    vacanteId,
        nombre:       nombre,
        provider:     p,
      ),
    );
  }

  // ── Perfil completo del candidato ─────────────────────────────────────────
  // [soloVer] = true → no muestra botones Aceptar/Rechazar (para favoritos/rechazados)
  void _mostrarPerfil(BuildContext context,
      Map<String, dynamic> candidato, CompanyProvider p,
      {bool soloVer = false}) {
    final estudianteId  = candidato['estudiante_id'] as int?
        ?? candidato['usuario_id'] as int? ?? 0;
    final vacanteId     = candidato['vacante_id']    as int? ?? 0;
    final postulacionId = _toInt(candidato['postulacion_id']);
    final nombre        = candidato['nombre_completo'] as String? ?? 'Candidato';
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

                if (!soloVer) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _rechazar(context, p,
                            estudianteId:  estudianteId,
                            vacanteId:     vacanteId,
                            nombre:        nombre,
                            postulacionId: postulacionId);
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
                ],
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
    
    // FIX: Recargar candidatos para sincronizar likes/matches con el servidor
    await p.recargarCandidatos(userId);
    
    if (!context.mounted) return;
    if (esMatch) {
      showDialog(context: context, builder: (_) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  shape: BoxShape.circle),
              child: const Icon(Icons.favorite,
                  color: Colors.white, size: 44)),
          const SizedBox(height: 14),
          const Text('¡Es un Match! 🎉', style: AppTextStyles.h3,
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

  // ── Rechazar — abre el sheet de retroalimentación ─────────────────────────
  Future<void> _rechazar(BuildContext context, CompanyProvider p, {
    required int estudianteId, required int vacanteId, String? nombre,
    int? postulacionId,
  }) async {
    final userId = context.read<AuthProvider>().usuario?.id ?? 0;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RetroalimentacionSheet(
        estudianteId:  estudianteId,
        vacanteId:     vacanteId,
        nombre:        nombre,
        provider:      p,
        userId:        userId,
        postulacionId: postulacionId,
        onRechazado:   (msg) {
          if (context.mounted) _snack(context, msg, AppColors.error);
        },
      ),
    );
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

  // ── Botón "Ver feedback enviado" para tarjetas rechazadas ─────────────────
  // Los items del endpoint /candidatos/estado/rechazados tienen:
  //   { estudiante_id, vacante_id, estado_candidato, perfil_estudiante, ... }
  // pero NO tienen postulacion_id (rechazo por swipe, sin postulación formal).
  // Los items de postulaciones sí tienen 'id' (= postulacion_id).
  Widget _buildBotonVerFeedback(
      BuildContext context, Map<String, dynamic> post) {
    // Los rechazados por swipe siempre tienen 'estado_candidato' y no tienen 'estado'
    final esRechazoPorSwipe = post.containsKey('estado_candidato') &&
        !post.containsKey('estado');

    if (esRechazoPorSwipe) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Rechazado sin postulación — no hay feedback disponible.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
          )),
        ]),
      );
    }

    // Postulación formal: usar post['id'] como postulacion_id
    final postulacionId = _toInt(post['postulacion_id']) ?? _toInt(post['id']);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: postulacionId == null
            ? null
            : () => _mostrarFeedbackEnviado(context, postulacionId),
        icon: const Icon(Icons.feedback_outlined, size: 15,
            color: AppColors.accentOrange),
        label: const Text('Ver feedback enviado',
            style: TextStyle(color: AppColors.accentOrange)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          side: const BorderSide(color: AppColors.accentOrange),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _mostrarFeedbackEnviado(BuildContext context, int postulacionId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedbackEnviadoSheet(postulacionId: postulacionId),
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


// ══════════════════════════════════════════════════════════════════════════════
// Sheet "Ver feedback enviado" — empresa ve el feedback que le mandó al candidato
// ══════════════════════════════════════════════════════════════════════════════
class _FeedbackEnviadoSheet extends StatefulWidget {
  final int postulacionId;
  const _FeedbackEnviadoSheet({required this.postulacionId});

  @override
  State<_FeedbackEnviadoSheet> createState() => _FeedbackEnviadoSheetState();
}

class _FeedbackEnviadoSheetState extends State<_FeedbackEnviadoSheet> {
  final _repo = RetroalimentacionRepository.instance;
  bool _cargando = true;
  RetroalimentacionRead? _retro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final retro = await _repo.getRetroalimentacion(widget.postulacionId);
      if (mounted) setState(() { _retro = retro; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.35,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.feedback_outlined,
                    color: AppColors.accentOrange, size: 18)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Feedback enviado',
                  style: AppTextStyles.h4)),
            ]),
          ),
          const Divider(height: 20),
          Expanded(child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _retro == null
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay feedback registrado para esta postulación.',
                      textAlign: TextAlign.center)))
              : SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (_retro!.camposMejora != null &&
                        _retro!.camposMejora!.isNotEmpty) ...[
                      _seccion('Áreas de mejora indicadas',
                          Icons.trending_up, AppColors.accentOrange),
                      const SizedBox(height: 8),
                      _tarjeta(_retro!.camposMejora!,
                          AppColors.accentOrange),
                      const SizedBox(height: 16),
                    ],
                    if (_retro!.sugerenciasPerfil != null &&
                        _retro!.sugerenciasPerfil!.isNotEmpty) ...[
                      _seccion('Sugerencias de perfil enviadas',
                          Icons.tips_and_updates_outlined, AppColors.accentBlue),
                      const SizedBox(height: 8),
                      _tarjeta(_retro!.sugerenciasPerfil!,
                          AppColors.accentBlue),
                      const SizedBox(height: 16),
                    ],
                    if (_retro!.roadmapEstado != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.accentGreen.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.auto_awesome,
                              size: 14, color: AppColors.accentGreen),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            _retro!.roadmapListo
                              ? 'El candidato ya puede ver el roadmap de IA generado.'
                              : 'El roadmap de IA está siendo generado para el candidato.',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary),
                          )),
                        ]),
                      ),
                    ],
                  ]),
                ),
          ),
        ]),
      ),
    );
  }

  Widget _seccion(String titulo, IconData icon, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 6),
    Text(titulo, style: AppTextStyles.subtitle1.copyWith(
        fontWeight: FontWeight.bold, color: color)),
  ]);

  Widget _tarjeta(String contenido, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Text(contenido, style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary, height: 1.5)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Sheet de retroalimentación — BUG 2 FIX
// ══════════════════════════════════════════════════════════════════════════════
class _RetroalimentacionSheet extends StatefulWidget {
  final int estudianteId;
  final int vacanteId;
  final String? nombre;
  final CompanyProvider provider;
  final int userId;
  final int? postulacionId;
  final void Function(String mensaje) onRechazado;

  const _RetroalimentacionSheet({
    required this.estudianteId,
    required this.vacanteId,
    required this.nombre,
    required this.provider,
    required this.userId,
    required this.onRechazado,
    this.postulacionId,
  });

  @override
  State<_RetroalimentacionSheet> createState() =>
      _RetroalimentacionSheetState();
}

class _RetroalimentacionSheetState extends State<_RetroalimentacionSheet> {
  final _camposCtrl      = TextEditingController();
  final _sugerenciasCtrl = TextEditingController();
  final _formKey         = GlobalKey<FormState>();
  bool  _enviando        = false;

  @override
  void dispose() {
    _camposCtrl.dispose();
    _sugerenciasCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final p = widget.provider;

    try {
      final resultado = await p.rechazarCandidato(
        empresaId:         widget.userId,
        estudianteId:      widget.estudianteId,
        vacanteId:         widget.vacanteId,
        camposMejora:      _camposCtrl.text.trim(),
        sugerenciasPerfil: _sugerenciasCtrl.text.trim().isEmpty
            ? null
            : _sugerenciasCtrl.text.trim(),
      );

      await p.recargarCandidatos(widget.userId);

      if (!mounted) return;
      Navigator.pop(context);
      if (resultado.retroCreada) {
        widget.onRechazado('Candidato rechazado y feedback enviado ✓');
      } else if (resultado.exito && _camposCtrl.text.trim().isNotEmpty) {
        widget.onRechazado(
          'Candidato rechazado — el feedback no pudo enviarse porque '
          'el candidato no tiene postulación formal en esta vacante.',
        );
      } else {
        widget.onRechazado('Candidato rechazado');
      }

    } catch (e) {
      debugPrint('[RetroSheet] Error inesperado en _enviar: $e');
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Error al rechazar candidato. Intenta de nuevo.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 18),

                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.feedback_outlined,
                        color: AppColors.error, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Confirmar rechazo',
                        style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold)),
                    Text(widget.nombre ?? 'Candidato',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary)),
                  ])),
                ]),
                const SizedBox(height: 8),

                // Info contextual según si existe postulación formal
                if (widget.postulacionId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'El feedback que escribas se enviará al candidato '
                      'y la IA generará un plan de mejora personalizado.',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error.withOpacity(0.8)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.accentOrange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.accentOrange.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppColors.accentOrange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Este candidato solo dio like sin postularse formalmente. '
                        'El rechazo quedará registrado pero no es posible enviarle feedback.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accentOrange),
                      )),
                    ]),
                  ),
                const SizedBox(height: 20),

                // Campos de feedback solo si hay postulación formal
                if (widget.postulacionId != null) ...[
                  Text('Áreas de mejora (opcional)',
                      style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _camposCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Explica por qué no es el candidato adecuado...',
                      filled: true,
                      fillColor: AppColors.primaryPurple.withOpacity(0.03),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryPurple, width: 2)),
                    ),
                    validator: (v) => null,
                  ),
                  const SizedBox(height: 16),

                  Text('Sugerencias para su perfil',
                      style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Opcional — consejos para mejorar su CV o perfil',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _sugerenciasCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ej: Agrega más detalle a tu experiencia, '
                          'mejora tu portfolio...',
                      filled: true,
                      fillColor: AppColors.primaryPurple.withOpacity(0.03),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryPurple, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 8),

                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: _enviando ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryPurple),
                      foregroundColor: AppColors.primaryPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _enviar,
                    icon: _enviando
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.close, size: 16),
                    label: Text(_enviando
                        ? 'Procesando...'
                        : widget.postulacionId != null
                            ? 'Rechazar y enviar feedback'
                            : 'Confirmar rechazo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sheet de feedback para candidatos ya rechazados
// Busca la postulacion_id en el backend y crea la retroalimentación.
// ══════════════════════════════════════════════════════════════════════════════
class _FeedbackRechazadoSheet extends StatefulWidget {
  final int empresaId;
  final int estudianteId;
  final int vacanteId;
  final String? nombre;
  final CompanyProvider provider;

  const _FeedbackRechazadoSheet({
    required this.empresaId,
    required this.estudianteId,
    required this.vacanteId,
    required this.nombre,
    required this.provider,
  });

  @override
  State<_FeedbackRechazadoSheet> createState() => _FeedbackRechazadoSheetState();
}

class _FeedbackRechazadoSheetState extends State<_FeedbackRechazadoSheet> {
  final _camposCtrl      = TextEditingController();
  final _sugerenciasCtrl = TextEditingController();
  final _formKey         = GlobalKey<FormState>();
  bool _enviando  = false;
  bool _buscando  = true;
  int? _postulacionId;
  bool _yaEnvioFeedback = false; // true si ya existe retroalimentación

  @override
  void initState() {
    super.initState();
    _buscarPostulacion();
  }

  @override
  void dispose() {
    _camposCtrl.dispose();
    _sugerenciasCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarPostulacion() async {
    debugPrint('[FeedbackSheet] buscando postulacion est=${widget.estudianteId} vac=${widget.vacanteId}');
    final pid = await widget.provider.buscarPostulacionId(
      empresaId:    widget.empresaId,
      estudianteId: widget.estudianteId,
      vacanteId:    widget.vacanteId,
    );
    debugPrint('[FeedbackSheet] postulacion_id=$pid');
    if (!mounted) return;

    if (pid != null) {
      // Verificar si ya hay retroalimentación para esta postulación
      final retro = await RetroalimentacionRepository.instance
          .getRetroalimentacion(pid);
      debugPrint('[FeedbackSheet] retro existente: ${retro?.tieneContenido}');
      if (!mounted) return;
      setState(() {
        _postulacionId = pid;
        _yaEnvioFeedback = retro != null && retro.tieneContenido;
        _buscando = false;
      });
    } else {
      setState(() { _postulacionId = null; _buscando = false; });
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    final resultado = await widget.provider.enviarFeedbackRechazado(
      empresaId:         widget.empresaId,
      estudianteId:      widget.estudianteId,
      vacanteId:         widget.vacanteId,
      camposMejora:      _camposCtrl.text.trim(),
      sugerenciasPerfil: _sugerenciasCtrl.text.trim().isEmpty
          ? null : _sugerenciasCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultado.retroCreada
          ? 'Feedback enviado ✓ — la IA generará el plan de mejora'
          : resultado.encontrado
              ? 'Error al guardar el feedback. Intenta de nuevo.'
              : 'Este candidato no tiene postulación formal — no se puede enviar feedback.'),
      backgroundColor: resultado.retroCreada ? AppColors.accentGreen : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 18),

                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.auto_awesome,
                        color: AppColors.primaryPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Enviar feedback',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(widget.nombre ?? 'Candidato',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary)),
                  ])),
                ]),
                const SizedBox(height: 12),

                if (_buscando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_postulacionId == null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.accentOrange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accentOrange.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.accentOrange, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text(
                        'Este candidato rechazó la vacante antes del match, '
                        'por lo que no tiene postulación formal. '
                        'No es posible enviarle retroalimentación.',
                        style: TextStyle(color: AppColors.accentOrange),
                      )),
                    ]),
                  )
                else if (_yaEnvioFeedback) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accentGreen.withValues(alpha: 0.3))),
                    child: const Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.accentGreen, size: 18),
                      SizedBox(width: 10),
                      Expanded(child: Text(
                        'Ya enviaste retroalimentación a este candidato. '
                        'No es posible enviarla dos veces.',
                        style: TextStyle(color: AppColors.accentGreen),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primaryPurple),
                        foregroundColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'El feedback se enviará al candidato y '
                      'la IA generará un plan de mejora personalizado.',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.accentGreen),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Áreas de mejora *',
                      style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _camposCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Explica por qué no continuó el proceso...',
                      filled: true,
                      fillColor: AppColors.primaryPurple.withOpacity(0.03),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryPurple, width: 2)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Escribe al menos una área de mejora' : null,
                  ),
                  const SizedBox(height: 16),

                  Text('Sugerencias de perfil',
                      style: AppTextStyles.subtitle1.copyWith(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Opcional — consejos para mejorar su CV o perfil',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _sugerenciasCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ej: Agrega más proyectos al portfolio...',
                      filled: true,
                      fillColor: AppColors.primaryPurple.withOpacity(0.03),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.borderLight)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryPurple, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: _enviando ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primaryPurple),
                        foregroundColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton.icon(
                      onPressed: _enviando ? null : _enviar,
                      icon: _enviando
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(_enviando ? 'Enviando...' : 'Enviar feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )),
                  ]),
                ],

                if (_postulacionId == null && !_buscando) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}