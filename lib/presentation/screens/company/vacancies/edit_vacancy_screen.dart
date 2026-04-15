// lib/presentation/screens/company/vacancies/edit_vacancy_screen.dart
// PUT /vacante/{vacante_id} — VacanteUpdate (todos opcionales)
// Pre-llena TODOS los campos desde la vacante existente

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/company_provider.dart';

class EditVacancyScreen extends StatefulWidget {
  final int vacanteId;
  const EditVacancyScreen({super.key, required this.vacanteId});

  @override
  State<EditVacancyScreen> createState() => _EditVacancyScreenState();
}

class _EditVacancyScreenState extends State<EditVacancyScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _requisitosCtrl;
  late final TextEditingController _ubicacionCtrl;
  late final TextEditingController _sueldoMinCtrl;
  late final TextEditingController _sueldoMaxCtrl;

  late String  _modalidad;
  late String  _moneda;
  late String  _estado;
  String?      _tipoContrato;

  bool _inicializado = false;

  static const _modalidades = ['remoto', 'presencial', 'hibrido'];
  static const _contratos   = [
    'Tiempo completo', 'Medio tiempo', 'Prácticas profesionales',
    'Servicio social', 'Por proyecto', 'Temporal', 'Freelance',
  ];
  static const _monedas = ['MXN', 'USD', 'EUR'];
  static const _estados = ['activa', 'pausada', 'cerrada'];

  @override
  void initState() {
    super.initState();
    _tituloCtrl      = TextEditingController();
    _descripcionCtrl = TextEditingController();
    _requisitosCtrl  = TextEditingController();
    _ubicacionCtrl   = TextEditingController();
    _sueldoMinCtrl   = TextEditingController();
    _sueldoMaxCtrl   = TextEditingController();
    _modalidad       = 'presencial';
    _moneda          = 'MXN';
    _estado          = 'activa';

    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarVacante());
  }

  @override
  void dispose() {
    _tituloCtrl.dispose(); _descripcionCtrl.dispose();
    _requisitosCtrl.dispose(); _ubicacionCtrl.dispose();
    _sueldoMinCtrl.dispose(); _sueldoMaxCtrl.dispose();
    super.dispose();
  }

  // ── Pre-cargar desde el provider ──────────────────────────────────────────
  void _cargarVacante() {
    final vacante = context.read<CompanyProvider>().vacantes
        .firstWhere((v) => v['id'] == widget.vacanteId,
            orElse: () => {});

    if (vacante.isEmpty) {
      // Si no está en cache, intentar cargarla del servidor
      _cargarDesdeServidor();
      return;
    }

    _rellenarCampos(vacante);
  }

  Future<void> _cargarDesdeServidor() async {
    try {
      final vacante = await context.read<CompanyProvider>()
          .getVacante(widget.vacanteId);
      if (vacante != null) _rellenarCampos(vacante);
    } catch (e) {
      debugPrint('[EditVacancy] Error cargando vacante: $e');
    }
  }

  void _rellenarCampos(Map<String, dynamic> v) {
    setState(() {
      _tituloCtrl.text      = v['titulo']      as String? ?? '';
      _descripcionCtrl.text = v['descripcion'] as String? ?? '';
      _requisitosCtrl.text  = v['requisitos']  as String? ?? '';
      _ubicacionCtrl.text   = v['ubicacion']   as String? ?? '';

      final minS = v['sueldo_minimo'];
      final maxS = v['sueldo_maximo'];
      _sueldoMinCtrl.text = minS != null ? minS.toString() : '';
      _sueldoMaxCtrl.text = maxS != null ? maxS.toString() : '';

      _modalidad     = v['modalidad']     as String? ?? 'presencial';
      _moneda        = v['moneda']        as String? ?? 'MXN';
      _estado        = v['estado']        as String? ?? 'activa';
      _tipoContrato  = v['tipo_contrato'] as String?;

      // Validar que los valores estén en las listas
      if (!_modalidades.contains(_modalidad)) _modalidad = 'presencial';
      if (!_monedas.contains(_moneda)) _moneda = 'MXN';
      if (!_estados.contains(_estado)) _estado = 'activa';
      if (_tipoContrato != null && !_contratos.contains(_tipoContrato))
        _tipoContrato = null;

      _inicializado = true;
    });
  }

  // ── Validaciones sueldo cruzadas ──────────────────────────────────────────
  String? _validateMin(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = double.tryParse(v.replaceAll(',', ''));
    if (val == null || val < 0) return 'Ingresa un monto válido';
    final maxV = double.tryParse(_sueldoMaxCtrl.text.replaceAll(',', ''));
    if (maxV != null && val > maxV)
      return 'El mínimo no puede ser mayor al máximo';
    return null;
  }

  String? _validateMax(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = double.tryParse(v.replaceAll(',', ''));
    if (val == null || val < 0) return 'Ingresa un monto válido';
    final minV = double.tryParse(_sueldoMinCtrl.text.replaceAll(',', ''));
    if (minV != null && val < minV)
      return 'El máximo no puede ser menor al mínimo';
    return null;
  }

  // ── Guardar cambios ───────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final minV = double.tryParse(_sueldoMinCtrl.text.replaceAll(',', ''));
    final maxV = double.tryParse(_sueldoMaxCtrl.text.replaceAll(',', ''));
    if (minV != null && maxV != null && minV > maxV) {
      _snack('El sueldo mínimo no puede ser mayor al máximo', isError: true);
      return;
    }

    // VacanteUpdate — todos los campos son opcionales (nullable en el schema)
    // Mandamos TODOS los que tienen valor para no perder datos
    final body = <String, dynamic>{
      'titulo':      _tituloCtrl.text.trim(),
      'descripcion': _descripcionCtrl.text.trim(),
      'modalidad':   _modalidad,
      'estado':      _estado,
    };

    if (_requisitosCtrl.text.trim().isNotEmpty)
      body['requisitos']  = _requisitosCtrl.text.trim();
    if (_ubicacionCtrl.text.trim().isNotEmpty)
      body['ubicacion']   = _ubicacionCtrl.text.trim();
    if (minV != null) body['sueldo_minimo'] = minV;
    if (maxV != null) body['sueldo_maximo'] = maxV;
    if (minV != null || maxV != null) body['moneda'] = _moneda;
    if (_tipoContrato != null) body['tipo_contrato'] = _tipoContrato;

    debugPrint('[EditVacancy] PUT /vacante/${widget.vacanteId} body: $body');

    final ok = await context.read<CompanyProvider>()
        .actualizarVacante(widget.vacanteId, body);

    if (!mounted) return;
    if (ok) {
      _snack('Vacante actualizada correctamente');
      context.pop();
    }
  }

  void _snack(String msg, {bool isError = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 4 : 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).cardColor;

    if (!_inicializado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar vacante'),
            leading: IconButton(icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar vacante'),
        leading: IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop()),
        actions: [
          Consumer<CompanyProvider>(builder: (_, p, __) => TextButton(
            onPressed: p.cargando ? null : _guardar,
            child: p.cargando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Error
            Consumer<CompanyProvider>(builder: (_, p, __) {
              if (p.error == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.error!,
                      style: const TextStyle(color: AppColors.error))),
                  IconButton(icon: const Icon(Icons.close, size: 16),
                      onPressed: () => p.limpiarError()),
                ]),
              );
            }),

            // ── Información básica ─────────────────────────────────────
            _sectionHeader('Información básica', Icons.work_outline),
            const SizedBox(height: 12),

            TextFormField(
              controller: _tituloCtrl,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Título del puesto *', Icons.title, card),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El título es obligatorio' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _descripcionCtrl, maxLines: 5, maxLength: 1000,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Descripción *', Icons.description_outlined, card)
                  .copyWith(alignLabelWithHint: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'La descripción es obligatoria';
                if (v.trim().length < 20) return 'Mínimo 20 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Modalidad
            Text('Modalidad *', style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: _modalidades.asMap().entries.map((e) {
              final m = e.value; final sel = _modalidad == m;
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: e.key < _modalidades.length-1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _modalidad = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primaryPurple : card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? AppColors.primaryPurple : AppColors.borderLight,
                          width: sel ? 2 : 1)),
                    child: Column(children: [
                      Icon(_modalIcon(m), size: 20,
                          color: sel ? Colors.white : AppColors.textSecondary),
                      const SizedBox(height: 4),
                      Text(_lModal(m), style: AppTextStyles.bodySmall.copyWith(
                          color: sel ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),

            // Tipo contrato
            DropdownButtonFormField<String>(
              value: _tipoContrato,
              decoration: _deco('Tipo de contrato', Icons.badge_outlined, card),
              hint: const Text('Sin especificar'),
              dropdownColor: card,
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin especificar')),
                ..._contratos.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _tipoContrato = v),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _ubicacionCtrl,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Ubicación', Icons.location_on_outlined, card)
                  .copyWith(hintText: 'Ciudad, Estado'),
            ),

            // ── Sueldo ─────────────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionHeader('Rango salarial', Icons.attach_money),
            const SizedBox(height: 12),

            // Moneda
            Row(children: [
              const Icon(Icons.currency_exchange, size: 15,
                  color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Moneda:', style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              ..._monedas.map((m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(m), selected: _moneda == m,
                  onSelected: (_) => setState(() => _moneda = m),
                  selectedColor: AppColors.primaryPurple,
                  labelStyle: TextStyle(
                      color: _moneda == m ? Colors.white : null,
                      fontWeight: FontWeight.w600),
                ),
              )),
            ]),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: TextFormField(
                controller: _sueldoMinCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: _deco('Sueldo mínimo', Icons.south, card)
                    .copyWith(prefixText: '\$  '),
                validator: _validateMin,
                onChanged: (_) => _formKey.currentState?.validate(),
              )),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('–', style: AppTextStyles.h4.copyWith(
                      color: AppColors.textSecondary))),
              Expanded(child: TextFormField(
                controller: _sueldoMaxCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: _deco('Sueldo máximo', Icons.north, card)
                    .copyWith(prefixText: '\$  '),
                validator: _validateMax,
                onChanged: (_) => _formKey.currentState?.validate(),
              )),
            ]),

            if (_sueldoMinCtrl.text.isNotEmpty || _sueldoMaxCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_sueldoPreview(), style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accentGreen, fontWeight: FontWeight.w600)),
              ),
            ],

            // ── Requisitos ─────────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionHeader('Requisitos', Icons.checklist_outlined),
            const SizedBox(height: 12),

            TextFormField(
              controller: _requisitosCtrl, maxLines: 4, maxLength: 500,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Requisitos y habilidades', Icons.checklist, card)
                  .copyWith(alignLabelWithHint: true),
            ),

            // ── Estado ─────────────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionHeader('Estado de la vacante', Icons.toggle_on_outlined),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight)),
              child: Row(children: _estados.map((e) {
                final sel = _estado == e;
                return Expanded(child: GestureDetector(
                  onTap: () => setState(() => _estado = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: sel ? _estadoColor(e) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(_lEstado(e),
                        style: AppTextStyles.bodySmall.copyWith(
                            color: sel ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w600))),
                  ),
                ));
              }).toList()),
            ),
            const SizedBox(height: 8),
            Text(_estadoDesc(_estado), style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary)),
            const SizedBox(height: 32),

            Consumer<CompanyProvider>(builder: (_, p, __) => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: p.cargando ? null : _guardar,
                icon: p.cargando
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(p.cargando ? 'Guardando...' : 'Guardar cambios'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            )),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  String _sueldoPreview() {
    final min = _sueldoMinCtrl.text.trim();
    final max = _sueldoMaxCtrl.text.trim();
    if (min.isNotEmpty && max.isNotEmpty) return 'Vista: \$$min – \$$max $_moneda/mes';
    if (min.isNotEmpty) return 'Vista: Desde \$$min $_moneda/mes';
    if (max.isNotEmpty) return 'Vista: Hasta \$$max $_moneda/mes';
    return '';
  }

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
    Icon(icon, size: 18, color: AppColors.primaryPurple),
    const SizedBox(width: 8),
    Text(title, style: AppTextStyles.h4),
  ]);

  InputDecoration _deco(String label, IconData icon, Color fill) =>
    InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primaryPurple),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2)),
      filled: true, fillColor: fill,
    );

  IconData _modalIcon(String m) {
    switch (m) {
      case 'remoto': return Icons.home_work_outlined;
      case 'presencial': return Icons.business_outlined;
      case 'hibrido': return Icons.sync_alt_outlined;
      default: return Icons.work_outline;
    }
  }

  String _lModal(String m) {
    switch (m) {
      case 'remoto': return 'Remoto'; case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido'; default: return m;
    }
  }

  Color _estadoColor(String e) {
    switch (e) {
      case 'activa':  return AppColors.accentGreen;
      case 'pausada': return Colors.orange;
      case 'cerrada': return AppColors.error;
      default:        return AppColors.primaryPurple;
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

  String _estadoDesc(String e) {
    switch (e) {
      case 'activa':  return 'Visible para todos los estudiantes';
      case 'pausada': return 'Visible pero sin nuevas postulaciones';
      case 'cerrada': return 'Puesto cubierto — no visible';
      default:        return '';
    }
  }
}