// lib/presentation/screens/auth/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_routes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Logo / Ilustración ──────────────────────────────────────
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.purpleGradient,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(
                    color: AppColors.primaryPurple.withOpacity(0.35),
                    blurRadius: 24, offset: const Offset(0, 12),
                  )],
                ),
                child: const Icon(Icons.work_outline,
                    color: Colors.white, size: 56),
              ),
              const SizedBox(height: 32),

              // ── Textos ────────────────────────────────────────────────────
              Text('JobMatch',
                  style: AppTextStyles.h1.copyWith(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                'Conecta con las mejores oportunidades laborales.\nDesliza, haz match y consigue tu próximo empleo.',
                style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // ── Sección Estudiante ────────────────────────────────────────
              _SectionCard(
                icon: Icons.school_outlined,
                titulo: 'Soy estudiante o egresado',
                descripcion: 'Busca prácticas y empleos que se adapten a tu perfil',
                color: AppColors.primaryPurple,
                onLogin: () => context.push(AppRoutes.login),
                onRegister: () => context.push(AppRoutes.registerStudent),
              ),
              const SizedBox(height: 16),

              // ── Sección Empresa ───────────────────────────────────────────
              _SectionCard(
                icon: Icons.business_outlined,
                titulo: 'Soy empresa reclutadora',
                descripcion: 'Publica vacantes y encuentra al candidato ideal',
                color: AppColors.accentBlue,
                onLogin: () => context.push(AppRoutes.login),
                onRegister: () => context.push(AppRoutes.registerCompany),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String   titulo;
  final String   descripcion;
  final Color    color;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _SectionCard({
    required this.icon, required this.titulo, required this.descripcion,
    required this.color, required this.onLogin, required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 16, offset: const Offset(0, 4),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppTextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(descripcion, style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary)),
            ],
          )),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Iniciar sesión'),
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
            onPressed: onRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Registrarse',
                style: TextStyle(color: Colors.white)),
          )),
        ]),
      ]),
    );
  }
}