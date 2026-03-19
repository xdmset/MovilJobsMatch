// lib/presentation/providers/student_provider.dart

import 'package:flutter/material.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  final _repo = StudentRepository.instance;

  // ── Vacantes ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _vacantes    = [];
  int  _currentIndex  = 0;
  int  _dailySwipes   = 0;
  final int _maxSwipes = 10;
  bool _cargandoVacantes = false;

  String? _filtroModalidad;
  String? _filtroUbicacion;
  double? _filtroSueldoMin;

  List<Map<String, dynamic>> get vacantes      => _vacantes;
  int  get currentIndex                         => _currentIndex;
  bool get hasReachedLimit                      => _dailySwipes >= _maxSwipes;
  int  get remainingSwipes                      => _maxSwipes - _dailySwipes;
  bool get cargandoVacantes                     => _cargandoVacantes;

  Map<String, dynamic>? get currentVacancy =>
      _currentIndex < _vacantes.length ? _vacantes[_currentIndex] : null;

  // ── Matches (cuando un swipe genera match) ────────────────────────────────
  // { id, estudiante_id, vacante_id, fecha_match, vacante: {...} }
  final List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> get matches => _matches;

  // ── Historial de swipes (para pantalla actividad) ─────────────────────────
  // { titulo, modalidad, ..., tipo: 'like'|'dislike', timestamp, match: bool }
  final List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> get historial => _historial;

  // ── Cargar vacantes ───────────────────────────────────────────────────────
  Future<void> cargarVacantes({
    String? modalidad, String? ubicacion, double? sueldoMin,
  }) async {
    _cargandoVacantes = true;
    notifyListeners();
    try {
      _vacantes = await _repo.getVacantes(
        modalidad: modalidad ?? _filtroModalidad,
        ubicacion: ubicacion ?? _filtroUbicacion,
        sueldoMin: sueldoMin ?? _filtroSueldoMin,
      );
      _currentIndex = 0;
    } catch (_) { _vacantes = []; }
    _cargandoVacantes = false;
    notifyListeners();
  }

  Future<void> aplicarFiltros({
    String? modalidad, String? ubicacion, double? sueldoMin,
  }) async {
    _filtroModalidad = modalidad;
    _filtroUbicacion = ubicacion;
    _filtroSueldoMin = sueldoMin;
    await cargarVacantes(modalidad: modalidad, ubicacion: ubicacion, sueldoMin: sueldoMin);
  }

  void limpiarFiltros() {
    _filtroModalidad = null; _filtroUbicacion = null; _filtroSueldoMin = null;
    cargarVacantes();
  }

  // ── Like — interes_estudiante: true ───────────────────────────────────────
  Future<bool> likeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return false;
    final v = currentVacancy!;
    final vacanteId = v['id'] as int?;

    _dailySwipes++;
    _currentIndex++;
    notifyListeners();

    bool esMatch = false;
    if (vacanteId != null) {
      final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
      if (matchRes != null) {
        esMatch = true;
        _matches.insert(0, {...matchRes, 'vacante': v});
      }
    }

    _historial.insert(0, {
      ...v,
      'tipo':      'like',
      'timestamp': DateTime.now().toIso8601String(),
      'match':     esMatch,
    });
    notifyListeners();
    return esMatch; // true = hay match
  }

  // ── Dislike — interes_estudiante: false ───────────────────────────────────
  Future<void> dislikeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return;
    final v = currentVacancy!;
    final vacanteId = v['id'] as int?;

    _historial.insert(0, {
      ...v,
      'tipo':      'dislike',
      'timestamp': DateTime.now().toIso8601String(),
      'match':     false,
    });

    _dailySwipes++;
    _currentIndex++;
    notifyListeners();

    if (vacanteId != null) {
      await _repo.registrarSwipe(estudianteId, vacanteId, false);
    }
  }

  void resetDailySwipes() { _dailySwipes = 0; notifyListeners(); }
}