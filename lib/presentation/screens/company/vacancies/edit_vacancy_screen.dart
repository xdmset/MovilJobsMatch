// lib/presentation/screens/company/vacancies/edit_vacancy_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';

class EditVacancyScreen extends StatefulWidget {
  final int? vacanteId;
  const EditVacancyScreen({super.key, required this.vacanteId});

  @override
  State<EditVacancyScreen> createState() => _EditVacancyScreenState();
}

class _EditVacancyScreenState extends State<EditVacancyScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _tituloCtrl     = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _requisitosCtrl = TextEditingController();
  final _salarioMinCtrl = TextEditingController();
  final _salarioMaxCtrl = TextEditingController();
  final _ubicacionCtrl  = TextEditingController();

  String? _modalidad;
  String? _tipoContrato;
  String  _estado    = 'activa';
  bool _guardando    = false;
  bool _cargandoData = true;

  static const _modalidades   = ['remoto', 'presencial', 'hibrido'];
  static const _tiposContrato = ['tiempo_completo', 'medio_tiempo', 'practicas', 'freelance'];
  static const _estados       = ['activa', 'pausada', 'cerrada'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarVacante());
  }

  @override
  void dispose() {
    _tituloCtrl.dispose(); _descCtrl.dispose(); _requisitosCtrl.dispose();
    _salarioMinCtrl.dispose(); _salarioMaxCtrl.dispose(); _ubicacionCtrl.dispose();
    super.dispose();
  }

  // ── Carga datos — primero del provider (ya cargado), si no del API ────────
  Future<void> _cargarVacante() async {
    if (widget.vacanteId == null) {
      setState(() => _cargandoData = false);
      return;
    }

    // Intentar desde el provider primero (sin llamada extra)
    final vacantesEnMemoria = context.read<CompanyProvider>().vacantes;
    final enMemoria = vacantesEnMemoria.where(
        (v) => v['id'] == widget.vacanteId).toList();

    if (enMemoria.isNotEmpty) {
      _llenarCampos(enMemoria.first);
      setState(() => _cargandoData = false);
      return;
    }

    // Si no está en memoria, llamar al API
    try {
      final raw = await ApiService.instance
          .get('/vacante/${widget.vacanteId}', auth: true);
      final v = raw is Map<String, dynamic>
          ? raw
          : (raw['data'] as Map<String, dynamic>);
      _llenarCampos(v);
    } catch (_) {
      // Si falla, dejar campos vacíos
    }
    setState(() => _cargandoData = false);
  }

  void _llenarCampos(Map<String, dynamic> v) {
    _tituloCtrl.text     = v['titulo'] as String? ?? '';
    _descCtrl.text       = v['descripcion'] as String? ?? '';
    _requisitosCtrl.text = v['requisitos'] as String? ?? '';
    _salarioMinCtrl.text =
        v['sueldo_minimo'] != null ? v['sueldo_minimo'].toString() : '';
    _salarioMaxCtrl.text =
        v['sueldo_maximo'] != null ? v['sueldo_maximo'].toString() : '';
    _ubicacionCtrl.text  = v['ubicacion'] as String? ?? '';
    _modalidad    = v['modalidad'] as String?;
    _tipoContrato = v['tipo_contrato'] as String?;
    _estado       = v['estado'] as String? ?? 'activa';
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final empresaId = context.read<AuthProvider>().usuario?.id;
    if (empresaId == null || widget.vacanteId == null) return;

    setState(() => _guardando = true);
    try {
      await ApiService.instance.put(
        '/vacante/${widget.vacanteId}',
        {
          'titulo':      _tituloCtrl.text.trim(),
          'descripcion': _descCtrl.text.trim(),
          if (_requisitosCtrl.text.trim().isNotEmpty)
            'requisitos': _requisitosCtrl.text.trim(),
          if (_salarioMinCtrl.text.trim().isNotEmpty)
            'sueldo_minimo': double.tryParse(_salarioMinCtrl.text.trim()),
          if (_salarioMaxCtrl.text.trim().isNotEmpty)
            'sueldo_maximo': double.tryParse(_salarioMaxCtrl.text.trim()),
          if (_ubicacionCtrl.text.trim().isNotEmpty)
            'ubicacion': _ubicacionCtrl.text.trim(),
          if (_modalidad != null)    'modalidad': _modalidad,
          if (_tipoContrato != null) 'tipo_contrato': _tipoContrato,
          'estado': _estado,
        },
        auth: true,
      );
      if (!mounted) return;
      await context.read<CompanyProvider>().cargarDashboard(empresaId);
      _snack('Vacante actualizada', AppColors.accentGreen);
      context.pop();
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────
  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar vacante'),
        content: const Text('Esta acción no se puede deshacer. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await ApiService.instance.delete('/vacante/${widget.vacanteId}');
      if (!mounted) return;
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) await context.read<CompanyProvider>().cargarDashboard(id);
      _snack('Vacante eliminada', AppColors.accentGreen);
      context.pop();
    } catch (e) {
      if (mounted) _snack(e.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_cargandoData) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar vacante'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: _guardando ? null : _eliminar,
            tooltip: 'Eliminar vacante',
          ),
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            _sec('Información básica'),
            const SizedBox(height: 16),
            _field(ctrl: _tituloCtrl, label: 'Título del puesto *',
                icon: Icons.work_outline, cardColor: cardColor,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            _field(ctrl: _descCtrl, label: 'Descripción *',
                icon: Icons.description_outlined, cardColor: cardColor,
                maxLines: 4,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            _field(ctrl: _requisitosCtrl, label: 'Requisitos',
                icon: Icons.checklist_outlined, cardColor: cardColor,
                maxLines: 3,
                hint: 'Ej: 2 años de experiencia, inglés intermedio...'),
            const SizedBox(height: 32),

            _sec('Condiciones'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _field(
                ctrl: _salarioMinCtrl, label: 'Sueldo mínimo',
                icon: Icons.attach_money, cardColor: cardColor,
                hint: '15000', keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field(
                ctrl: _salarioMaxCtrl, label: 'Sueldo máximo',
                icon: Icons.attach_money, cardColor: cardColor,
                hint: '20000', keyboard: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            _field(ctrl: _ubicacionCtrl, label: 'Ubicación',
                icon: Icons.location_on_outlined, cardColor: cardColor,
                hint: 'Ciudad, Estado'),
            const SizedBox(height: 24),

            _lbl('Modalidad'), const SizedBox(height: 8),
            Wrap(spacing: 8, children: _modalidades.map((m) {
              final sel = _modalidad == m;
              return ChoiceChip(
                label: Text(_lModal(m)), selected: sel,
                onSelected: (_) =>
                    setState(() => _modalidad = sel ? null : m),
                selectedColor: AppColors.primaryPurple,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : null,
                    fontWeight: FontWeight.w600));
            }).toList()),
            const SizedBox(height: 20),

            _lbl('Tipo de contrato'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _tiposContrato.map((t) {
              final sel = _tipoContrato == t;
              return ChoiceChip(
                label: Text(_lTipo(t)), selected: sel,
                onSelected: (_) =>
                    setState(() => _tipoContrato = sel ? null : t),
                selectedColor: AppColors.primaryPurple,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : null,
                    fontWeight: FontWeight.w600));
            }).toList()),
            const SizedBox(height: 20),

            _lbl('Estado de la vacante'), const SizedBox(height: 8),
            Wrap(spacing: 8, children: _estados.map((e) {
              final sel   = _estado == e;
              final color = _colorEstado(e);
              return ChoiceChip(
                label: Text(_lEstado(e)), selected: sel,
                onSelected: (_) => setState(() => _estado = e),
                selectedColor: color,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : null,
                    fontWeight: FontWeight.w600));
            }).toList()),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar cambios'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sec(String t) => Text(t, style: AppTextStyles.h4);

  Widget _lbl(String t) => Text(t,
      style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary));

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required Color cardColor,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        validator: validator,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryPurple),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: AppColors.primaryPurple, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          filled: true,
          fillColor: cardColor,
        ),
      );

  String _lModal(String m) {
    switch (m) {
      case 'remoto':     return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido':    return 'Híbrido';
      default:           return m;
    }
  }

  String _lTipo(String t) {
    switch (t) {
      case 'tiempo_completo': return 'Tiempo completo';
      case 'medio_tiempo':    return 'Medio tiempo';
      case 'practicas':       return 'Prácticas';
      case 'freelance':       return 'Freelance';
      default:                return t;
    }
  }

  String _lEstado(String e) {
    switch (e) {
      case 'activa':  return 'Activa';
      case 'pausada': return 'Pausada';
      case 'cerrada': return 'Cerrada';
      default:        return e;
    }
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'activa':  return AppColors.accentGreen;
      case 'pausada': return Colors.orange;
      case 'cerrada': return AppColors.error;
      default:        return AppColors.textSecondary;
    }
  }
}