// lib/presentation/screens/company/vacancies/create_vacancy_screen.dart
//
// API: POST /vacante/{empresa_id}
// empresa_id va en el PATH (no en el body)
// Requeridos en body: titulo, descripcion, modalidad
// Opcionales: requisitos, tipo_contrato, ubicacion,
//             sueldo_minimo, sueldo_maximo, moneda, estado

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';

class CreateVacancyScreen extends StatefulWidget {
  const CreateVacancyScreen({super.key});
  @override
  State<CreateVacancyScreen> createState() => _CreateVacancyScreenState();
}

class _CreateVacancyScreenState extends State<CreateVacancyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campos requeridos
  final _tituloCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  String _modalidad      = 'presencial';

  // Campos opcionales
  final _requisitosCtrl = TextEditingController();
  final _ubicacionCtrl  = TextEditingController();
  final _sueldoMinCtrl  = TextEditingController();
  final _sueldoMaxCtrl  = TextEditingController();
  String  _moneda        = 'MXN';
  String? _tipoContrato;
  String  _estado        = 'activa';

  static const _modalidades = ['remoto', 'presencial', 'hibrido'];
  static const _contratos   = [
    'Tiempo completo', 'Medio tiempo', 'Prácticas profesionales',
    'Servicio social', 'Por proyecto', 'Temporal', 'Freelance',
  ];
  static const _monedas = ['MXN', 'USD', 'EUR'];
  static const _estados = ['activa', 'pausada', 'cerrada'];

  @override
  void dispose() {
    _tituloCtrl.dispose(); _descripcionCtrl.dispose();
    _requisitosCtrl.dispose(); _ubicacionCtrl.dispose();
    _sueldoMinCtrl.dispose(); _sueldoMaxCtrl.dispose();
    super.dispose();
  }

  // ── Validaciones de sueldo cruzadas ───────────────────────────────────────
  String? _validateSueldoMin(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = double.tryParse(v.replaceAll(',', ''));
    if (val == null || val < 0) return 'Ingresa un monto válido (mayor a 0)';
    final maxV = double.tryParse(_sueldoMaxCtrl.text.replaceAll(',', ''));
    if (maxV != null && val > maxV) {
      return 'El mínimo (\$$val) no puede ser mayor al máximo (\$$maxV)';
    }
    return null;
  }

  String? _validateSueldoMax(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = double.tryParse(v.replaceAll(',', ''));
    if (val == null || val < 0) return 'Ingresa un monto válido (mayor a 0)';
    final minV = double.tryParse(_sueldoMinCtrl.text.replaceAll(',', ''));
    if (minV != null && val < minV) {
      return 'El máximo (\$$val) no puede ser menor al mínimo (\$$minV)';
    }
    return null;
  }

  // ── Publicar vacante ──────────────────────────────────────────────────────
  Future<void> _publicar() async {
    // Limpiar error previo
    context.read<CompanyProvider>().limpiarError();

    if (!_formKey.currentState!.validate()) return;

    final minV = double.tryParse(_sueldoMinCtrl.text.replaceAll(',', ''));
    final maxV = double.tryParse(_sueldoMaxCtrl.text.replaceAll(',', ''));

    // Guardia extra de sueldos
    if (minV != null && maxV != null && minV > maxV) {
      _snack('El sueldo mínimo no puede ser mayor al máximo', isError: true);
      return;
    }

    // empresa_id viene del usuario autenticado (va en el PATH del endpoint)
    final empresaId = context.read<AuthProvider>().usuario?.id;
    if (empresaId == null) {
      _snack('No se pudo identificar tu empresa. Cierra sesión e inicia de nuevo.',
          isError: true);
      return;
    }

    // Body del request — solo los campos con valor
    final body = <String, dynamic>{
      'titulo':      _tituloCtrl.text.trim(),
      'descripcion': _descripcionCtrl.text.trim(),
      'modalidad':   _modalidad,
      'estado':      _estado,
      if (_requisitosCtrl.text.trim().isNotEmpty)
        'requisitos': _requisitosCtrl.text.trim(),
      if (_ubicacionCtrl.text.trim().isNotEmpty)
        'ubicacion':  _ubicacionCtrl.text.trim(),
      if (minV != null) 'sueldo_minimo': minV,
      if (maxV != null) 'sueldo_maximo': maxV,
      if (minV != null || maxV != null) 'moneda': _moneda,
      if (_tipoContrato != null) 'tipo_contrato': _tipoContrato,
    };

    debugPrint('[CreateVacancy] POST /vacante/$empresaId body: $body');

    final ok = await context.read<CompanyProvider>()
        .crearVacante(empresaId, body);

    if (!mounted) return;
    if (ok) {
      _snack('¡Vacante publicada exitosamente!');
      context.pop();
    }
    // Si falla, el error se muestra en el banner del provider
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar vacante'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          Consumer<CompanyProvider>(builder: (_, p, __) => TextButton(
            onPressed: p.cargando ? null : _publicar,
            child: p.cargando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Publicar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Error del provider ─────────────────────────────────────
            Consumer<CompanyProvider>(builder: (_, p, __) {
              if (p.error == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
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

            // ══════════════════════════════════════════════════════════
            _sectionHeader('Información básica', Icons.work_outline),
            const SizedBox(height: 12),

            // Título *
            TextFormField(
              controller: _tituloCtrl,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Título del puesto *', Icons.title, card)
                  .copyWith(hintText: 'Ej: Desarrollador Flutter Jr.'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El título del puesto es obligatorio';
                }
                if (v.trim().length < 3) {
                  return 'El título debe tener al menos 3 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Descripción *
            TextFormField(
              controller: _descripcionCtrl, maxLines: 5, maxLength: 1000,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Descripción del puesto *',
                  Icons.description_outlined, card)
                  .copyWith(
                    hintText: 'Describe las responsabilidades, el equipo de trabajo y lo que ofrecen...',
                    alignLabelWithHint: true,
                  ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'La descripción es obligatoria';
                }
                if (v.trim().length < 20) {
                  return 'Describe mejor el puesto (mínimo 20 caracteres)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Modalidad *
            Text('Modalidad de trabajo *',
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: _modalidades.asMap().entries.map((entry) {
              final m   = entry.value;
              final sel = _modalidad == m;
              final isLast = entry.key == _modalidades.length - 1;
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
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

            // Tipo de contrato
            Text('Tipo de contrato',
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tipoContrato,
              decoration: _deco('Selecciona el tipo', Icons.badge_outlined, card),
              hint: const Text('Sin especificar'),
              dropdownColor: card,
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin especificar')),
                ..._contratos.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _tipoContrato = v),
            ),
            const SizedBox(height: 14),

            // Ubicación
            TextFormField(
              controller: _ubicacionCtrl,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Ubicación', Icons.location_on_outlined, card)
                  .copyWith(hintText: 'Ciudad, Estado (o "Remoto")'),
            ),

            // ══════════════════════════════════════════════════════════
            const SizedBox(height: 28),
            _sectionHeader('Rango salarial', Icons.attach_money),
            const SizedBox(height: 4),
            Text('Publicar el sueldo atrae un 40% más de candidatos',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary)),
            const SizedBox(height: 12),

            // Moneda
            Row(children: [
              const Icon(Icons.currency_exchange, size: 15,
                  color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Moneda:',
                  style: AppTextStyles.bodySmall.copyWith(
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

            // Sueldos min / max
            Row(children: [
              Expanded(child: TextFormField(
                controller: _sueldoMinCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: _deco('Sueldo mínimo', Icons.south, card)
                    .copyWith(prefixText: '\$  '),
                validator: _validateSueldoMin,
                onChanged: (_) => _formKey.currentState?.validate(),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('–',
                    style: AppTextStyles.h4.copyWith(
                        color: AppColors.textSecondary)),
              ),
              Expanded(child: TextFormField(
                controller: _sueldoMaxCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: _deco('Sueldo máximo', Icons.north, card)
                    .copyWith(prefixText: '\$  '),
                validator: _validateSueldoMax,
                onChanged: (_) => _formKey.currentState?.validate(),
              )),
            ]),

            // Preview sueldo
            if (_sueldoMinCtrl.text.isNotEmpty || _sueldoMaxCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.preview_outlined, size: 15,
                      color: AppColors.accentGreen),
                  const SizedBox(width: 8),
                  Text(_sueldoPreview(),
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.accentGreen,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ],

            // ══════════════════════════════════════════════════════════
            const SizedBox(height: 28),
            _sectionHeader('Requisitos', Icons.checklist_outlined),
            const SizedBox(height: 12),

            TextFormField(
              controller: _requisitosCtrl, maxLines: 4, maxLength: 500,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: _deco('Requisitos y habilidades',
                  Icons.checklist, card)
                  .copyWith(
                    hintText: 'Ej: 1 año de experiencia, inglés intermedio, conocimiento en Flutter...',
                    alignLabelWithHint: true,
                  ),
            ),

            // ══════════════════════════════════════════════════════════
            const SizedBox(height: 28),
            _sectionHeader('Estado inicial', Icons.toggle_on_outlined),
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
            Row(children: [
              Icon(_estadoIcon(_estado), size: 14, color: _estadoColor(_estado)),
              const SizedBox(width: 6),
              Flexible(child: Text(_estadoDesc(_estado),
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary))),
            ]),
            const SizedBox(height: 32),

            // Botón publicar
            Consumer<CompanyProvider>(builder: (_, p, __) => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: p.cargando ? null : _publicar,
                icon: p.cargando
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.publish_outlined),
                label: Text(p.cargando ? 'Publicando...' : 'Publicar vacante'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            )),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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
      case 'remoto':     return Icons.home_work_outlined;
      case 'presencial': return Icons.business_outlined;
      case 'hibrido':    return Icons.sync_alt_outlined;
      default:           return Icons.work_outline;
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

  IconData _estadoIcon(String e) {
    switch (e) {
      case 'activa':  return Icons.check_circle_outline;
      case 'pausada': return Icons.pause_circle_outline;
      case 'cerrada': return Icons.cancel_outlined;
      default:        return Icons.info_outline;
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
      case 'activa':  return 'Visible para todos los estudiantes inmediatamente';
      case 'pausada': return 'Visible pero no recibe nuevas postulaciones';
      case 'cerrada': return 'Puesto cubierto — no visible para estudiantes';
      default:        return '';
    }
  }
}