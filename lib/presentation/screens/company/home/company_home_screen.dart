// lib/presentation/screens/company/home/company_home_screen.dart
//
// Shell principal de empresa con IndexedStack.
// Usa un ValueNotifier<int?> para comunicar el vacanteId seleccionado
// desde VacanciesListScreen → CandidatesScreen sin depender de GoRouter extra
// (que no funciona dentro de IndexedStack).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/company_provider.dart';
import 'company_home_tab.dart';
import '../vacancies/vacancies_list_screen.dart';
import '../candidates/candidates_screen.dart';
import '../profile/company_profile_screen.dart';

// ── Notifier global del shell ─────────────────────────────────────────────────
// Permite que VacanciesListScreen le diga a CandidatesScreen qué vacante filtrar.
// Se crea una sola vez en CompanyHomeScreen y se pasa hacia abajo.
class CompanyShellNotifier {
  /// ID de la vacante seleccionada para filtrar candidatos (null = todos)
  final ValueNotifier<int?> vacanteIdFiltro = ValueNotifier(null);
  /// Título de la vacante seleccionada (para mostrarlo en CandidatesScreen)
  final ValueNotifier<String?> vacanteTituloFiltro = ValueNotifier(null);

  void filtrarPorVacante(int vacanteId, String titulo) {
    vacanteIdFiltro.value = vacanteId;
    vacanteTituloFiltro.value = titulo;
  }

  void limpiarFiltro() {
    vacanteIdFiltro.value = null;
    vacanteTituloFiltro.value = null;
  }

  void dispose() {
    vacanteIdFiltro.dispose();
    vacanteTituloFiltro.dispose();
  }
}

class CompanyHomeScreen extends StatefulWidget {
  const CompanyHomeScreen({super.key});

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _shellNotifier = CompanyShellNotifier();

  // Las páginas se construyen en build() para poder pasarles el notifier
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shellNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recargar();
  }

  Future<void> _cargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id != null) await context.read<CompanyProvider>().cargarDashboard(id);
  }

  Future<void> _recargar() async {
    final id = context.read<AuthProvider>().usuario?.id;
    if (id == null) return;
    await context.read<CompanyProvider>().recargarCandidatos(id);
  }

  void _onTap(int index) {
    // Al salir de candidatos, limpiar el filtro de vacante
    if (_currentIndex == 2 && index != 2) {
      _shellNotifier.limpiarFiltro();
    }
    setState(() => _currentIndex = index);
    // Recargar candidatos cada vez que se entra al tab
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
      body: IndexedStack(index: _currentIndex, children: _pages),
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