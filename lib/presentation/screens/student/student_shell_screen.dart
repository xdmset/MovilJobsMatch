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

class _StudentShellScreenState extends State<StudentShellScreen> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Solo cargamos vacantes — las postulaciones se derivan de los matches
      context.read<StudentProvider>().cargarVacantes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Postulaciones',
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