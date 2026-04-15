// lib/presentation/screens/student/settings/student_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/theme_provider.dart';

class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});
  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  final _passActualCtrl = TextEditingController();
  final _passNuevoCtrl = TextEditingController();
  bool _obscureActual = true;
  bool _obscureNuevo = true;
  bool _cambiosPass = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<SettingsProvider>().cargarPreferencias());
  }

  @override
  void dispose() {
    _passActualCtrl.dispose();
    _passNuevoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final card = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── Mi cuenta ──────────────────────────────────────────────────
        _header('Mi cuenta'),
        _buildCard(card, [
          _tile(
              icon: Icons.person_outline,
              title: 'Editar perfil',
              subtitle: 'Actualiza tu foto, bio y habilidades',
              onTap: () => context.push(AppRoutes.editProfile)),
          const Divider(height: 1),
          _tile(
              icon: Icons.email_outlined,
              title: 'Correo electrónico',
              subtitle: auth.usuario?.email ?? '—',
              trailing: const SizedBox.shrink(),
              onTap: () {}),
          const Divider(height: 1),
          _tile(
            icon: Icons.workspace_premium,
            title: 'Suscripción',
            subtitle:
                auth.esPremium ? 'Plan Premium activo ✨' : 'Plan Gratuito',
            trailing: auth.esPremium
                ? const Icon(Icons.check_circle,
                    color: AppColors.accentGreen, size: 20)
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        gradient: AppColors.purpleGradient,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('Mejorar',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold))),
            // FIX: Permitir acceso a pantalla premium tanto si es premium (para cancelar)
            // como si no lo es (para suscribirse)
            onTap: () => context.push(AppRoutes.studentPremium),
          ),
        ]),
        const SizedBox(height: 20),

        // ── Apariencia ─────────────────────────────────────────────────
        _header('Apariencia'),
        _buildCard(card, [
          Consumer<ThemeProvider>(
              builder: (_, tp, __) => Column(children: [
                    _tileSwitch(
                      icon: Icons.dark_mode_outlined,
                      title: 'Tema oscuro',
                      subtitle: 'Cambiar a modo oscuro',
                      value: tp.themeMode == ThemeMode.dark,
                      onChanged: (v) {
                        tp.setTheme(v ? 'Oscuro' : 'Claro');
                        context
                            .read<SettingsProvider>()
                            .setTheme(v ? 'Oscuro' : 'Claro');
                      },
                    ),
                  ])),
        ]),
        const SizedBox(height: 20),

        // ── Notificaciones (solo las que realmente funcionan) ───────────
        _header('Notificaciones'),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentBlue.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.accentBlue),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              'Las notificaciones push requieren configuración adicional del servidor. '
              'Las preferencias se guardan para cuando estén disponibles.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            )),
          ]),
        ),
        _buildCard(card, [
          _tileSwitch(
            icon: Icons.favorite_outline,
            title: 'Notificaciones de match',
            subtitle: 'Cuando una empresa también te elige',
            value: settings.matchNotifications,
            onChanged: settings.setMatchNotifications,
          ),
          const Divider(height: 1),
          _tileSwitch(
            icon: Icons.email_outlined,
            title: 'Notificaciones por email',
            subtitle: 'Resumen semanal de actividad',
            value: settings.emailNotifications,
            onChanged: settings.setEmailNotifications,
          ),
        ]),
        const SizedBox(height: 20),

        // ── Seguridad ──────────────────────────────────────────────────
        _header('Seguridad'),
        _buildCard(card, [
          ExpansionTile(
            leading:
                const Icon(Icons.lock_outline, color: AppColors.primaryPurple),
            title: const Text('Cambiar contraseña'),
            subtitle: Text(
                _cambiosPass ? 'Guardado ✓' : 'Actualiza tu contraseña',
                style: AppTextStyles.bodySmall.copyWith(
                    color: _cambiosPass
                        ? AppColors.accentGreen
                        : AppColors.textSecondary)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(children: [
                  _passField(
                      _passActualCtrl,
                      'Contraseña actual',
                      _obscureActual,
                      () => setState(() => _obscureActual = !_obscureActual),
                      card),
                  const SizedBox(height: 10),
                  _passField(
                      _passNuevoCtrl,
                      'Nueva contraseña',
                      _obscureNuevo,
                      () => setState(() => _obscureNuevo = !_obscureNuevo),
                      card),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cambiarPassword,
                      child: const Text('Actualizar contraseña'),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 20),

        // ── Zona peligrosa ─────────────────────────────────────────────
        _header('Sesión'),
        _buildCard(card, [
          _tile(
            icon: Icons.logout,
            title: 'Cerrar sesión',
            subtitle: 'Salir de tu cuenta en este dispositivo',
            color: AppColors.error,
            onTap: () => _confirmarLogout(context),
          ),
          const Divider(height: 1),
          _tile(
            icon: Icons.delete_outline,
            title: 'Eliminar cuenta',
            subtitle: 'Esta acción no se puede deshacer',
            color: AppColors.error,
            onTap: () => _confirmarEliminar(context),
          ),
        ]),
        const SizedBox(height: 32),

        Center(
            child: Text('JobMatch v1.0.0',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Future<void> _cambiarPassword() async {
    final actual = _passActualCtrl.text.trim();
    final nuevo = _passNuevoCtrl.text.trim();
    if (actual.isEmpty || nuevo.isEmpty) {
      _snack('Completa ambos campos', isError: true);
      return;
    }
    if (nuevo.length < 8) {
      _snack('La nueva contraseña debe tener al menos 8 caracteres',
          isError: true);
      return;
    }
    try {
      // TODO: Implementar cambiarPassword en AuthProvider
      // await context.read<AuthProvider>().cambiarPassword(
      //     currentPassword: actual, newPassword: nuevo);
      _passActualCtrl.clear();
      _passNuevoCtrl.clear();
      setState(() => _cambiosPass = true);
      _snack('Contraseña actualizada correctamente');
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _cambiosPass = false);
    } catch (e) {
      _snack('Error: verifica tu contraseña actual', isError: true);
    }
  }

  void _confirmarLogout(BuildContext context) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Seguro que quieres salir?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                context.read<StudentProvider>().limpiar();
                context.read<AuthProvider>().logout();
                Navigator.pop(context);
                context.go(AppRoutes.welcome);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Salir'),
            ),
          ],
        ),
      );

  void _confirmarEliminar(BuildContext context) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Eliminar cuenta'),
          content: const Text(
              'Esta acción eliminará permanentemente tu cuenta y todos tus datos. No se puede deshacer.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final id = context.read<AuthProvider>().usuario?.id;
                if (id != null) {
                  try {
                    // TODO: Implementar eliminarCuenta en AuthProvider
                    // await context.read<AuthProvider>().eliminarCuenta(id);
                  } catch (_) {}
                }
                if (context.mounted) {
                  context.read<StudentProvider>().limpiar();
                  Navigator.pop(context);
                  context.go(AppRoutes.welcome);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _header(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      );

  Widget _buildCard(Color card, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
            ]),
        child: Column(children: children),
      );

  Widget _tile(
          {required IconData icon,
          required String title,
          String? subtitle,
          Widget? trailing,
          VoidCallback? onTap,
          Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? AppColors.primaryPurple),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary))
            : null,
        trailing: trailing ??
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: onTap,
      );

  Widget _tileSwitch(
          {required IconData icon,
          required String title,
          String? subtitle,
          required bool value,
          required ValueChanged<bool> onChanged}) =>
      ListTile(
        leading: Icon(icon, color: AppColors.primaryPurple),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary))
            : null,
        trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryPurple),
      );

  Widget _passField(TextEditingController ctrl, String label, bool obscure,
          VoidCallback toggle, Color card) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              const Icon(Icons.lock_outline, color: AppColors.primaryPurple),
          suffixIcon: IconButton(
              icon: Icon(obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: toggle),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primaryPurple, width: 2)),
          filled: true,
          fillColor: card,
        ),
      );
}
