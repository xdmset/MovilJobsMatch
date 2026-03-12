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

  // ── Paso 1: Cuenta ──────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ── Paso 2: Perfil (todos los campos de PerfilEstudianteCreate) ─
  final _fullNameController = TextEditingController();     // nombre_completo *
  final _universityController = TextEditingController();  // institucion_educativa *
  String _nivelAcademico = 'Licenciatura';                // nivel_academico *
  final _ubicacionController = TextEditingController();   // ubicacion *
  String? _modalidadPreferida;                            // modalidad_preferida
  final _bioController = TextEditingController();         // biografia
  final _habilidadesController = TextEditingController(); // habilidades (texto libre)

  static const _nivelesAcademicos = [
    'Bachillerato / Preparatoria',
    'Técnico Superior Universitario',
    'Licenciatura',
    'Ingeniería',
    'Maestría',
    'Doctorado',
  ];

  static const _modalidades = ['remoto', 'presencial', 'hibrido'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _universityController.dispose();
    _ubicacionController.dispose();
    _bioController.dispose();
    _habilidadesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Navegación ──────────────────────────────────────────────────
  void _nextPage() {
    if (_currentPage == 0) {
      if (_validarPaso1()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _handleRegister();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validarPaso1() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      _showSnack('Ingresa un correo electrónico válido');
      return false;
    }
    if (_passwordController.text.length < 8) {
      _showSnack('La contraseña debe tener al menos 8 caracteres');
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack('Las contraseñas no coinciden');
      return false;
    }
    return true;
  }

  bool _validarPaso2() {
    if (_fullNameController.text.trim().isEmpty) {
      _showSnack('Ingresa tu nombre completo');
      return false;
    }
    if (_universityController.text.trim().isEmpty) {
      _showSnack('Ingresa tu institución educativa');
      return false;
    }
    if (_ubicacionController.text.trim().isEmpty) {
      _showSnack('Ingresa tu ubicación');
      return false;
    }
    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _handleRegister() async {
    if (!_validarPaso2()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // habilidades se envía como string simple tal como lo escribe el usuario
    final habilidadesTexto = _habilidadesController.text.trim();

    final success = await auth.registrarEstudiante(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nombreCompleto: _fullNameController.text.trim(),
      institucionEducativa: _universityController.text.trim(),
      nivelAcademico: _nivelAcademico,
      ubicacion: _ubicacionController.text.trim(),
      biografia: _bioController.text.trim().isNotEmpty
          ? _bioController.text.trim()
          : null,
      habilidades: habilidadesTexto.isNotEmpty ? habilidadesTexto : null,
      modalidadPreferida: _modalidadPreferida,
    );

    if (!mounted) return;
    if (success) context.go(AppRoutes.studentHome);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage > 0) {
              _previousPage();
            } else {
              context.pop();
            }
          },
        ),
        title: Text('Crear cuenta (${_currentPage + 1}/2)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _buildPaso1(),
                  _buildPaso2(),
                ],
              ),
            ),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: List.generate(2, (i) {
          return Expanded(
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
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // PASO 1 – Correo y contraseña
  // ════════════════════════════════════════════════════════════════
  Widget _buildPaso1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¡Empieza tu carrera!', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Crea tu cuenta y conecta con empresas que buscan talento como el tuyo.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'tu@correo.com',
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: 'Mínimo 8 caracteres',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // PASO 2 – Todos los campos del perfil
  // ════════════════════════════════════════════════════════════════
  Widget _buildPaso2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu perfil', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            'Esta información es visible para las empresas que te encuentren.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // ── Campos requeridos ────────────────────────────────────
          _sectionLabel('Datos personales'),
          const SizedBox(height: 12),

          // nombre_completo *
          TextFormField(
            controller: _fullNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nombre completo *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),

          // ubicacion * (ahora requerido)
          TextFormField(
            controller: _ubicacionController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Ubicación *',
              prefixIcon: Icon(Icons.location_on_outlined),
              hintText: 'Ciudad, Estado',
            ),
          ),
          const SizedBox(height: 28),

          // ── Datos académicos ────────────────────────────────────
          _sectionLabel('Formación académica'),
          const SizedBox(height: 12),

          // institucion_educativa *
          TextFormField(
            controller: _universityController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Institución educativa *',
              prefixIcon: Icon(Icons.school_outlined),
              hintText: 'Universidad, instituto, colegio...',
            ),
          ),
          const SizedBox(height: 16),

          // nivel_academico *
          DropdownButtonFormField<String>(
            value: _nivelAcademico,
            decoration: const InputDecoration(
              labelText: 'Nivel académico *',
              prefixIcon: Icon(Icons.military_tech_outlined),
            ),
            items: _nivelesAcademicos
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) =>
                setState(() => _nivelAcademico = v ?? 'Licenciatura'),
          ),
          const SizedBox(height: 28),

          // ── Datos opcionales ────────────────────────────────────
          _sectionLabel('Información adicional (opcional)'),
          const SizedBox(height: 12),

          // modalidad_preferida
          Text('Modalidad preferida', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _modalidades.map((m) {
              final activo = _modalidadPreferida == m;
              return ChoiceChip(
                label: Text(_labelModalidad(m)),
                selected: activo,
                onSelected: (_) =>
                    setState(() => _modalidadPreferida = activo ? null : m),
                selectedColor: AppColors.primaryPurpleLight,
                checkmarkColor: Colors.white,
                labelStyle: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: activo ? Colors.white : AppColors.textPrimary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // habilidades (texto libre separado por comas)
          TextFormField(
            controller: _habilidadesController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Habilidades',
              prefixIcon: Icon(Icons.star_outline),
              hintText: 'Ej: Trabajo en equipo, Excel, Inglés, Liderazgo...',
              helperText: 'Separa cada habilidad con una coma',
            ),
          ),
          const SizedBox(height: 16),

          // biografia
          TextFormField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Sobre ti',
              hintText:
                  'Cuéntanos brevemente quién eres y qué tipo de oportunidades buscas...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),

          // Error banner — muestra el mensaje real del servidor
          Consumer<AuthProvider>(
            builder: (_, auth, __) {
              if (auth.error == null) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accentRed.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        color: AppColors.accentRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.accentRed),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.subtitle1.copyWith(color: AppColors.primaryPurple),
    );
  }

  // ── Bottom buttons ───────────────────────────────────────────────
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (_, auth, __) {
            return Row(
              children: [
                if (_currentPage > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: auth.cargando ? null : _previousPage,
                      child: const Text('Atrás'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: auth.cargando ? null : _nextPage,
                    child: auth.cargando && _currentPage == 1
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _currentPage == 0 ? 'Continuar' : 'Crear cuenta'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _labelModalidad(String m) {
    switch (m) {
      case 'remoto':     return '🏠 Remoto';
      case 'presencial': return '🏢 Presencial';
      case 'hibrido':    return '🔀 Híbrido';
      default:           return m;
    }
  }
}