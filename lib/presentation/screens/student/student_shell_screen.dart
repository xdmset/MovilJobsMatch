// lib/presentation/screens/student/student_shell_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import 'home/student_home_screen.dart';
import 'applications/applications_screen.dart';
import 'activity/activity_history_screen.dart';
import 'profile/student_profile_screen.dart';

class StudentShellScreen extends StatefulWidget {
  const StudentShellScreen({super.key});

  @override
  State<StudentShellScreen> createState() => _StudentShellScreenState();
}

class _StudentShellScreenState extends State<StudentShellScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  static const _pages = [
    StudentHomeScreen(),
    ApplicationsScreen(),
    ActivityHistoryScreen(),
    StudentProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recargarTodo();
  }

  Future<void> _init() async {
    final userId = context.read<AuthProvider>().usuario?.id;
    final p      = context.read<StudentProvider>();
    if (userId == null) return;

    // ORDEN IMPORTANTE:
    // 1. Cargar historial primero (obtiene IDs ya vistas)
    // 2. Luego cargar vacantes (usa esos IDs para sincronizar índice)
    await p.cargarHistorial(userId);
    await p.cargarVacantes();
  }

  Future<void> _recargarTodo() async {
    final userId = context.read<AuthProvider>().usuario?.id;
    final p      = context.read<StudentProvider>();
    if (userId == null) return;
    await p.cargarHistorial(userId);
    // Solo recargar vacantes si se acabaron
    if (p.currentVacancy == null && !p.hasReachedLimit) {
      await p.cargarVacantes(resetIndex: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          // Al entrar a Actividad recargar historial
          if (i == 2) {
            final userId = context.read<AuthProvider>().usuario?.id;
            if (userId != null) {
              context.read<StudentProvider>().cargarHistorial(userId);
            }
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Actividad',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}