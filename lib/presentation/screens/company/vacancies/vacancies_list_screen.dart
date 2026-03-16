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
  const VacanciesListScreen({super.key});

  @override
  State<VacanciesListScreen> createState() => _VacanciesListScreenState();
}

class _VacanciesListScreenState extends State<VacanciesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) context.read<CompanyProvider>().cargarDashboard(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis vacantes')),
      body: Consumer<CompanyProvider>(builder: (_, company, __) {
        if (company.cargando && company.vacantes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (company.vacantes.isEmpty) return _buildEmpty();
        return RefreshIndicator(
          onRefresh: () async {
            final id = context.read<AuthProvider>().usuario?.id;
            if (id != null) await company.cargarDashboard(id);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: company.vacantes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildVacanteCard(company.vacantes[i]),
          ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.companyCreateVacancy),
        icon: const Icon(Icons.add),
        label: const Text('Nueva vacante'),
        backgroundColor: AppColors.primaryPurple,
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.work_off_outlined, size: 80, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text('Sin vacantes', style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Text('Publica tu primera vacante para empezar a recibir candidatos',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => context.push(AppRoutes.companyCreateVacancy),
        icon: const Icon(Icons.add), label: const Text('Publicar vacante'),
      ),
    ],
  ));

  Widget _buildVacanteCard(Map<String, dynamic> v) {
    final titulo    = v['titulo'] as String? ?? 'Vacante';
    final modalidad = v['modalidad'] as String? ?? '';
    final ubicacion = v['ubicacion'] as String? ?? '';
    final salario   = v['salario'] as String? ?? '';
    final tipo      = v['tipo_contrato'] as String? ?? '';
    final id        = v['id'];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.work_outline, color: AppColors.accentBlue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold)),
              if (tipo.isNotEmpty)
                Text(tipo, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Activa', style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (ubicacion.isNotEmpty) _chip(Icons.location_on_outlined, ubicacion),
            if (modalidad.isNotEmpty) _chip(Icons.work_outline, _labelModalidad(modalidad)),
            if (salario.isNotEmpty) _chip(Icons.attach_money, salario),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                if (id != null) context.push('${AppRoutes.companyEditVacancy}/$id');
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.companyCandidates),
              icon: const Icon(Icons.people_outline, size: 16),
              label: const Text('Ver candidatos'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 38)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primaryPurple.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.primaryPurple),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryPurple)),
    ]),
  );

  String _labelModalidad(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }
}