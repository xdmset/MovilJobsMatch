// lib/presentation/screens/company/company_shell_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import 'home/company_home_tab.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = context.read<AuthProvider>().usuario?.id;
      if (id != null) {
        context.read<CompanyProvider>().cargarDashboard(id);
      }
    });
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
  }

  // Las 4 pestañas — IndexedStack las mantiene vivas en memoria
  static const _pages = [
    CompanyHomeTab(),
    VacanciesListScreen(),
    CandidatesScreen(),
    CompanyProfileScreen(),
  ];

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