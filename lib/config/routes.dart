// lib/config/routes.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_routes.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/welcome_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_student_screen.dart';
import '../presentation/screens/auth/register_company_screen.dart';

// Student
import '../presentation/screens/student/home/student_home_screen.dart';
import '../presentation/screens/student/profile/student_edit_profile_screen.dart';
import '../presentation/screens/common/premium_screen.dart';
import '../presentation/screens/common/settings_screen.dart';

// Student shell (IndexedStack)
import '../presentation/screens/student/student_shell_screen.dart';

// Company shell (IndexedStack) — ES LA PANTALLA RAÍZ DE EMPRESA
import '../presentation/screens/company/home/company_home_screen.dart';

// Company pantallas push (fuera del shell)
import '../presentation/screens/company/vacancies/create_vacancy_screen.dart';
import '../presentation/screens/company/vacancies/edit_vacancy_screen.dart';
import '../presentation/screens/company/profile/company_edit_profile_screen.dart';

// Settings y premium separados por rol
import '../presentation/screens/student/settings/student_settings_screen.dart';
import '../presentation/screens/student/premium/student_premium_screen.dart';
import '../presentation/screens/company/settings/company_settings_screen.dart';
import '../presentation/screens/company/premium/company_premium_screen.dart';



class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [

      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey, child: const SplashScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)),
      ),

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey, child: const WelcomeScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)),
      ),
      GoRoute(path: AppRoutes.login,
          builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.registerStudent,
          builder: (_, __) => const RegisterStudentScreen()),
      GoRoute(path: AppRoutes.registerCompany,
          builder: (_, __) => const RegisterCompanyScreen()),

      // ── Student — Shell (IndexedStack con 4 tabs) ─────────────────────────
      // studentHome apunta al shell que contiene home, matches, actividad, perfil
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (_, __) => const StudentShellScreen(),
      ),
      // Pantallas fuera del shell del estudiante (push sobre el shell)
      GoRoute(path: AppRoutes.editProfile,
          builder: (_, __) => const StudentEditProfileScreen()),
      GoRoute(path: AppRoutes.studentSettings,
          builder: (_, __) => const StudentSettingsScreen()),
      GoRoute(path: AppRoutes.studentPremium,
          builder: (_, __) => const StudentPremiumScreen()),

      // ── Company — Shell (IndexedStack con 4 tabs) ─────────────────────────
      // companyHome apunta al shell que contiene inicio, vacantes, candidatos, perfil
      GoRoute(
        path: AppRoutes.companyHome,
        builder: (_, __) => const CompanyHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.companyVacancies,
        builder: (_, __) => const CompanyHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.companyCandidates,
        builder: (_, __) => const CompanyHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.companyProfile,
        builder: (_, __) => const CompanyHomeScreen(),
      ),
      // Pantallas fuera del shell de empresa (push sobre el shell)
      GoRoute(path: AppRoutes.companyCreateVacancy,
          builder: (_, __) => const CreateVacancyScreen()),
      GoRoute(
        path: '/company/vacancies/edit/:id',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return EditVacancyScreen(vacanteId: id ?? 0);
        },
      ),
      GoRoute(path: AppRoutes.companyEditProfile,
          builder: (_, __) => const CompanyEditProfileScreen()),
      GoRoute(path: AppRoutes.companySettings,
          builder: (_, __) => const CompanySettingsScreen()),
      GoRoute(path: AppRoutes.companyPremium,
          builder: (_, __) => const CompanyPremiumScreen()),

      // ── Común ─────────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.settings,
          builder: (_, __) => const SettingsScreen()),
      // GoRoute(path: AppRoutes.premium,
      //     builder: (_, __) => const PremiumScreen()),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Ruta no encontrada: ${state.error}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.welcome),
            child: const Text('Ir al inicio'),
          ),
        ],
      )),
    ),
  );
}