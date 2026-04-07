// lib/presentation/screens/auth/register_company_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Paso 1
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  // Paso 2
  final _nombreCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _sitioWebCtrl    = TextEditingController();
  final _ubicacionCtrl   = TextEditingController();
  String? _sector;

  static const _sectores = [
    'Tecnología', 'Manufactura', 'Salud', 'Educación', 'Finanzas',
    'Retail / Comercio', 'Logística', 'Construcción', 'Alimentos',
    'Turismo / Hospitalidad', 'Medios / Entretenimiento', 'Consultoría',
    'Energía', 'Gobierno / Sector público', 'Otro',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    _nombreCtrl.dispose(); _descripcionCtrl.dispose();
    _sitioWebCtrl.dispose(); _ubicacionCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == 0) {
      if (_validarPaso1()) {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
      }
    } else {
      _registrar();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  bool _validarPaso1() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _snack('Ingresa un correo válido'); return false;
    }
    if (_passCtrl.text.length < 8) {
      _snack('La contraseña debe tener al menos 8 caracteres'); return false;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _snack('Las contraseñas no coinciden'); return false;
    }
    return true;
  }

  bool _validarPaso2() {
    if (_nombreCtrl.text.trim().isEmpty) {
      _snack('Ingresa el nombre de tu empresa'); return false;
    }
    return true;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  Future<void> _registrar() async {
    if (!_validarPaso2()) return;
    final auth = context.read<AuthProvider>();
    final ok   = await auth.registrarEmpresa(
      email:           _emailCtrl.text.trim(),
      password:        _passCtrl.text,
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
    if (ok) context.go(AppRoutes.companyHome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text('Registro empresa — Paso ${_currentPage + 1} de 2'),
      ),
      body: SafeArea(child: Column(children: [
        _buildProgreso(),
        Expanded(child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (p) => setState(() => _currentPage = p),
          children: [_buildPaso1(), _buildPaso2()],
        )),
        _buildBotones(),
      ])),
    );
  }

  Widget _buildProgreso() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    child: Row(children: List.generate(2, (i) => Expanded(
      child: Container(
        margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
        height: 4,
        decoration: BoxDecoration(
          color: i <= _currentPage
              ? AppColors.accentBlue : AppColors.borderLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ))),
  );

  Widget _buildPaso1() {
    final cardColor = Theme.of(context).cardColor;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Datos de acceso', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('Crea las credenciales de tu cuenta empresarial',
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary)),
        const SizedBox(height: 32),

        _field(_emailCtrl, 'Correo electrónico *', Icons.email_outlined,
            cardColor, keyboard: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _field(_passCtrl, 'Contraseña *', Icons.lock_outline, cardColor,
            obscure: _obscurePass,
            suffix: IconButton(
              icon: Icon(_obscurePass
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            )),
        const SizedBox(height: 16),
        _field(_confirmCtrl, 'Confirmar contraseña *',
            Icons.lock_outline, cardColor,
            obscure: _obscureConfirm,
            suffix: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            )),
        const SizedBox(height: 24),
        _buildErrorBanner(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('¿Ya tienes cuenta? ',
              style: AppTextStyles.bodyMedium),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Iniciar sesión'),
          ),
        ]),
      ]),
    );
  }

  Widget _buildPaso2() {
    final cardColor = Theme.of(context).cardColor;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Perfil de la empresa', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('Esta información aparecerá en tu perfil público',
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary)),
        const SizedBox(height: 32),

        _field(_nombreCtrl, 'Nombre comercial *', Icons.business_outlined,
            cardColor),
        const SizedBox(height: 16),

        // Sector — dropdown con fill adaptado al tema
        DropdownButtonFormField<String>(
          value: _sector,
          decoration: InputDecoration(
            labelText: 'Sector',
            prefixIcon: const Icon(Icons.category_outlined,
                color: AppColors.accentBlue),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.accentBlue, width: 2),
            ),
            filled: true,
            fillColor: cardColor,        // ← se adapta al tema oscuro
          ),
          hint: const Text('Selecciona un sector'),
          dropdownColor: cardColor,      // ← dropdown también adaptado
          items: _sectores
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _sector = v),
        ),
        const SizedBox(height: 16),

        _field(_descripcionCtrl, 'Descripción', Icons.description_outlined,
            cardColor, maxLines: 3, maxLength: 300,
            hint: 'Cuéntanos sobre tu empresa...'),
        const SizedBox(height: 16),

        _field(_sitioWebCtrl, 'Sitio web', Icons.language_outlined,
            cardColor, hint: 'https://tuempresa.com',
            keyboard: TextInputType.url),
        const SizedBox(height: 16),

        _field(_ubicacionCtrl, 'Ciudad / Sede', Icons.location_on_outlined,
            cardColor, hint: 'Ciudad, Estado'),
        const SizedBox(height: 16),

        _buildErrorBanner(),
      ]),
    );
  }

  Widget _buildErrorBanner() =>
    Consumer<AuthProvider>(builder: (_, auth, __) {
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

  Widget _buildBotones() => Consumer<AuthProvider>(builder: (_, auth, __) {
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue),
            child: auth.cargando
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(_currentPage == 0 ? 'Continuar' : 'Crear cuenta',
                    style: const TextStyle(color: Colors.white)),
          ),
        ),
      ]),
    );
  });

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      Color cardColor, {
    String? hint, int maxLines = 1, int? maxLength,
    bool obscure = false, Widget? suffix,
    TextInputType? keyboard,
  }) =>
    TextFormField(
      controller: ctrl,
      maxLines: maxLines, maxLength: maxLength,
      obscureText: obscure, keyboardType: keyboard,
      style: TextStyle(          // ← texto siempre visible en modo oscuro
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.accentBlue),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.accentBlue, width: 2),
        ),
        filled: true,
        fillColor: cardColor,    // ← fondo adaptado al tema
      ),
    );
}