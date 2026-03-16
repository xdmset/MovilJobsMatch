// lib/presentation/screens/student/profile/student_edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/perfil_provider.dart';

class StudentEditProfileScreen extends StatefulWidget {
  const StudentEditProfileScreen({super.key});

  @override
  State<StudentEditProfileScreen> createState() => _StudentEditProfileScreenState();
}

class _StudentEditProfileScreenState extends State<StudentEditProfileScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _picker         = ImagePicker();
  final _skillInputCtrl = TextEditingController(); // ← nuevo: input de tags

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _institucionCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _ubicacionCtrl;

  String  _nivelAcademico    = 'Licenciatura';
  String? _modalidadPreferida;
  final List<String> _skills = []; // ← lista dinámica, sin chips predefinidos

  static const _niveles = [
    'Bachillerato', 'Técnico Superior Universitario',
    'Licenciatura', 'Ingeniería', 'Maestría', 'Doctorado',
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<PerfilProvider>().perfil;
    _nombreCtrl      = TextEditingController(text: p?.nombreCompleto ?? '');
    _institucionCtrl = TextEditingController(text: p?.institucionEducativa ?? '');
    _bioCtrl         = TextEditingController(text: p?.biografia ?? '');
    _ubicacionCtrl   = TextEditingController(text: p?.ubicacion ?? '');
    _nivelAcademico     = p?.nivelAcademico ?? 'Licenciatura';
    _modalidadPreferida = p?.modalidadPreferida;

    if (p?.habilidades != null && p!.habilidades!.isNotEmpty) {
      _skills.addAll(
        p.habilidades!.split(',').map<String>((s) => s.trim()).where((String s) => s.isNotEmpty),
      );
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _institucionCtrl.dispose();
    _bioCtrl.dispose(); _ubicacionCtrl.dispose();
    _skillInputCtrl.dispose();
    super.dispose();
  }

  int? get _userId => context.read<AuthProvider>().usuario?.id;

  // Agrega una o varias habilidades (separadas por coma)
  void _addSkill() {
    final texto = _skillInputCtrl.text.trim();
    if (texto.isEmpty) return;
    final nuevas = texto.split(',')
        .map<String>((s) => s.trim())
        .where((String s) => s.isNotEmpty && !_skills.contains(s))
        .toList();
    if (nuevas.isNotEmpty) {
      setState(() => _skills.addAll(nuevas));
      _skillInputCtrl.clear();
    }
  }

  String? _buildHabilidades() => _skills.isEmpty ? null : _skills.join(', ');

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final id = _userId; if (id == null) return;

    final ok = await context.read<PerfilProvider>().actualizarPerfil(
      id,
      nombreCompleto:       _nombreCtrl.text.trim(),
      institucionEducativa: _institucionCtrl.text.trim(),
      nivelAcademico:       _nivelAcademico,
      biografia:            _bioCtrl.text.trim().isNotEmpty ? _bioCtrl.text.trim() : null,
      habilidades:          _buildHabilidades(),
      ubicacion:            _ubicacionCtrl.text.trim().isNotEmpty ? _ubicacionCtrl.text.trim() : null,
      modalidadPreferida:   _modalidadPreferida,
    );
    if (!mounted) return;
    if (ok) { _snack('Perfil actualizado', AppColors.accentGreen); context.pop(); }
  }

  Future<void> _pickFoto(ImageSource source) async {
    final id = _userId; if (id == null) return;
    final xfile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null || !mounted) return;
    final ok = await context.read<PerfilProvider>().subirFoto(id, File(xfile.path));
    if (mounted) _snack(ok ? 'Foto actualizada' : context.read<PerfilProvider>().error ?? 'Error',
        ok ? AppColors.accentGreen : AppColors.error);
  }

  Future<void> _eliminarFoto() async {
    final id = _userId; if (id == null) return;
    final ok = await context.read<PerfilProvider>().eliminarFoto(id);
    if (mounted && ok) _snack('Foto eliminada', AppColors.accentGreen);
  }

  Future<void> _pickCv() async {
    final id = _userId; if (id == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    final ok = await context.read<PerfilProvider>().subirCv(id, File(result.files.single.path!));
    if (mounted) _snack(ok ? 'CV subido correctamente' : context.read<PerfilProvider>().error ?? 'Error',
        ok ? AppColors.accentGreen : AppColors.error);
  }

  Future<void> _eliminarCv() async {
    final id = _userId; if (id == null) return;
    final ok = await context.read<PerfilProvider>().eliminarCv(id);
    if (mounted && ok) _snack('CV eliminado', AppColors.accentGreen);
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryPurple,
        title: const Text('Editar perfil', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Consumer<PerfilProvider>(builder: (_, p, __) => TextButton(
            onPressed: p.cargando ? null : _guardar,
            child: p.cargando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Guardar', style: AppTextStyles.button.copyWith(color: Colors.white, fontSize: 16)),
          )),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [

          // Error banner
          Consumer<PerfilProvider>(builder: (_, p, __) {
            if (p.error == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(p.error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
            );
          }),

          _sec('Foto de perfil'), const SizedBox(height: 16),
          _buildFotoSection(), const SizedBox(height: 24),

          _sec('Currículum (CV)'), const SizedBox(height: 16),
          _buildCvSection(), const SizedBox(height: 32),

          _sec('Información personal'), const SizedBox(height: 16),
          _field(ctrl: _nombreCtrl, label: 'Nombre completo', icon: Icons.person_outline,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
          const SizedBox(height: 16),
          _field(ctrl: _ubicacionCtrl, label: 'Ubicación',
              icon: Icons.location_on_outlined, hint: 'Ciudad, Estado'),
          const SizedBox(height: 16),
          _field(ctrl: _bioCtrl, label: 'Biografía', icon: Icons.description_outlined,
              hint: 'Cuéntale a las empresas sobre ti...', maxLines: 4, maxLength: 300),
          const SizedBox(height: 32),

          _sec('Información académica'), const SizedBox(height: 16),
          _field(ctrl: _institucionCtrl, label: 'Institución educativa', icon: Icons.school_outlined,
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _nivelAcademico,
            decoration: _deco('Nivel académico', Icons.military_tech_outlined),
            items: _niveles.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
            onChanged: (v) => setState(() => _nivelAcademico = v!),
          ),
          const SizedBox(height: 32),

          // ── Habilidades: texto libre con tags ──────────────────────────
          _sec('Habilidades'),
          const SizedBox(height: 4),
          Text('Escribe tus habilidades y presiona + o Enter. Puedes escribir varias separadas por comas.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _skillInputCtrl,
                decoration: _deco('Ej: Excel, Inglés, Soldadura, Diseño', Icons.bolt_outlined),
                onFieldSubmitted: (_) => _addSkill(),
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                  color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white), onPressed: _addSkill),
            ),
          ]),
          const SizedBox(height: 12),
          if (_skills.isNotEmpty)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _skills.map((s) => Chip(
                label: Text(s, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _skills.remove(s)),
                backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.3)),
              )).toList(),
            ),
          const SizedBox(height: 32),

          _sec('Modalidad de trabajo'), const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['remoto', 'presencial', 'hibrido'].map((m) {
              final sel = _modalidadPreferida == m;
              return ChoiceChip(
                label: Text(_labelModalidad(m)), selected: sel,
                onSelected: (_) => setState(() => _modalidadPreferida = sel ? null : m),
                selectedColor: AppColors.primaryPurple,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),

          Consumer<PerfilProvider>(builder: (_, p, __) => SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: p.cargando ? null : _guardar,
              child: p.cargando
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar cambios'),
            ),
          )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildFotoSection() => Consumer<PerfilProvider>(builder: (_, p, __) {
    final fotoUrl = p.perfil?.fotoPerfilUrl;
    return Row(children: [
      Stack(children: [
        CircleAvatar(
          radius: 50, backgroundColor: AppColors.primaryPurpleLight,
          backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
          child: (fotoUrl == null || fotoUrl.isEmpty)
              ? Text(_initials(), style: AppTextStyles.h2.copyWith(color: Colors.white)) : null,
        ),
        if (p.uploadingFoto)
          const Positioned.fill(child: Center(child: CircularProgressIndicator())),
      ]),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(
          onPressed: p.uploadingFoto ? null : _showFotoPicker,
          icon: const Icon(Icons.camera_alt, size: 18),
          label: Text(fotoUrl != null ? 'Cambiar foto' : 'Subir foto'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
        ),
        if (fotoUrl != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: p.uploadingFoto ? null : _eliminarFoto,
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            label: const Text('Eliminar foto', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: const BorderSide(color: AppColors.error)),
          ),
        ],
      ])),
    ]);
  });

  Widget _buildCvSection() => Consumer<PerfilProvider>(builder: (_, p, __) {
    final tieneCv = (p.perfil?.cvUrl ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(tieneCv ? Icons.description : Icons.upload_file,
              color: AppColors.primaryPurple, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tieneCv ? 'CV subido' : 'Sin CV', style: AppTextStyles.subtitle1),
            if (tieneCv) Text(p.perfil?.cvTipoArchivo?.toUpperCase() ?? 'PDF',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentGreen)),
          ])),
          if (p.uploadingCv)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: p.uploadingCv ? null : _pickCv,
          icon: const Icon(Icons.file_upload, size: 18),
          label: Text(tieneCv ? 'Reemplazar CV' : 'Subir CV (PDF/DOC)'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
        ),
        if (tieneCv) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: p.uploadingCv ? null : _eliminarCv,
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            label: const Text('Eliminar CV', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: const BorderSide(color: AppColors.error)),
          ),
        ],
      ]),
    );
  });

  void _showFotoPicker() => showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: const Icon(Icons.camera_alt, color: AppColors.accentBlue),
          title: const Text('Tomar foto'),
          onTap: () { Navigator.pop(context); _pickFoto(ImageSource.camera); },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library, color: AppColors.primaryPurple),
          title: const Text('Elegir de galería'),
          onTap: () { Navigator.pop(context); _pickFoto(ImageSource.gallery); },
        ),
        if (context.read<PerfilProvider>().perfil?.fotoPerfilUrl != null)
          ListTile(
            leading: const Icon(Icons.delete, color: AppColors.error),
            title: const Text('Quitar foto', style: TextStyle(color: AppColors.error)),
            onTap: () { Navigator.pop(context); _eliminarFoto(); },
          ),
        const SizedBox(height: 16),
      ])),
    ),
  );

  Widget _sec(String t) => Text(t, style: AppTextStyles.h4);

  Widget _field({required TextEditingController ctrl, required String label, required IconData icon,
      String? hint, int maxLines = 1, int? maxLength, String? Function(String?)? validator}) =>
    TextFormField(controller: ctrl, maxLines: maxLines, maxLength: maxLength, validator: validator,
        decoration: _deco(label, icon).copyWith(hintText: hint));

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: AppColors.primaryPurple),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
    filled: true, fillColor: AppColors.cardBackground,
  );

  String _initials() {
    final n = _nombreCtrl.text.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ').where((s) => s.isNotEmpty).toList();
    return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : parts[0][0].toUpperCase();
  }

  String _labelModalidad(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }
}