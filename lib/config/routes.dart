// lib/config/routes.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_routes.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/welcome_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_student_screen.dart';
import '../presentation/screens/auth/register_company_screen.dart';
import '../presentation/screens/student/home/student_home_screen.dart';
import '../presentation/screens/student/profile/student_profile_screen.dart';
import '../presentation/screens/student/profile/student_edit_profile_screen.dart';
import '../presentation/screens/student/applications/applications_screen.dart';
import '../presentation/screens/student/activity/activity_history_screen.dart';
import '../presentation/screens/common/premium_screen.dart';
import '../presentation/screens/common/settings_screen.dart';
import '../presentation/screens/company/company_shell_screen.dart';
import '../presentation/screens/company/vacancies/create_vacancy_screen.dart';
import '../presentation/screens/company/vacancies/edit_vacancy_screen.dart';
import '../presentation/screens/student/ai_feedback/ai_feedback_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [

      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash, name: 'splash',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey, child: const SplashScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child)),
      ),

      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.welcome, name: 'welcome',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey, child: const WelcomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child)),
      ),
      GoRoute(
        path: AppRoutes.login, name: 'login',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey, child: const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)).animate(anim),
            child: child)),
      ),
      GoRoute(
        path: AppRoutes.registerStudent, name: 'register-student',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey, child: const RegisterStudentScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)).animate(anim),
            child: child)),
      ),
      GoRoute(
        path: AppRoutes.registerCompany, name: 'register-company',
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey, child: const RegisterCompanyScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOut)).animate(anim),
            child: child)),
      ),

      // ── Student ──────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.studentHome,         name: 'student-home',         builder: (_, __) => const StudentHomeScreen()),
      GoRoute(path: AppRoutes.studentProfile,      name: 'student-profile',      builder: (_, __) => const StudentProfileScreen()),
      GoRoute(path: AppRoutes.editProfile,         name: 'edit-profile',         builder: (_, __) => const StudentEditProfileScreen()),
      GoRoute(path: AppRoutes.studentApplications, name: 'student-applications', builder: (_, __) => const ApplicationsScreen()),
      GoRoute(path: AppRoutes.studentActivity,     name: 'student-activity',     builder: (_, __) => const ActivityHistoryScreen()),
      GoRoute(
        path: AppRoutes.aiFeedback, name: 'ai-feedback',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AIFeedbackScreen(
            applicationId: extra?['applicationId'],
            companyName:   extra?['companyName'],
            position:      extra?['position'],
          );
        },
      ),

      // ── Company Shell — nav bar persistente ──────────────────────────────
      // Todas las secciones principales viven DENTRO del shell.
      // Solo las sub-pantallas (crear/editar vacante) son rutas separadas.
      GoRoute(
        path: AppRoutes.companyHome, name: 'company-home',
        builder: (_, __) => const CompanyShellScreen(),
      ),
      // Estas rutas redirigen al shell — el shell maneja el índice
      GoRoute(path: AppRoutes.companyVacancies,  name: 'company-vacancies',  builder: (_, __) => const CompanyShellScreen()),
      GoRoute(path: AppRoutes.companyCandidates, name: 'company-candidates', builder: (_, __) => const CompanyShellScreen()),
      GoRoute(path: AppRoutes.companyProfile,    name: 'company-profile',    builder: (_, __) => const CompanyShellScreen()),

      // Sub-pantallas que SÍ son rutas independientes (sin nav bar)
      GoRoute(path: AppRoutes.companyCreateVacancy, name: 'company-create-vacancy',
          builder: (_, __) => const CreateVacancyScreen()),
      GoRoute(
        path: '/company/vacancies/edit/:id', name: 'company-edit-vacancy',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return EditVacancyScreen(vacanteId: id);
        },
      ),

      // ── Common ────────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.settings, name: 'settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: AppRoutes.premium,  name: 'premium',  builder: (_, __) => const PremiumScreen()),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: ${state.error}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.welcome),
            child: const Text('Volver al inicio'),
          ),
        ],
      )),
    ),
  );
}