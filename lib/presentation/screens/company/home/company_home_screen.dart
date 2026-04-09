// lib/presentation/screens/company/home/company_home_screen.dart
//
// ESTE ES EL SHELL PRINCIPAL DE LA EMPRESA.
// Usa IndexedStack + BottomNavigationBar para mantener las 4 tabs.
// NO usa context.push() para cambiar de tab — usa setState(_currentIndex).
// Los datos se cargan UNA VEZ en initState via cargarDashboard().

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/settings_provider.dart';
// Tabs del shell
import 'company_home_tab.dart';
import '../vacancies/vacancies_list_screen.dart';
import '../candidates/candidates_screen.dart';
import '../profile/company_profile_screen.dart';

class CompanyHomeScreen extends StatefulWidget {
  const CompanyHomeScreen({super.key});

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Las 4 tabs — IndexedStack las mantiene vivas
  static const _pages = [
    CompanyHomeTab(),
    VacanciesListScreen(),
    CandidatesScreen(),
    CompanyProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recargar();
  }

  Future<void> _cargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) {
      await context.read<CompanyProvider>().cargarDashboard(id);
    }
  }

  Future<void> _recargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id == null) return;
    final p = context.read<CompanyProvider>();
    // Recargar candidatos al volver a la app
    await p.recargarPostulaciones(id);
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    // Al entrar a Candidatos, recargar dashboard completo para asegurar datos frescos
    if (index == 2) {
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) {
        debugPrint('[CompanyHomeScreen] Tab candidatos - recargando dashboard');
        context.read<CompanyProvider>().cargarDashboard(id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Vacantes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Candidatos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_outlined),
            activeIcon: Icon(Icons.business),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}