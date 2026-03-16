// lib/presentation/screens/company/candidates/candidates_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';

class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key});

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) context.read<CompanyProvider>().recargarPostulaciones(id);
    });
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  List<Map<String, dynamic>> _filtrados(List<Map<String, dynamic>> lista) {
    if (_filtroEstado == 'todos') return lista;
    return lista.where((p) =>
        (p['estado'] as String? ?? '').toLowerCase() == _filtroEstado).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidatos'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: (i) => setState(() =>
              _filtroEstado = ['todos','pendiente','aceptado','rechazado'][i]),
          tabs: const [Tab(text:'Todos'), Tab(text:'Pendientes'),
                       Tab(text:'Aceptados'), Tab(text:'Rechazados')],
        ),
      ),
      body: Consumer<CompanyProvider>(builder: (_, company, __) {
        if (company.cargando && company.postulaciones.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final lista = _filtrados(company.postulaciones);
        if (lista.isEmpty) return _buildEmpty();
        return RefreshIndicator(
          onRefresh: () async {
            final id = context.read<AuthProvider>().usuario?.id;
            if (id != null) await context.read<CompanyProvider>().recargarPostulaciones(id);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildCard(lista[i]),
          ),
        );
      }),
    );
  }

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.people_outline, size: 80, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text('Sin candidatos', style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text(
        _filtroEstado == 'todos'
            ? 'Aún no hay postulaciones para tus vacantes'
            : 'No hay candidatos con este estado',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
        textAlign: TextAlign.center,
      ),
    ],
  ));

  Widget _buildCard(Map<String, dynamic> p) {
    final estado  = p['estado'] as String? ?? 'pendiente';
    final nombre  = p['estudiante_nombre'] as String? ?? p['nombre_completo'] as String? ?? 'Candidato';
    final vacante = p['vacante_titulo'] as String? ?? p['titulo'] as String? ?? 'Vacante';
    final postId  = p['id'] as int?;
    final inst    = p['institucion_educativa'] as String? ?? '';
    final nivel   = p['nivel_academico'] as String? ?? '';
    final color   = _colorEstado(estado);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryPurple.withOpacity(0.15),
            child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: AppTextStyles.h4.copyWith(color: AppColors.primaryPurple)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
            if (inst.isNotEmpty)
              Text(inst, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            if (nivel.isNotEmpty)
              Text(nivel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_labelEstado(estado),
                style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primaryPurple.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.work_outline, size: 14, color: AppColors.primaryPurple),
            const SizedBox(width: 6),
            Flexible(child: Text(vacante, style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryPurple, fontWeight: FontWeight.w600))),
          ]),
        ),
        if (estado == 'pendiente' && postId != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _cambiarEstado(postId, 'rechazado'),
              icon: const Icon(Icons.close, size: 16, color: AppColors.error),
              label: const Text('Rechazar', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0,40),
                  side: const BorderSide(color: AppColors.error)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _cambiarEstado(postId, 'aceptado'),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Aceptar'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0,40),
                  backgroundColor: AppColors.accentGreen),
            )),
          ]),
        ],
      ]),
    );
  }

  Future<void> _cambiarEstado(int postId, String estado) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Estado cambiado a "$estado"'),
      backgroundColor: estado == 'aceptado' ? AppColors.accentGreen : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'aceptado': return AppColors.accentGreen;
      case 'rechazado': return AppColors.error;
      default: return AppColors.accentBlue;
    }
  }
  String _labelEstado(String e) {
    switch (e) {
      case 'aceptado': return 'Aceptado';
      case 'rechazado': return 'Rechazado';
      default: return 'Pendiente';
    }
  }
}