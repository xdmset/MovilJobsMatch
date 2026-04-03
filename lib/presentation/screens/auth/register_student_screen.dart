// lib/presentation/screens/auth/register_student_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';

class RegisterStudentScreen extends StatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  State<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends State<RegisterStudentScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // ── Paso 1: Cuenta ────────────────────────────────────────────────────────
  final _emailCtrl          = TextEditingController();
  final _passwordCtrl       = TextEditingController();
  final _confirmCtrl        = TextEditingController();
  bool _obscurePass         = true;
  bool _obscureConfirm      = true;

  // ── Paso 2: Perfil ────────────────────────────────────────────────────────
  final _nombreCtrl         = TextEditingController();
  final _universidadCtrl    = TextEditingController();
  final _ubicacionCtrl      = TextEditingController();
  final _bioCtrl            = TextEditingController();
  final _habilidadesCtrl    = TextEditingController();
  String  _nivelAcademico   = 'Licenciatura';
  String? _modalidad;
  DateTime? _fechaNacimiento;          // ← NUEVO

  static const _niveles = [
    'Bachillerato / Preparatoria',
    'Técnico Superior Universitario',
    'Licenciatura', 'Ingeniería', 'Maestría', 'Doctorado',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose(); _passwordCtrl.dispose(); _confirmCtrl.dispose();
    _nombreCtrl.dispose(); _universidadCtrl.dispose(); _ubicacionCtrl.dispose();
    _bioCtrl.dispose(); _habilidadesCtrl.dispose(); _pageController.dispose();
    super.dispose();
  }

  // ── Navegación ────────────────────────────────────────────────────────────
  void _next() {
    if (_currentPage == 0) {
      if (_validarPaso1()) {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else {
      _handleRegister();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  // ── Validaciones ──────────────────────────────────────────────────────────
  bool _validarPaso1() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _snack('Ingresa un correo electrónico válido'); return false;
    }
    if (_passwordCtrl.text.length < 8) {
      _snack('La contraseña debe tener al menos 8 caracteres'); return false;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _snack('Las contraseñas no coinciden'); return false;
    }
    return true;
  }

  bool _validarPaso2() {
    if (_nombreCtrl.text.trim().isEmpty) {
      _snack('Ingresa tu nombre completo'); return false;
    }
    if (_universidadCtrl.text.trim().isEmpty) {
      _snack('Ingresa tu institución educativa'); return false;
    }
    if (_fechaNacimiento == null) {
      _snack('Selecciona tu fecha de nacimiento'); return false;
    }
    // Mínimo 15 años
    final edad = _calcularEdad(_fechaNacimiento!);
    if (edad < 15) {
      _snack('Debes tener al menos 15 años'); return false;
    }
    return true;
  }

  int _calcularEdad(DateTime nac) {
    final hoy = DateTime.now();
    int edad  = hoy.year - nac.year;
    if (hoy.month < nac.month ||
        (hoy.month == nac.month && hoy.day < nac.day)) edad--;
    return edad;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickFechaNacimiento() async {
    final hoy  = DateTime.now();
    final init = _fechaNacimiento ?? DateTime(hoy.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate:   init,
      firstDate:     DateTime(1950),
      lastDate:      DateTime(hoy.year - 15, hoy.month, hoy.day),
      helpText:      'Fecha de nacimiento',
      confirmText:   'Confirmar',
      cancelText:    'Cancelar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryPurple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  String get _fechaFormateada {
    if (_fechaNacimiento == null) return 'Seleccionar fecha de nacimiento *';
    final d = _fechaNacimiento!;
    const meses = ['ene','feb','mar','abr','may','jun',
                   'jul','ago','sep','oct','nov','dic'];
    final edad = _calcularEdad(d);
    return '${d.day} de ${meses[d.month - 1]} de ${d.year}  ($edad años)';
  }

  String get _fechaIso =>
      '${_fechaNacimiento!.year.toString().padLeft(4,'0')}-'
      '${_fechaNacimiento!.month.toString().padLeft(2,'0')}-'
      '${_fechaNacimiento!.day.toString().padLeft(2,'0')}';

  // ── Registro ──────────────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_validarPaso2()) return;
    final auth = context.read<AuthProvider>();
    final ok   = await auth.registrarEstudiante(
      email:                _emailCtrl.text.trim(),
      password:             _passwordCtrl.text,
      nombreCompleto:       _nombreCtrl.text.trim(),
      institucionEducativa: _universidadCtrl.text.trim(),
      nivelAcademico:       _nivelAcademico,
      fechaNacimiento:      _fechaIso,
      biografia:            _bioCtrl.text.trim().isNotEmpty
                              ? _bioCtrl.text.trim() : null,
      habilidades:          _habilidadesCtrl.text.trim().isNotEmpty
                              ? _habilidadesCtrl.text.trim() : null,
      ubicacion:            _ubicacionCtrl.text.trim().isNotEmpty
                              ? _ubicacionCtrl.text.trim() : null,
      modalidadPreferida:   _modalidad,
    );
    if (!mounted) return;
    if (ok) context.go(AppRoutes.studentHome);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text('Crear cuenta (${_currentPage + 1}/2)'),
      ),
      body: SafeArea(child: Column(children: [
        _buildProgress(),
        Expanded(child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (p) => setState(() => _currentPage = p),
          children: [_buildPaso1(), _buildPaso2()],
        )),
        _buildBottomButtons(),
      ])),
    );
  }

  Widget _buildProgress() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    child: Row(children: List.generate(2, (i) => Expanded(
      child: Container(
        margin: EdgeInsets.only(right: i < 1 ? 8 : 0),
        height: 4,
        decoration: BoxDecoration(
          color: i <= _currentPage
              ? AppColors.primaryPurple : AppColors.borderLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ))),
  );

  Widget _buildPaso1() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Crea tu cuenta', style: AppTextStyles.h2),
      const SizedBox(height: 8),
      Text('Ingresa tu correo y contraseña',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 32),
      _field(_emailCtrl, 'Correo electrónico', Icons.email_outlined,
          keyboard: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _field(_passwordCtrl, 'Contraseña', Icons.lock_outline,
          obscure: _obscurePass,
          suffixIcon: IconButton(
            icon: Icon(_obscurePass
                ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          )),
      const SizedBox(height: 16),
      _field(_confirmCtrl, 'Confirmar contraseña', Icons.lock_outline,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm
                ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          )),
      const SizedBox(height: 24),
      _buildErrorBanner(),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('¿Ya tienes cuenta? ', style: AppTextStyles.bodyMedium),
        TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Inicia sesión')),
      ]),
    ]),
  );

  Widget _buildPaso2() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Datos de tu perfil', style: AppTextStyles.h2),
      const SizedBox(height: 8),
      Text('Esta información aparecerá en tu perfil',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 32),

      _field(_nombreCtrl, 'Nombre completo *', Icons.person_outline),
      const SizedBox(height: 16),

      // ── Date picker de fecha de nacimiento ────────────────────────────────
      GestureDetector(
        onTap: _pickFechaNacimiento,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _fechaNacimiento == null
                  ? AppColors.borderLight : AppColors.primaryPurple,
              width: _fechaNacimiento == null ? 1 : 2,
            ),
          ),
          child: Row(children: [
            Icon(Icons.cake_outlined,
                color: _fechaNacimiento == null
                    ? AppColors.textSecondary : AppColors.primaryPurple),
            const SizedBox(width: 12),
            Expanded(child: Text(_fechaFormateada,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _fechaNacimiento == null
                      ? AppColors.textTertiary : AppColors.textPrimary,
                ))),
            Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.textSecondary),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      _field(_universidadCtrl, 'Institución educativa *', Icons.school_outlined),
      const SizedBox(height: 16),

      DropdownButtonFormField<String>(
        value: _nivelAcademico,
        decoration: _deco('Nivel académico', Icons.military_tech_outlined),
        items: _niveles.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
        onChanged: (v) => setState(() => _nivelAcademico = v!),
      ),
      const SizedBox(height: 16),

      _field(_ubicacionCtrl, 'Ubicación', Icons.location_on_outlined,
          hint: 'Ciudad, Estado'),
      const SizedBox(height: 16),

      _field(_bioCtrl, 'Sobre ti (opcional)', Icons.description_outlined,
          maxLines: 3, hint: 'Cuéntale a las empresas sobre ti...'),
      const SizedBox(height: 16),

      _field(_habilidadesCtrl, 'Habilidades (opcional)', Icons.bolt_outlined,
          hint: 'Ej: Python, Inglés, Excel'),
      const SizedBox(height: 24),

      Text('Modalidad preferida', style: AppTextStyles.subtitle1),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: ['remoto','presencial','hibrido'].map((m) {
        final sel = _modalidad == m;
        return ChoiceChip(
          label: Text(_lModal(m)), selected: sel,
          onSelected: (_) => setState(() => _modalidad = sel ? null : m),
          selectedColor: AppColors.primaryPurple,
          labelStyle: TextStyle(
              color: sel ? Colors.white : null, fontWeight: FontWeight.w600),
        );
      }).toList()),
      const SizedBox(height: 16),
      _buildErrorBanner(),
    ]),
  );

  Widget _buildErrorBanner() => Consumer<AuthProvider>(builder: (_, auth, __) {
    if (auth.error == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(auth.error!,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
    );
  });

  Widget _buildBottomButtons() => Consumer<AuthProvider>(builder: (_, auth, __) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(children: [
        if (_currentPage > 0) ...[
          Expanded(child: OutlinedButton(
            onPressed: auth.cargando ? null : _back,
            child: const Text('Atrás'),
          )),
          const SizedBox(width: 16),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: auth.cargando ? null : _next,
            child: auth.cargando
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(_currentPage == 0 ? 'Continuar' : 'Crear cuenta'),
          ),
        ),
      ]),
    );
  });

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {String? hint, int maxLines = 1, TextInputType? keyboard,
       bool obscure = false, Widget? suffixIcon}) =>
    TextFormField(
      controller: ctrl, maxLines: maxLines,
      obscureText: obscure, keyboardType: keyboard,
      decoration: _deco(label, icon).copyWith(
          hintText: hint, suffixIcon: suffixIcon),
    );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.primaryPurple),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
    filled: true, fillColor: Theme.of(context).cardColor,
  );

  String _lModal(String m) {
    switch (m) {
      case 'remoto': return 'Remoto';
      case 'presencial': return 'Presencial';
      case 'hibrido': return 'Híbrido';
      default: return m;
    }
  }
}