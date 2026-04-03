// lib/presentation/screens/student/applications/applications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/student_provider.dart';

class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Mis matches'),
      ),
      body: Consumer<StudentProvider>(
        builder: (context, p, _) {
          final matches = List<Map<String, dynamic>>.from(p.matches);
          if (matches.isEmpty) return _buildEmpty(context);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildMatchCard(context, matches[i]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite_outline, size: 56,
              color: AppColors.primaryPurple),
        ),
        const SizedBox(height: 24),
        Text('Sin matches aún', style: AppTextStyles.h4.copyWith(
            color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Cuando des like a una vacante y la empresa también te elija, aparecerá aquí.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        // Usa setState del shell para cambiar tab — o simplemente pop
        ElevatedButton.icon(
          onPressed: () {
            // Navegar al tab de inicio dentro del shell
            final scaffold = Scaffold.maybeOf(context);
            // El IndexedStack no expone el setter, así que usamos
            // el provider para triggerar rebuild en home
            context.read<StudentProvider>().cargarVacantes();
          },
          icon: const Icon(Icons.swipe),
          label: const Text('Ir a explorar vacantes'),
        ),
      ]),
    ),
  );

  Widget _buildMatchCard(BuildContext context, Map<String, dynamic> match) {
    final vacante   = match['vacante'] as Map<String, dynamic>? ?? {};
    final titulo    = vacante['titulo'] as String? ?? 'Vacante';
    final modalidad = vacante['modalidad'] as String? ?? '';
    final ubicacion = vacante['ubicacion'] as String? ?? '';
    final minS      = vacante['sueldo_minimo'];
    final maxS      = vacante['sueldo_maximo'];
    final moneda    = vacante['moneda'] as String? ?? 'MXN';
    final fecha     = match['fecha_match'] as String?;

    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';
    else if (minS != null)            salario = 'Desde \$$minS $moneda';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Badge match
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.favorite, size: 15, color: AppColors.accentGreen),
            const SizedBox(width: 6),
            Text('Match', style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentGreen, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (fecha != null)
              Text(_formatFecha(fecha), style: AppTextStyles.bodySmall.copyWith(
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
              if (salario.isNotEmpty)   _chip(Icons.attach_money,
                  salario, AppColors.accentGreen),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDetalles(context, vacante),
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Ver detalles de la oferta'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showDetalles(BuildContext context, Map<String, dynamic> v) {
    final titulo  = v['titulo'] as String? ?? 'Vacante';
    final desc    = v['descripcion'] as String? ?? '';
    final requi   = v['requisitos'] as String? ?? '';
    final minS    = v['sueldo_minimo'];
    final maxS    = v['sueldo_maximo'];
    final moneda  = v['moneda'] as String? ?? 'MXN';
    String salario = '';
    if (minS != null && maxS != null) salario = '\$$minS – \$$maxS $moneda';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2))),
            Expanded(child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: AppTextStyles.h3),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if ((v['modalidad'] as String? ?? '').isNotEmpty)
                    _chip(Icons.work_outline, _lModal(v['modalidad']!),
                        AppColors.primaryPurple),
                  if ((v['ubicacion'] as String? ?? '').isNotEmpty)
                    _chip(Icons.location_on_outlined, v['ubicacion']!,
                        AppColors.accentBlue),
                  if (salario.isNotEmpty)
                    _chip(Icons.attach_money, salario, AppColors.accentGreen),
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

  String _lModal(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }

  String _formatFecha(String f) {
    try {
      final d = DateTime.parse(f).toLocal();
      const meses = ['ene','feb','mar','abr','may','jun',
                     'jul','ago','sep','oct','nov','dic'];
      return '${d.day} ${meses[d.month - 1]} ${d.year}';
    } catch (_) { return f; }
  }
}