// lib/presentation/screens/common/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        context.read<SettingsProvider>().cargarPreferencias());
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme    = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Cuenta ────────────────────────────────────────────────────────
          _sectionHeader('Cuenta'),
          _card([
            _tile(
              icon: Icons.person_outline,
              title: 'Editar perfil',
              subtitle: 'Actualiza tu información personal',
              onTap: () => context.push(AppRoutes.editProfile),
            ),
            const Divider(height: 1),
            _tile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: auth.usuario?.email ?? '—',
              trailing: const SizedBox.shrink(),
              onTap: () {},
            ),
            const Divider(height: 1),
            _tile(
              icon: Icons.workspace_premium,
              title: 'Suscripción',
              subtitle: auth.esPremium ? 'Plan Premium ✨' : 'Plan Gratis',
              trailing: auth.esPremium
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.purpleGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Mejorar',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
              onTap: () => context.push(AppRoutes.premium),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Notificaciones ────────────────────────────────────────────────
          // Se guardan localmente — cuando integres FCM/OneSignal
          // ya tienes los flags listos para leer desde SettingsProvider
          _sectionHeader('Notificaciones'),
          _card([
            _switchTile(
              icon: Icons.notifications_outlined,
              title: 'Notificaciones push',
              subtitle: 'Recibir alertas en el dispositivo',
              value: settings.pushNotifications,
              onChanged: settings.setPushNotifications,
            ),
            const Divider(height: 1),
            _switchTile(
              icon: Icons.favorite_outline,
              title: 'Notificaciones de match',
              subtitle: 'Avisarme cuando haya un nuevo match',
              value: settings.matchNotifications,
              onChanged: settings.setMatchNotifications,
            ),
            const Divider(height: 1),
            _switchTile(
              icon: Icons.email_outlined,
              title: 'Notificaciones por email',
              subtitle: 'Recibir actualizaciones por correo',
              value: settings.emailNotifications,
              onChanged: settings.setEmailNotifications,
            ),
          ]),

          const SizedBox(height: 24),

          // ── Preferencias ──────────────────────────────────────────────────
          _sectionHeader('Preferencias'),
          _card([
            _tile(
              icon: Icons.language,
              title: 'Idioma',
              subtitle: theme.locale.languageCode == 'en' ? 'English' : 'Español',
              onTap: () => _showLanguageDialog(settings, theme),
            ),
            const Divider(height: 1),
            _tile(
              icon: _themeIcon(theme.themeMode),
              title: 'Tema',
              subtitle: _labelTema(theme.themeMode),
              onTap: () => _showThemeDialog(settings, theme),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Zona de peligro ───────────────────────────────────────────────
          _sectionHeader('Zona de peligro'),
          _card([
            _tile(
              icon: Icons.logout,
              title: 'Cerrar sesión',
              subtitle: 'Salir de tu cuenta',
              titleColor: AppColors.error,
              onTap: _handleLogout,
            ),
            const Divider(height: 1),
            _tile(
              icon: Icons.delete_forever,
              title: 'Eliminar cuenta',
              subtitle: 'Borrar permanentemente tu cuenta y datos',
              titleColor: AppColors.error,
              onTap: _handleDeleteAccount,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Idioma ────────────────────────────────────────────────────────────────
  void _showLanguageDialog(SettingsProvider s, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langOption('Español', 'es', s, theme),
            _langOption('English', 'en', s, theme),
          ],
        ),
      ),
    );
  }

  Widget _langOption(String label, String code, SettingsProvider s, ThemeProvider theme) {
    final selected = theme.locale.languageCode == code;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: AppColors.primaryPurple) : null,
      onTap: () {
        theme.setLocale(label);   // aplica inmediatamente
        s.setLanguage(label);     // sincroniza SettingsProvider
        Navigator.pop(context);
      },
    );
  }

  // ── Tema ──────────────────────────────────────────────────────────────────
  void _showThemeDialog(SettingsProvider s, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeOptionTile('Sistema', ThemeMode.system, Icons.brightness_auto_outlined, s, theme),
            _themeOptionTile('Claro',   ThemeMode.light,  Icons.light_mode_outlined,      s, theme),
            _themeOptionTile('Oscuro',  ThemeMode.dark,   Icons.dark_mode_outlined,       s, theme),
          ],
        ),
      ),
    );
  }

  Widget _themeOptionTile(String label, ThemeMode mode, IconData icon,
      SettingsProvider s, ThemeProvider theme) {
    final selected = theme.themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.primaryPurple : AppColors.textSecondary),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: AppColors.primaryPurple) : null,
      onTap: () {
        theme.setTheme(label);  // aplica inmediatamente — no necesita reiniciar
        s.setTheme(label);      // sincroniza SettingsProvider
        Navigator.pop(context);
      },
    );
  }

  IconData _themeIcon(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return Icons.light_mode_outlined;
      case ThemeMode.dark:   return Icons.dark_mode_outlined;
      default:               return Icons.brightness_auto_outlined;
    }
  }

  String _labelTema(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'Claro';
      case ThemeMode.dark:   return 'Oscuro';
      default:               return 'Sistema';
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
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
  }

  // ── Eliminar cuenta ───────────────────────────────────────────────────────
  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta acción no se puede deshacer. Todos tus datos serán eliminados permanentemente.\n\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _confirmarEliminacion(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacion() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingresa tu contraseña para confirmar:'),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
          Consumer<SettingsProvider>(
            builder: (_, settings, __) => ElevatedButton(
              onPressed: settings.deletingAccount ? null : () async {
                if (passCtrl.text.trim().isEmpty) return;
                final userId = context.read<AuthProvider>().usuario?.id;
                if (userId == null) return;
                final ok = await context.read<SettingsProvider>().eliminarCuenta(userId);
                if (!mounted) return;
                Navigator.pop(dialogCtx);
                if (ok) {
                  context.read<AuthProvider>().logout();
                  context.go(AppRoutes.welcome);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(settings.error ?? 'Error al eliminar la cuenta'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: settings.deletingAccount
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmar'),
            ),
          ),
        ],
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────
  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 12),
    child: Text(t, style: AppTextStyles.subtitle1.copyWith(
        fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: AppColors.textPrimary.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(children: children),
  );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (titleColor ?? AppColors.primaryPurple).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: titleColor ?? AppColors.primaryPurple, size: 24),
    ),
    title: Text(title, style: AppTextStyles.subtitle1.copyWith(
        fontWeight: FontWeight.w600, color: titleColor)),
    subtitle: Text(subtitle, style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary)),
    trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textTertiary),
    onTap: onTap,
  );

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) => ListTile(
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primaryPurple, size: 24),
    ),
    title: Text(title, style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary)),
    trailing: Switch(value: value, onChanged: onChanged, activeColor: AppColors.primaryPurple),
  );
}