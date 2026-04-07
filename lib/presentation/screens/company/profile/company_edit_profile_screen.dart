// lib/presentation/screens/company/profile/company_edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/repositories/media_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';

class CompanyEditProfileScreen extends StatefulWidget {
  const CompanyEditProfileScreen({super.key});

  @override
  State<CompanyEditProfileScreen> createState() =>
      _CompanyEditProfileScreenState();
}

class _CompanyEditProfileScreenState extends State<CompanyEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker  = ImagePicker();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _sitioWebCtrl;
  late final TextEditingController _ubicacionCtrl;
  String? _sector;
  bool _uploadingFoto = false;

  static const _sectores = [
    'Tecnología', 'Manufactura', 'Salud', 'Educación', 'Finanzas',
    'Retail / Comercio', 'Logística', 'Construcción', 'Alimentos',
    'Turismo / Hospitalidad', 'Medios / Entretenimiento', 'Consultoría',
    'Energía', 'Gobierno / Sector público', 'Otro',
  ];

  @override
  void initState() {
    super.initState();
    final p          = context.read<CompanyProvider>().perfil;
    _nombreCtrl      = TextEditingController(text: p?.nombreComercial ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion     ?? '');
    _sitioWebCtrl    = TextEditingController(text: p?.sitioWeb        ?? '');
    _ubicacionCtrl   = TextEditingController(text: p?.ubicacionSede   ?? '');
    _sector          = p?.sector;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _descripcionCtrl.dispose();
    _sitioWebCtrl.dispose(); _ubicacionCtrl.dispose();
    super.dispose();
  }

  int? get _userId => context.read<AuthProvider>().usuario?.id;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final id = _userId; if (id == null) return;

    final ok = await context.read<CompanyProvider>().actualizarPerfil(
      id,
      nombreComercial: _nombreCtrl.text.trim(),
      sector:          _sector,
      descripcion:     _descripcionCtrl.text.trim().isNotEmpty
                         ? _descripcionCtrl.text.trim() : null,
      sitioWeb:        _sitioWebCtrl.text.trim().isNotEmpty
                         ? _sitioWebCtrl.text.trim() : null,
      ubicacionSede:   _ubicacionCtrl.text.trim().isNotEmpty
                         ? _ubicacionCtrl.text.trim() : null,
    );

    if (!mounted) return;
    if (ok) {
      _snack('Perfil actualizado correctamente');
      context.pop();
    }
    // El error se muestra via Consumer en el build
  }

  Future<void> _pickFoto(ImageSource source) async {
    final id = _userId; if (id == null) return;
    final xfile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null || !mounted) return;
    setState(() => _uploadingFoto = true);
    try {
      await MediaRepository.instance.uploadFotoEmpresa(id, File(xfile.path));
      // Recargar perfil para mostrar nueva foto
      await context.read<CompanyProvider>().cargarPerfil(id);
      if (mounted) _snack('Logo actualizado');
    } catch (e) {
      if (mounted) _snack('Error al subir la foto', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingFoto = false);
    }
  }

  void _showFotoPicker() => showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: const Icon(Icons.camera_alt, color: AppColors.accentBlue),
          title: const Text('Tomar foto'),
          onTap: () { Navigator.pop(context); _pickFoto(ImageSource.camera); }),
        ListTile(
          leading: const Icon(Icons.photo_library, color: AppColors.primaryPurple),
          title: const Text('Elegir de galería'),
          onTap: () { Navigator.pop(context); _pickFoto(ImageSource.gallery); }),
        const SizedBox(height: 8),
      ])),
    ),
  );

  void _snack(String msg, {bool isError = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil empresa'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
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
        child: ListView(padding: const EdgeInsets.all(16), children: [

          // ── Error del provider ────────────────────────────────────────
          Consumer<CompanyProvider>(builder: (_, p, __) {
            if (p.error == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(p.error!,
                    style: const TextStyle(color: AppColors.error))),
              ]),
            );
          }),

          // ── Logo ──────────────────────────────────────────────────────
          _seccion('Logo / Foto de empresa', Icons.business_outlined),
          const SizedBox(height: 12),
          Consumer<CompanyProvider>(builder: (_, p, __) {
            final fotoUrl  = p.perfil?.fotoPerfilUrl;
            final inicial  = (_nombreCtrl.text.trim().isNotEmpty
                ? _nombreCtrl.text.trim()[0] : '?').toUpperCase();
            return Row(children: [
              Stack(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.accentBlue.withOpacity(0.15),
                  child: (fotoUrl == null || fotoUrl.isEmpty)
                      ? Text(inicial, style: AppTextStyles.h3.copyWith(
                          color: AppColors.accentBlue))
                      : ClipOval(child: Image.network(fotoUrl,
                          width: 88, height: 88, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(inicial,
                              style: AppTextStyles.h3.copyWith(
                                  color: AppColors.accentBlue)))),
                ),
                if (_uploadingFoto)
                  const Positioned.fill(child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2))),
              ]),
              const SizedBox(width: 20),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _uploadingFoto ? null : _showFotoPicker,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(fotoUrl != null && fotoUrl.isNotEmpty
                        ? 'Cambiar logo' : 'Subir logo'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        minimumSize: const Size(double.infinity, 44)),
                  ),
                  const SizedBox(height: 4),
                  Text('Recomendado: imagen cuadrada',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary),
                      textAlign: TextAlign.center),
                ],
              )),
            ]);
          }),

          // ── Información ───────────────────────────────────────────────
          const SizedBox(height: 28),
          _seccion('Información de la empresa', Icons.info_outline),
          const SizedBox(height: 14),

          _field(_nombreCtrl, 'Nombre comercial *', Icons.business, card,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre comercial es obligatorio' : null),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _sector,
            decoration: _deco('Sector / Industria', Icons.category_outlined, card),
            hint: const Text('Selecciona el sector de tu empresa'),
            dropdownColor: card,
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin especificar')),
              ..._sectores.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            ],
            onChanged: (v) => setState(() => _sector = v),
          ),
          const SizedBox(height: 14),

          _field(_descripcionCtrl, 'Descripción de la empresa',
              Icons.description_outlined, card,
              maxLines: 4, maxLength: 500,
              hint: 'Cuéntale a los candidatos sobre tu empresa, cultura y valores...'),
          const SizedBox(height: 14),

          _field(_sitioWebCtrl, 'Sitio web', Icons.language_outlined, card,
              hint: 'https://tuempresa.com',
              keyboard: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final url = v.trim();
                if (!url.startsWith('http://') && !url.startsWith('https://'))
                  return 'Debe empezar con http:// o https://';
                return null;
              }),
          const SizedBox(height: 14),

          _field(_ubicacionCtrl, 'Ciudad / Sede principal',
              Icons.location_on_outlined, card,
              hint: 'Ej: Tijuana, Baja California'),
          const SizedBox(height: 32),

          Consumer<CompanyProvider>(builder: (_, p, __) =>
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: p.cargando ? null : _guardar,
                icon: p.cargando
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(p.cargando ? 'Guardando...' : 'Guardar cambios'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.accentBlue),
              ),
            )),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _seccion(String title, IconData icon) => Row(children: [
    Icon(icon, size: 18, color: AppColors.accentBlue),
    const SizedBox(width: 8),
    Text(title, style: AppTextStyles.h4),
  ]);

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      Color card, {
    String? hint, int maxLines = 1, int? maxLength,
    TextInputType? keyboard, String? Function(String?)? validator,
  }) =>
    TextFormField(
      controller: ctrl, maxLines: maxLines, maxLength: maxLength,
      keyboardType: keyboard,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: _deco(label, icon, card).copyWith(hintText: hint),
      validator: validator,
    );

  InputDecoration _deco(String label, IconData icon, Color fill) =>
    InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.accentBlue),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2)),
      filled: true, fillColor: fill,
    );
}