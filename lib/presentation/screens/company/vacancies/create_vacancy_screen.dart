// lib/presentation/screens/company/vacancies/create_vacancy_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';

class CreateVacancyScreen extends StatefulWidget {
  const CreateVacancyScreen({super.key});

  @override
  State<CreateVacancyScreen> createState() => _CreateVacancyScreenState();
}

class _CreateVacancyScreenState extends State<CreateVacancyScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _tituloCtrl    = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _requisitosCtrl = TextEditingController();
  final _salarioCtrl   = TextEditingController();
  final _ubicacionCtrl = TextEditingController();

  String? _modalidad;
  String? _tipoContrato;
  bool _cargando = false;

  static const _modalidades    = ['remoto', 'presencial', 'hibrido'];
  static const _tiposContrato  = ['tiempo_completo','medio_tiempo','practicas','freelance'];

  @override
  void dispose() {
    _tituloCtrl.dispose(); _descCtrl.dispose();
    _requisitosCtrl.dispose(); _salarioCtrl.dispose();
    _ubicacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    final empresaId = context.read<AuthProvider>().usuario?.id;
    if (empresaId == null) return;

    setState(() => _cargando = true);
    try {
      await ApiService.instance.post(
        '/vacante/$empresaId',
        {
          'titulo':      _tituloCtrl.text.trim(),
          'descripcion': _descCtrl.text.trim(),
          if (_requisitosCtrl.text.trim().isNotEmpty)
            'requisitos': _requisitosCtrl.text.trim(),
          if (_salarioCtrl.text.trim().isNotEmpty)
            'salario': _salarioCtrl.text.trim(),
          if (_ubicacionCtrl.text.trim().isNotEmpty)
            'ubicacion': _ubicacionCtrl.text.trim(),
          if (_modalidad != null)    'modalidad': _modalidad,
          if (_tipoContrato != null) 'tipo_contrato': _tipoContrato,
        },
        auth: true,
      );
      if (!mounted) return;
      // Recargar vacantes
      await context.read<CompanyProvider>().cargarDashboard(empresaId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vacante publicada exitosamente'),
        backgroundColor: AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva vacante'),
        actions: [
          TextButton(
            onPressed: _cargando ? null : _crear,
            child: _cargando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Publicar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [

          _section('Información básica'),
          const SizedBox(height: 16),
          _field(_tituloCtrl, 'Título del puesto *', Icons.work_outline,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
          const SizedBox(height: 16),
          _field(_descCtrl, 'Descripción *', Icons.description_outlined,
              maxLines: 4,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
          const SizedBox(height: 16),
          _field(_requisitosCtrl, 'Requisitos', Icons.checklist_outlined, maxLines: 3,
              hint: 'Ej: 2 años de experiencia, inglés intermedio...'),
          const SizedBox(height: 32),

          _section('Condiciones'),
          const SizedBox(height: 16),
          _field(_salarioCtrl, 'Rango salarial', Icons.attach_money,
              hint: 'Ej: \$8,000 - \$12,000 MXN'),
          const SizedBox(height: 16),
          _field(_ubicacionCtrl, 'Ubicación', Icons.location_on_outlined,
              hint: 'Ciudad, Estado'),
          const SizedBox(height: 16),

          // Modalidad
          Text('Modalidad', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: _modalidades.map((m) {
            final sel = _modalidad == m;
            return ChoiceChip(
              label: Text(_labelModalidad(m)), selected: sel,
              onSelected: (_) => setState(() => _modalidad = sel ? null : m),
              selectedColor: AppColors.primaryPurple,
              labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
            );
          }).toList()),
          const SizedBox(height: 16),

          // Tipo contrato
          Text('Tipo de contrato', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _tiposContrato.map((t) {
            final sel = _tipoContrato == t;
            return ChoiceChip(
              label: Text(_labelTipo(t)), selected: sel,
              onSelected: (_) => setState(() => _tipoContrato = sel ? null : t),
              selectedColor: AppColors.primaryPurple,
              labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600),
            );
          }).toList()),
          const SizedBox(height: 40),

          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _cargando ? null : _crear,
            child: _cargando
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Publicar vacante'),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _section(String t) => Text(t, style: AppTextStyles.h4);

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {String? hint, int maxLines = 1, String? Function(String?)? validator}) =>
    TextFormField(controller: ctrl, maxLines: maxLines, validator: validator,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
          filled: true, fillColor: Theme.of(context).cardColor,
        ));

  String _labelModalidad(String m) {
    switch (m) { case 'remoto': return 'Remoto'; case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido'; default: return m; }
  }
  String _labelTipo(String t) {
    switch (t) { case 'tiempo_completo': return 'Tiempo completo';
      case 'medio_tiempo': return 'Medio tiempo'; case 'practicas': return 'Prácticas';
      case 'freelance': return 'Freelance'; default: return t; }
  }
}