// lib/presentation/screens/company/company_shell_screen.dart
//
// Este archivo se mantiene por compatibilidad pero la lógica real
// está en CompanyHomeScreen. Ambos usan CompanyShellNotifier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import 'home/company_home_tab.dart';
import 'home/company_home_screen.dart' show CompanyShellNotifier;
import 'vacancies/vacancies_list_screen.dart';
import 'candidates/candidates_screen.dart';
import 'profile/company_profile_screen.dart';

class CompanyShellScreen extends StatefulWidget {
  const CompanyShellScreen({super.key});

  @override
  State<CompanyShellScreen> createState() => _CompanyShellScreenState();
}

class _CompanyShellScreenState extends State<CompanyShellScreen> {
  int _currentIndex = 0;
  final _shellNotifier = CompanyShellNotifier();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      CompanyHomeTab(
        onIrACandidatos: (vacanteId, titulo) {
          _shellNotifier.filtrarPorVacante(vacanteId, titulo);
          setState(() => _currentIndex = 2);
        },
      ),
      VacanciesListScreen(
        onVerCandidatos: (vacanteId, titulo) {
          _shellNotifier.filtrarPorVacante(vacanteId, titulo);
          setState(() => _currentIndex = 2);
        },
      ),
      CandidatesScreen(notifier: _shellNotifier),
      const CompanyProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) {
        context.read<CompanyProvider>().cargarDashboard(id);
      }
    });
  }

  @override
  void dispose() {
    _shellNotifier.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (_currentIndex == 2 && index != 2) {
      _shellNotifier.limpiarFiltro();
    }
    setState(() => _currentIndex = index);
    if (index == 2) {
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) {
        context.read<CompanyProvider>().recargarCandidatos(id);
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