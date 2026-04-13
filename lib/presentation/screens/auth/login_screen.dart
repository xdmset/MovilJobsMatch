// lib/presentation/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';

// Tipo de acceso: el usuario elige antes de introducir credenciales
enum _TipoAcceso { estudiante, empresa }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool  _obscure   = true;

  // El usuario selecciona su rol antes de entrar
  _TipoAcceso _tipoAcceso = _TipoAcceso.estudiante;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.limpiarError();

    final ok = await auth.login(
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (!ok) return; // El error ya está en auth.error

    // ── Validar que el rol coincida con lo que eligió el usuario ──────────
    final esEmpresaReal    = auth.esEmpresa;
    final esEstudianteReal = auth.esEstudiante;
    final eligioEmpresa    = _tipoAcceso == _TipoAcceso.empresa;

    if (eligioEmpresa && !esEmpresaReal) {
      // Inició como empresa pero es estudiante
      await auth.logout();
      if (!mounted) return;
      _mostrarErrorRol(
        '👤 Esta cuenta es de estudiante',
        'Usa la opción "Soy estudiante" para ingresar con esta cuenta.',
      );
      return;
    }

    if (!eligioEmpresa && !esEstudianteReal) {
      // Inició como estudiante pero es empresa
      await auth.logout();
      if (!mounted) return;
      _mostrarErrorRol(
        '🏢 Esta cuenta es de empresa',
        'Usa la opción "Soy empresa" para ingresar con esta cuenta.',
      );
      return;
    }

    // Navegar a la pantalla correcta
    context.go(esEmpresaReal ? AppRoutes.companyHome : AppRoutes.studentHome);
  }

  void _mostrarErrorRol(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo, style: AppTextStyles.h4),
        content: Text(mensaje, style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary, height: 1.5)),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Cambiar el selector al rol correcto automáticamente
                setState(() {
                  _tipoAcceso = titulo.contains('estudiante')
                      ? _TipoAcceso.estudiante
                      : _TipoAcceso.empresa;
                });
              },
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Iniciar sesión'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ──────────────────────────────────────────────
                Text('¡Bienvenido de vuelta!', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(
                  'Elige cómo quieres ingresar e introduce tus credenciales.',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),

                // ── Selector de rol ──────────────────────────────────────
                _buildRolSelector(),
                const SizedBox(height: 24),

                // ── Email ────────────────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => context.read<AuthProvider>().limpiarError(),
                  decoration: _deco('Correo electrónico',
                      Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Ingresa tu correo';
                    if (!v.contains('@') || !v.contains('.'))
                      return 'Correo no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Contraseña ───────────────────────────────────────────
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  onChanged: (_) => context.read<AuthProvider>().limpiarError(),
                  decoration: _deco('Contraseña', Icons.lock_outline)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Ingresa tu contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Error del API ────────────────────────────────────────
                Consumer<AuthProvider>(builder: (_, auth, __) {
                  final err = auth.error;
                  if (err == null) return const SizedBox.shrink();
                  return _buildErrorBanner(err);
                }),

                // ── Botón ingresar ───────────────────────────────────────
                Consumer<AuthProvider>(builder: (_, auth, __) =>
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.cargando ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tipoAcceso == _TipoAcceso.empresa
                            ? AppColors.accentBlue
                            : AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: auth.cargando
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_tipoAcceso == _TipoAcceso.empresa
                                    ? Icons.business_outlined
                                    : Icons.school_outlined,
                                    size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _tipoAcceso == _TipoAcceso.empresa
                                      ? 'Entrar como empresa'
                                      : 'Entrar como estudiante',
                                  style: AppTextStyles.button
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Separador ────────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('¿Aún no tienes cuenta?',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),

                // ── Registro ─────────────────────────────────────────────
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.registerStudent),
                    icon: const Icon(Icons.school_outlined, size: 18),
                    label: const Text('Soy estudiante'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.registerCompany),
                    icon: const Icon(Icons.business_outlined, size: 18),
                    label: const Text('Soy empresa'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.accentBlue,
                      side: const BorderSide(color: AppColors.accentBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widget selector de rol ────────────────────────────────────────────────
  Widget _buildRolSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04), blurRadius: 8)],
    ),
    child: Row(children: [
      _rolTab(
        label: 'Estudiante',
        icon: Icons.school_outlined,
        tipo: _TipoAcceso.estudiante,
        color: AppColors.primaryPurple,
      ),
      _rolTab(
        label: 'Empresa',
        icon: Icons.business_outlined,
        tipo: _TipoAcceso.empresa,
        color: AppColors.accentBlue,
      ),
    ]),
  );

  Widget _rolTab({
    required String label,
    required IconData icon,
    required _TipoAcceso tipo,
    required Color color,
  }) {
    final sel = _tipoAcceso == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _tipoAcceso = tipo);
          context.read<AuthProvider>().limpiarError();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel ? [BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 18,
                color: sel ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.bodyMedium.copyWith(
                color: sel ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  // ── Banner de error ───────────────────────────────────────────────────────
  Widget _buildErrorBanner(String error) {
    // Determinar el tipo de error para el icono y color
    IconData icon = Icons.error_outline;
    Color color   = AppColors.error;
    String titulo = 'Error';

    final e = error.toLowerCase();
    if (e.contains('contraseña') || e.contains('incorrectos') ||
        e.contains('credenciales')) {
      icon  = Icons.lock_outline;
      titulo = 'Credenciales incorrectas';
    } else if (e.contains('conexión') || e.contains('internet') ||
        e.contains('servidor') || e.contains('red')) {
      icon   = Icons.wifi_off_outlined;
      color  = Colors.orange;
      titulo = 'Sin conexión';
    } else if (e.contains('tardó') || e.contains('timeout') ||
        e.contains('tiempo')) {
      icon   = Icons.access_time_outlined;
      color  = Colors.orange;
      titulo = 'Tiempo de espera agotado';
    } else if (e.contains('cuenta') && e.contains('inactiva')) {
      icon  = Icons.block_outlined;
      titulo = 'Cuenta inactiva';
    } else if (e.contains('empresa') || e.contains('estudiante')) {
      icon   = Icons.swap_horiz_outlined;
      color  = AppColors.accentBlue;
      titulo = 'Tipo de cuenta incorrecto';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: AppTextStyles.bodySmall.copyWith(
              color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(error, style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary, height: 1.4)),
        ])),
        GestureDetector(
          onTap: () => context.read<AuthProvider>().limpiarError(),
          child: Icon(Icons.close, size: 16, color: color.withOpacity(0.6)),
        ),
      ]),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon,
        color: _tipoAcceso == _TipoAcceso.empresa
            ? AppColors.accentBlue
            : AppColors.primaryPurple),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
          color: _tipoAcceso == _TipoAcceso.empresa
              ? AppColors.accentBlue
              : AppColors.primaryPurple,
          width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    filled: true,
    fillColor: Theme.of(context).cardColor,
  );
}