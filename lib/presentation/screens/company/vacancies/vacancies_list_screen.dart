// lib/presentation/screens/company/vacancies/vacancies_list_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/auth_provider.dart';

class VacanciesListScreen extends StatefulWidget {
  /// Callback para ir al tab candidatos filtrando por una vacante específica
  final void Function(int vacanteId, String titulo)? onVerCandidatos;

  const VacanciesListScreen({super.key, this.onVerCandidatos});

  @override
  State<VacanciesListScreen> createState() => _VacanciesListScreenState();
}

class _VacanciesListScreenState extends State<VacanciesListScreen> {
  String? _filtroEstado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) context.read<CompanyProvider>().recargarVacantes(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mis vacantes'),
        actions: [
          Consumer<CompanyProvider>(builder: (_, company, __) {
            final estados = _estadosDisponibles(company.vacantes);
            if (estados.isEmpty) return const SizedBox.shrink();
            return PopupMenuButton<String?>(
              icon: Stack(children: [
                const Icon(Icons.filter_list),
                if (_filtroEstado != null)
                  Positioned(right: 0, top: 0,
                    child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.primaryPurple,
                          shape: BoxShape.circle))),
              ]),
              tooltip: 'Filtrar por estado',
              onSelected: (v) => setState(() => _filtroEstado = v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null,
                    child: Text('Todas las vacantes')),
                ...estados.map((e) => PopupMenuItem(
                    value: e, child: Text(_labelEstado(e)))),
              ],
            );
          }),
        ],
      ),
      body: Consumer<CompanyProvider>(builder: (_, company, __) {
        if (company.cargando && company.vacantes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final todas = company.vacantes;
        final lista = _filtroEstado == null
            ? todas
            : todas.where((v) =>
                (v['estado'] as String? ?? '').toLowerCase() ==
                _filtroEstado!.toLowerCase()).toList();

        if (todas.isEmpty) return _buildEmpty();

        return RefreshIndicator(
          onRefresh: () async {
            final id = context.read<AuthProvider>().usuario?.id;
            if (id != null) {
              await company.recargarVacantes(id);
              await company.recargarCandidatos(id);
            }
          },
          child: Column(children: [
            if (_filtroEstado != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: AppColors.primaryPurple.withOpacity(0.08),
                child: Row(children: [
                  const Icon(Icons.filter_list, size: 14,
                      color: AppColors.primaryPurple),
                  const SizedBox(width: 6),
                  Text('Mostrando: ${_labelEstado(_filtroEstado!)}',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _filtroEstado = null),
                    child: const Icon(Icons.close, size: 14,
                        color: AppColors.primaryPurple)),
                ]),
              ),

            if (lista.isEmpty)
              Expanded(child: Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.search_off, size: 64,
                      color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text('Sin vacantes "${_labelEstado(_filtroEstado!)}"',
                      style: AppTextStyles.h4.copyWith(
                          color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(
                      onPressed: () => setState(() => _filtroEstado = null),
                      child: const Text('Ver todas')),
                ]),
              )))
            else
              Expanded(child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildVacanteCard(lista[i], company),
              )),
          ]),
        );
      }),
    );
  }

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.work_off_outlined, size: 80, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text('Sin vacantes publicadas',
          style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text('Usa "Publicar vacante" en la pantalla de inicio para empezar.',
          style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textTertiary),
          textAlign: TextAlign.center),
    ]),
  ));

  Widget _buildVacanteCard(
      Map<String, dynamic> v, CompanyProvider company) {
    final titulo    = v['titulo']        as String? ?? 'Vacante';
    final modalidad = v['modalidad']     as String? ?? '';
    final ubicacion = v['ubicacion']     as String? ?? '';
    final tipo      = v['tipo_contrato'] as String? ?? '';
    final estado    = v['estado']        as String? ?? 'activa';
    final id        = v['id']            as int?;

    final minS   = v['sueldo_minimo'];
    final maxS   = v['sueldo_maximo'];
    final moneda = v['moneda'] as String? ?? 'MXN';
    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    final totalLikes   = v['total_likes_estudiantes'] as int? ?? 0;
    final totalVistas  = v['total_visualizaciones']   as int? ?? 0;
    final totalMatches = v['total_matches']            as int? ?? 0;

    final candidatosDeEstaVacante = id != null
        ? company.candidatosFeed
            .where((c) => c['vacante_id'] == id).length
        : 0;

    final estadoColor = _colorEstado(estado);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: candidatosDeEstaVacante > 0
            ? Border.all(
                color: AppColors.primaryPurple.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.work_outline,
                  color: AppColors.accentBlue, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold)),
              if (tipo.isNotEmpty)
                Text(tipo, style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary)),
            ])),
            _badgeEstado(estado, estadoColor),
          ]),
          const SizedBox(height: 10),

          Wrap(spacing: 8, runSpacing: 6, children: [
            if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined, ubicacion),
            if (modalidad.isNotEmpty) _chip(Icons.work_outline, _labelModalidad(modalidad)),
            if (salario.isNotEmpty)   _chip(Icons.attach_money, salario),
          ]),

          // Métricas
          if (totalVistas > 0 || totalLikes > 0 || totalMatches > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              if (totalVistas > 0) _metrica(
                  Icons.visibility_outlined, '$totalVistas', 'vistas',
                  AppColors.textTertiary),
              if (totalLikes > 0) _metrica(
                  Icons.thumb_up_outlined, '$totalLikes', 'likes',
                  AppColors.primaryPurple),
              if (candidatosDeEstaVacante > 0) _metrica(
                  Icons.pending_outlined,
                  '$candidatosDeEstaVacante', 'pendientes',
                  Colors.orange),
              if (totalMatches > 0) _metrica(
                  Icons.favorite, '$totalMatches', 'matches',
                  AppColors.accentGreen),
            ]),
          ],

          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                if (id != null) context.push('/company/vacancies/edit/$id');
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            )),
            const SizedBox(width: 10),
            Expanded(child: Stack(children: [
              ElevatedButton.icon(
                // FIX: usa el callback del shell en lugar de GoRouter extra
                onPressed: () {
                  if (id != null && widget.onVerCandidatos != null) {
                    widget.onVerCandidatos!(id, titulo);
                  }
                },
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('Candidatos'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40)),
              ),
              if (candidatosDeEstaVacante > 0)
                Positioned(right: 4, top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                    child: Text('$candidatosDeEstaVacante',
                        style: const TextStyle(fontSize: 10,
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  )),
            ])),
          ]),

          const SizedBox(height: 8),
          _buildCambioEstado(id, estado, company),
        ]),
      ),
    );
  }

  Widget _buildCambioEstado(
      int? id, String estadoActual, CompanyProvider company) {
    if (id == null) return const SizedBox.shrink();
    const estados = ['activa', 'pausada', 'cerrada'];
    return Row(children: [
      const Icon(Icons.swap_horiz, size: 14, color: AppColors.textTertiary),
      const SizedBox(width: 6),
      Text('Estado:', style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textTertiary)),
      const SizedBox(width: 8),
      ...estados.map((e) {
        final sel = e == estadoActual.toLowerCase();
        final color = _colorEstado(e);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: sel ? null : () => _cambiarEstado(id, e, company),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: sel ? color : AppColors.borderLight,
                    width: sel ? 1.5 : 1),
              ),
              child: Text(_labelEstado(e),
                  style: TextStyle(
                      fontSize: 11,
                      color: sel ? color : AppColors.textTertiary,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
            ),
          ),
        );
      }),
    ]);
  }

  Future<void> _cambiarEstado(
      int vacanteId, String nuevoEstado, CompanyProvider company) async {
    final ok = await company.actualizarVacante(vacanteId, {'estado': nuevoEstado});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Estado actualizado a "${_labelEstado(nuevoEstado)}"'
          : 'Error al cambiar el estado'),
      backgroundColor: ok ? AppColors.accentGreen : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _badgeEstado(String estado, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(_labelEstado(estado),
        style: AppTextStyles.bodySmall.copyWith(
            color: color, fontWeight: FontWeight.bold)),
  );

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.primaryPurple),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.primaryPurple)),
    ]),
  );

  Widget _metrica(IconData icon, String value, String label, Color color) =>
    Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text('$value $label', style: AppTextStyles.bodySmall.copyWith(
            color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    );

  Color _colorEstado(String e) {
    switch (e.toLowerCase()) {
      case 'activa':    return AppColors.accentGreen;
      case 'pausada':   return Colors.orange;
      case 'cerrada':   return AppColors.error;
      case 'archivada': return AppColors.textTertiary;
      default:          return AppColors.accentGreen;
    }
  }

  String _labelEstado(String e) {
    switch (e.toLowerCase()) {
      case 'activa':    return 'Activa';
      case 'pausada':   return 'Pausada';
      case 'cerrada':   return 'Cerrada';
      case 'archivada': return 'Archivada';
      default:          return e;
    }
  }

  String _labelModalidad(String m) {
    switch (m.toLowerCase()) {
      case 'remoto':     return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido':    return 'Híbrido';
      default:           return m;
    }
  }

  Set<String> _estadosDisponibles(List<Map<String, dynamic>> vacantes) =>
      vacantes.map((v) => (v['estado'] as String? ?? '').toLowerCase())
          .where((e) => e.isNotEmpty).toSet();
}