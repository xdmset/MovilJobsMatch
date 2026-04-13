// lib/presentation/screens/company/home/company_home_tab.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/settings_provider.dart';

class CompanyHomeTab extends StatelessWidget {
  /// Callback para ir al tab de candidatos con filtro de vacante
  final void Function(int vacanteId, String titulo)? onIrACandidatos;

  const CompanyHomeTab({super.key, this.onIrACandidatos});

  @override
  Widget build(BuildContext context) {
    final comp = context.watch<CompanyProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hola, ${comp.perfil?.nombreComercial ?? 'Empresa'}',
              style: AppTextStyles.h4),
          Text('Panel de reclutamiento',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary)),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _handleMenu(context, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settings',
                  child: Row(children: [Icon(Icons.settings_outlined),
                    SizedBox(width: 12), Text('Configuración')])),
              const PopupMenuItem(value: 'theme',
                  child: Row(children: [Icon(Icons.dark_mode_outlined),
                    SizedBox(width: 12), Text('Tema')])),
              const PopupMenuItem(value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Cerrar sesión',
                        style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final id = context.read<AuthProvider>().usuario?.id;
          if (id != null) await context.read<CompanyProvider>().cargarDashboard(id);
        },
        child: comp.cargando && comp.perfil == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _buildMetrics(context, comp),
                  const SizedBox(height: 20),
                  _buildAccionesRapidas(context),
                  const SizedBox(height: 20),
                  _buildSeccionCandidatos(context, comp),
                  const SizedBox(height: 20),
                  _buildSeccionVacantes(context, comp),
                  const SizedBox(height: 24),
                ]),
              ),
      ),
      // Sin FAB — usar acción rápida "Publicar vacante"
    );
  }

  // ── Métricas ──────────────────────────────────────────────────────────────
  Widget _buildMetrics(BuildContext context, CompanyProvider comp) {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _metricCard(context, Icons.work_outline,
            comp.vacantes.length.toString(),
            'Vacantes activas', AppColors.accentBlue),
        _metricCard(context, Icons.people_outline,
            comp.totalCandidatos.toString(),
            'Total candidatos', AppColors.primaryPurple),
        _metricCard(context, Icons.pending_outlined,
            comp.pendientes.toString(),
            'Por revisar', Colors.orange),
        _metricCard(context, Icons.favorite_outline,
            comp.matches.toString(),
            'Matches', AppColors.accentGreen),
      ],
    );
  }

  Widget _metricCard(BuildContext context, IconData icon, String value,
      String label, Color color) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(value, style: AppTextStyles.h3.copyWith(color: color)),
          Text(label, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary), maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );

  // ── Acciones rápidas ──────────────────────────────────────────────────────
  Widget _buildAccionesRapidas(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Acciones rápidas', style: AppTextStyles.subtitle1.copyWith(
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _accionBtn(context, Icons.add_circle_outline,
            'Publicar vacante', AppColors.accentBlue,
            () => context.push(AppRoutes.companyCreateVacancy))),
        const SizedBox(width: 10),
        Expanded(child: _accionBtn(context, Icons.edit_outlined,
            'Editar perfil', AppColors.primaryPurple,
            () => context.push(AppRoutes.companyEditProfile))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _accionBtn(context, Icons.workspace_premium,
            'Ver Business', AppColors.accentGreen,
            () => context.push(AppRoutes.companyPremium))),
        const SizedBox(width: 10),
        Expanded(child: _accionBtn(context, Icons.settings_outlined,
            'Configuración', AppColors.textSecondary,
            () => context.push(AppRoutes.companySettings))),
      ]),
    ]),
  );

  Widget _accionBtn(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall.copyWith(
              color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );

  // ── Candidatos recientes ──────────────────────────────────────────────────
  // Solo muestra candidatos pendientes (sin aceptar/rechazar aún)
  Widget _buildSeccionCandidatos(BuildContext context, CompanyProvider comp) {
    // Solo los que están realmente pendientes de revisión
    final pendientes = comp.candidatosFeed.take(3).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Por revisar', style: AppTextStyles.h4),
        const Spacer(),
        if (comp.pendientes > 0)
          GestureDetector(
            onTap: () {
              // Ir al tab de candidatos sin filtro de vacante
              // (el shell lo maneja)
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${comp.pendientes} pendientes',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.orange, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      if (pendientes.isEmpty)
        _emptyCard(context,
            'Sin candidatos pendientes\nCuando los estudiantes den like a tus vacantes aparecerán aquí',
            Icons.people_outline)
      else
        ...pendientes.map((c) => _candidatoMini(context, c, comp)),
    ]);
  }

  Widget _candidatoMini(BuildContext context,
      Map<String, dynamic> candidato, CompanyProvider comp) {
    final estudianteId = candidato['estudiante_id'] as int?
        ?? candidato['usuario_id'] as int? ?? 0;
    final vacanteId    = candidato['vacante_id'] as int? ?? 0;
    final nombre       = candidato['nombre_completo'] as String?;
    final nivel        = candidato['nivel_academico'] as String? ?? '';
    final institucion  = candidato['institucion_educativa'] as String? ?? '';
    final fotoUrl      = candidato['foto_perfil_url'] as String?;
    final fechaStr     = candidato['fecha_like'] as String? ?? '';

    final vacante   = comp.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloV   = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';

    final inicial = nombre != null && nombre.isNotEmpty
        ? nombre[0].toUpperCase() : 'E';

    return GestureDetector(
      onTap: () => _mostrarPerfilCandidato(context, candidato, comp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(children: [
          // Foto o avatar
          _avatarCandidato(fotoUrl, inicial, 20),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre ?? 'Candidato #$estudianteId',
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600)),
            Text(tituloV, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary)),
            if (institucion.isNotEmpty)
              Text(institucion, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary, fontSize: 10)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Pendiente',
                  style: TextStyle(fontSize: 10, color: Colors.orange,
                      fontWeight: FontWeight.w600)),
            ),
            if (fechaStr.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(_formatFecha(fechaStr),
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary, fontSize: 10)),
            ],
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right, size: 14,
                color: AppColors.textTertiary),
          ]),
        ]),
      ),
    );
  }

  // ── Vacantes recientes ────────────────────────────────────────────────────
  Widget _buildSeccionVacantes(BuildContext context, CompanyProvider comp) {
    final vacantes = comp.vacantes.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mis vacantes', style: AppTextStyles.h4),
      const SizedBox(height: 12),
      if (vacantes.isEmpty)
        _emptyCard(context,
            'Aún no has publicado vacantes\nPresiona "Publicar vacante" para crear tu primera vacante',
            Icons.work_outline)
      else
        ...vacantes.map((v) => _vacanteMini(context, v, comp)),
    ]);
  }

  Widget _vacanteMini(BuildContext context,
      Map<String, dynamic> v, CompanyProvider comp) {
    final titulo    = v['titulo']    as String? ?? 'Vacante';
    final estado    = v['estado']    as String? ?? 'activa';
    final modalidad = v['modalidad'] as String? ?? '';
    final vacanteId = v['id'] as int?;
    final likesEstudiantes = v['total_likes_estudiantes'] as int? ?? 0;

    // Candidatos pendientes de esta vacante específica
    final pendientesVacante = vacanteId != null
        ? comp.candidatosFeed
            .where((c) => c['vacante_id'] == vacanteId).length
        : 0;

    Color estadoColor = AppColors.accentGreen;
    if (estado == 'inactivo' || estado == 'cerrada') estadoColor = AppColors.error;
    if (estado == 'pausada') estadoColor = Colors.orange;

    return GestureDetector(
      onTap: vacanteId != null && onIrACandidatos != null
          ? () => onIrACandidatos!(vacanteId, titulo)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: pendientesVacante > 0
                  ? AppColors.primaryPurple.withOpacity(0.3)
                  : AppColors.borderLight),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.work_outline,
                  color: AppColors.accentBlue, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600)),
            Row(children: [
              if (modalidad.isNotEmpty) Text(_lModal(modalidad),
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary)),
              if (likesEstudiantes > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.thumb_up, size: 11,
                    color: AppColors.primaryPurple),
                const SizedBox(width: 2),
                Text('$likesEstudiantes',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPurple, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
              if (pendientesVacante > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.pending_outlined, size: 11,
                    color: Colors.orange),
                const SizedBox(width: 2),
                Text('$pendientesVacante por revisar',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.orange, fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ]),
          ])),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_lEstado(estado), style: TextStyle(
                  fontSize: 11, color: estadoColor,
                  fontWeight: FontWeight.w600))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14,
                color: AppColors.textTertiary),
          ]),
        ]),
      ),
    );
  }

  // ── Perfil del candidato ──────────────────────────────────────────────────
  void _mostrarPerfilCandidato(BuildContext context,
      Map<String, dynamic> candidato, CompanyProvider comp) {
    final auth      = context.read<AuthProvider>();
    final empresaId = auth.usuario?.id ?? 0;

    final estudianteId = candidato['estudiante_id'] as int?
        ?? candidato['usuario_id'] as int? ?? 0;
    final vacanteId    = candidato['vacante_id'] as int? ?? 0;
    final nombre       = candidato['nombre_completo'] as String? ?? 'Candidato';
    final nivel        = candidato['nivel_academico'] as String? ?? '';
    final institucion  = candidato['institucion_educativa'] as String? ?? '';
    final ubicacion    = candidato['ubicacion'] as String? ?? '';
    final modalPref    = candidato['modalidad_preferida'] as String? ?? '';
    final habilidades  = candidato['habilidades'];
    final biografia    = candidato['biografia'] as String? ?? '';
    final cvUrl        = candidato['cv_url'] as String?;
    final fotoUrl      = candidato['foto_perfil_url'] as String?;
    final email        = candidato['email'] as String? ?? '';
    final esPremium    = candidato['es_premium'] as bool? ?? false;

    final vacante   = comp.vacantes.firstWhere(
        (v) => v['id'] == vacanteId, orElse: () => {});
    final tituloV   = vacante['titulo'] as String? ?? 'Vacante #$vacanteId';
    final inicial   = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';

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
            // Handle
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                _avatarCandidato(fotoUrl, inicial, 30),
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
                        borderRadius: BorderRadius.circular(6),
                      ),
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

            // Vacante a la que aplicó
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
                Expanded(child: Text('Le dio like a: $tituloV',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w600))),
              ]),
            ),
            const Divider(height: 20),

            // Contenido scrollable
            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Info chips
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

                // Biografía
                if (biografia.isNotEmpty) ...[
                  _secTitulo('Sobre mí'),
                  const SizedBox(height: 8),
                  Text(biografia, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.6)),
                  const SizedBox(height: 16),
                ],

                // Habilidades
                if (habilidades != null && habilidades.toString().isNotEmpty) ...[
                  _secTitulo('Habilidades'),
                  const SizedBox(height: 8),
                  Text(habilidades.toString(),
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 16),
                ],

                // CV
                if (cvUrl != null && cvUrl.isNotEmpty) ...[
                  _secTitulo('Currículum Vitae'),
                  const SizedBox(height: 8),
                  Container(
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
                      Expanded(child: Text('Ver CV del candidato',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.w600))),
                      const Icon(Icons.open_in_new, size: 16,
                          color: AppColors.accentBlue),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Acciones
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      comp.swipeEstudiante(
                        empresaId: empresaId,
                        estudianteId: estudianteId,
                        vacanteId: vacanteId,
                        interes: false,
                      );
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
                      comp.swipeEstudiante(
                        empresaId: empresaId,
                        estudianteId: estudianteId,
                        vacanteId: vacanteId,
                        interes: true,
                      );
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

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _avatarCandidato(String? fotoUrl, String inicial, double radius) {
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(fotoUrl),
        onBackgroundImageError: (_, __) {},
        backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
        child: fotoUrl.isEmpty ? Text(inicial, style: TextStyle(
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7)) : null,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryPurple.withOpacity(0.12),
      child: Text(inicial, style: TextStyle(
          color: AppColors.primaryPurple,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7)),
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

  Widget _emptyCard(BuildContext context, String msg, IconData icon) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(children: [
        Icon(icon, size: 40, color: AppColors.textTertiary),
        const SizedBox(height: 10),
        Text(msg, style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]),
    );

  void _handleMenu(BuildContext context, String v) {
    switch (v) {
      case 'settings': context.push(AppRoutes.companySettings); break;
      case 'theme':    _showTheme(context); break;
      case 'logout':   _logout(context); break;
    }
  }

  void _showTheme(BuildContext context) {
    final tp = context.read<ThemeProvider>();
    final sp = context.read<SettingsProvider>();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tema'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _tOpt(context, 'Claro',  ThemeMode.light,  Icons.light_mode_outlined,  tp, sp),
        _tOpt(context, 'Oscuro', ThemeMode.dark,   Icons.dark_mode_outlined,   tp, sp),
        _tOpt(context, 'Sistema',ThemeMode.system, Icons.brightness_auto_outlined, tp, sp),
      ]),
    ));
  }

  Widget _tOpt(BuildContext context, String label, ThemeMode mode,
      IconData icon, ThemeProvider tp, SettingsProvider sp) {
    final sel = tp.themeMode == mode;
    return ListTile(
      leading: Icon(icon,
          color: sel ? AppColors.accentBlue : AppColors.textSecondary),
      title: Text(label),
      trailing: sel ? const Icon(Icons.check,
          color: AppColors.accentBlue) : null,
      onTap: () { tp.setTheme(label); sp.setTheme(label); Navigator.pop(context); },
    );
  }

  void _logout(BuildContext context) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres salir?'),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primaryPurple),
              foregroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancelar'),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              context.read<CompanyProvider>().limpiar();
              context.read<AuthProvider>().logout();
              Navigator.pop(context);
              context.go(AppRoutes.welcome);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Salir'),
          )),
        ]),
      ],
    ),
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
    switch (m.toLowerCase()) {
      case 'remoto':     return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido':    return 'Híbrido';
      default: return m;
    }
  }

  String _lEstado(String e) {
    switch (e.toLowerCase()) {
      case 'activa': return 'Activa';
      case 'activo': return 'Activa';
      case 'inactivo': return 'Inactiva';
      case 'pausada': return 'Pausada';
      case 'cerrada': return 'Cerrada';
      default: return e;
    }
  }
}