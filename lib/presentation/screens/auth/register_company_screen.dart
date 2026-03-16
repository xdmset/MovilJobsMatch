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

  // ── Paso 1: Cuenta ────────────────────────────────────────────────────────
  final _emailCtrl           = TextEditingController();
  final _passwordCtrl        = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;

  // ── Paso 2: Perfil empresa ────────────────────────────────────────────────
  final _nombreComercialCtrl = TextEditingController(); // nombre_comercial *
  final _sectorCtrl          = TextEditingController(); // sector
  final _descripcionCtrl     = TextEditingController(); // descripcion
  final _sitioWebCtrl        = TextEditingController(); // sitio_web
  final _ubicacionSedeCtrl   = TextEditingController(); // ubicacion_sede

  static const _sectores = [
    'Tecnología', 'Manufactura', 'Salud', 'Educación', 'Finanzas',
    'Retail / Comercio', 'Logística', 'Construcción', 'Alimentos',
    'Turismo / Hospitalidad', 'Medios / Entretenimiento', 'Consultoría',
    'Energía', 'Gobierno / Sector público', 'Otro',
  ];
  String? _sectorSeleccionado;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose(); _nombreComercialCtrl.dispose();
    _sectorCtrl.dispose(); _descripcionCtrl.dispose();
    _sitioWebCtrl.dispose(); _ubicacionSedeCtrl.dispose();
    _pageController.dispose();
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
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _snack('Las contraseñas no coinciden'); return false;
    }
    return true;
  }

  bool _validarPaso2() {
    if (_nombreComercialCtrl.text.trim().isEmpty) {
      _snack('Ingresa el nombre de tu empresa'); return false;
    }
    return true;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  // ── Registro ──────────────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_validarPaso2()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final success = await auth.registrarEmpresa(
      email:          _emailCtrl.text.trim(),
      password:       _passwordCtrl.text,
      nombreComercial: _nombreComercialCtrl.text.trim(),
      sector:         _sectorSeleccionado,
      descripcion:    _descripcionCtrl.text.trim().isNotEmpty
                        ? _descripcionCtrl.text.trim() : null,
      sitioWeb:       _sitioWebCtrl.text.trim().isNotEmpty
                        ? _sitioWebCtrl.text.trim() : null,
      ubicacionSede:  _ubicacionSedeCtrl.text.trim().isNotEmpty
                        ? _ubicacionSedeCtrl.text.trim() : null,
    );

    if (!mounted) return;
    if (success) context.go(AppRoutes.companyHome);
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
        title: Text('Crear cuenta empresa (${_currentPage + 1}/2)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [_buildPaso1(), _buildPaso2()],
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  // ── Indicador de progreso ─────────────────────────────────────────────────
  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(2, (i) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 1 ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: i <= _currentPage
                  ? AppColors.primaryPurple
                  : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )),
      ),
    );
  }

  // ── Paso 1: Cuenta ────────────────────────────────────────────────────────
  Widget _buildPaso1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Crea tu cuenta', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('Ingresa el correo y contraseña de tu empresa',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 32),

        // Email
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _deco('Correo electrónico', Icons.email_outlined),
        ),
        const SizedBox(height: 16),

        // Password
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          decoration: _deco('Contraseña', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm password
        TextFormField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscureConfirmPassword,
          decoration: _deco('Confirmar contraseña', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Error banner
        Consumer<AuthProvider>(builder: (_, auth, __) {
          if (auth.error == null) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(auth.error!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
          );
        }),

        // Ya tienes cuenta
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('¿Ya tienes cuenta? ', style: AppTextStyles.bodyMedium),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Inicia sesión'),
          ),
        ]),
      ]),
    );
  }

  // ── Paso 2: Perfil empresa ────────────────────────────────────────────────
  Widget _buildPaso2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Datos de tu empresa', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text('Esta información aparecerá en tu perfil público',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 32),

        // Nombre comercial *
        TextFormField(
          controller: _nombreComercialCtrl,
          decoration: _deco('Nombre de la empresa *', Icons.business_outlined),
        ),
        const SizedBox(height: 16),

        // Sector — dropdown
        DropdownButtonFormField<String>(
          value: _sectorSeleccionado,
          decoration: _deco('Sector', Icons.category_outlined),
          hint: const Text('Selecciona un sector'),
          items: _sectores.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _sectorSeleccionado = v),
        ),
        const SizedBox(height: 16),

        // Descripción
        TextFormField(
          controller: _descripcionCtrl,
          maxLines: 3,
          maxLength: 300,
          decoration: _deco('Descripción', Icons.description_outlined).copyWith(
            hintText: 'Cuéntanos sobre tu empresa...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),

        // Sitio web
        TextFormField(
          controller: _sitioWebCtrl,
          keyboardType: TextInputType.url,
          decoration: _deco('Sitio web', Icons.language_outlined).copyWith(
            hintText: 'https://tuempresa.com',
          ),
        ),
        const SizedBox(height: 16),

        // Ubicación sede
        TextFormField(
          controller: _ubicacionSedeCtrl,
          decoration: _deco('Ubicación de la sede', Icons.location_on_outlined).copyWith(
            hintText: 'Ciudad, Estado',
          ),
        ),
        const SizedBox(height: 16),

        // Error banner
        Consumer<AuthProvider>(builder: (_, auth, __) {
          if (auth.error == null) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(auth.error!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
          );
        }),
      ]),
    );
  }

  // ── Botones inferiores ────────────────────────────────────────────────────
  Widget _buildBottomButtons() {
    return Consumer<AuthProvider>(builder: (_, auth, __) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(children: [
          if (_currentPage > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: auth.cargando ? null : _back,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: auth.cargando ? null : _next,
              child: auth.cargando
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentPage == 0 ? 'Continuar' : 'Crear cuenta'),
            ),
          ),
        ]),
      );
    });
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.primaryPurple),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2)),
    filled: true,
    fillColor: AppColors.cardBackground,
  );
}