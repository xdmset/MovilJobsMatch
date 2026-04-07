// lib/presentation/providers/student_provider.dart

import 'package:flutter/material.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  final _repo = StudentRepository.instance;

  // ── Vacantes ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _vacantes = [];
  int  _currentIndex  = 0;
  int  _dailySwipes   = 0;
  // Subido a 20 para pruebas (era 10)
  final int _maxSwipes = 20;
  bool _cargandoVacantes = false;

  String? _filtroModalidad;
  String? _filtroUbicacion;
  double? _filtroSueldoMin;

  List<Map<String, dynamic>> get vacantes    => _vacantes;
  int  get currentIndex                       => _currentIndex;
  bool get hasReachedLimit                    => _dailySwipes >= _maxSwipes;
  int  get remainingSwipes                    => _maxSwipes - _dailySwipes;
  bool get cargandoVacantes                   => _cargandoVacantes;
  String? get filtroModalidad                 => _filtroModalidad;
  String? get filtroUbicacion                 => _filtroUbicacion;
  double? get filtroSueldoMin                 => _filtroSueldoMin;

  Map<String, dynamic>? get currentVacancy =>
      _currentIndex < _vacantes.length ? _vacantes[_currentIndex] : null;

  // ── Matches ───────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> get matches => List.unmodifiable(_matches);

  // ── Historial ─────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> get historial => List.unmodifiable(_historial);

  bool _cargandoHistorial = false;
  bool get cargandoHistorial => _cargandoHistorial;

  // IDs de vacantes ya procesadas — fuente de verdad para no repetir
  final Set<int> _vacanteIdsVistas = {};

  // ── Cargar historial PRIMERO ──────────────────────────────────────────────
  Future<void> cargarHistorial(int estudianteId) async {
    _cargandoHistorial = true;
    notifyListeners();
    try {
      final serverItems = await _repo.getHistorialEstudiante(estudianteId);
      debugPrint('[Historial] ${serverItems.length} items del servidor');

      _vacanteIdsVistas.clear();
      for (final v in serverItems) {
        final id = v['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }
      debugPrint('[Historial] IDs vistas: $_vacanteIdsVistas');

      final deServidor = serverItems.map((v) {
        final leDioLike = v['le_dio_like'] as bool? ?? false;
        final ts = leDioLike
            ? (v['fecha_like'] as String? ??
               v['ultima_visualizacion'] as String? ?? '')
            : (v['ultima_visualizacion'] as String? ?? '');
        return <String, dynamic>{
          ...v,
          'tipo':        leDioLike ? 'like' : 'dislike',
          'timestamp':   ts,
          'match':       false,
          'le_dio_like': leDioLike,
        };
      }).toList();

      final soloLocales = _historial
          .where((h) => !_vacanteIdsVistas.contains(h['id'] as int?))
          .toList();

      _historial
        ..clear()
        ..addAll(deServidor)
        ..addAll(soloLocales);

      _historial.sort((a, b) =>
          (b['timestamp'] as String? ?? '')
              .compareTo(a['timestamp'] as String? ?? ''));

      if (_vacantes.isNotEmpty) _sincronizarIndice();

    } catch (e) {
      debugPrint('[Historial] ERROR: $e');
    }
    _cargandoHistorial = false;
    notifyListeners();
  }

  // ── Cargar vacantes DESPUÉS ───────────────────────────────────────────────
  // Filtra las ya vistas para que NUNCA se repitan
  Future<void> cargarVacantes({
    String? modalidad, String? ubicacion, double? sueldoMin,
    bool resetIndex = false,
  }) async {
    _cargandoVacantes = true;
    notifyListeners();
    try {
      final todas = await _repo.getVacantes(
        modalidad: modalidad ?? _filtroModalidad,
        ubicacion: ubicacion ?? _filtroUbicacion,
        sueldoMin: sueldoMin ?? _filtroSueldoMin,
      );

      // Excluir vacantes ya vistas/procesadas
      _vacantes = todas.where((v) {
        final id = v['id'] as int?;
        return id != null && !_vacanteIdsVistas.contains(id);
      }).toList();

      debugPrint('[Vacantes] ${todas.length} totales, '
          '${_vacantes.length} pendientes de ver');

      if (resetIndex) {
        _currentIndex = 0;
        _dailySwipes  = 0;
      } else {
        _sincronizarIndice();
      }
    } catch (e) {
      debugPrint('[Vacantes] ERROR: $e');
      _vacantes = [];
    }
    _cargandoVacantes = false;
    notifyListeners();
  }

  void _sincronizarIndice() {
    // Con el filtro ya aplicado en cargarVacantes, siempre empezar en 0
    _currentIndex = 0;
    _dailySwipes  = _vacanteIdsVistas.length.clamp(0, _maxSwipes);
  }

  Future<void> aplicarFiltros({
    String? modalidad, String? ubicacion, double? sueldoMin,
  }) async {
    _filtroModalidad = modalidad;
    _filtroUbicacion = ubicacion;
    _filtroSueldoMin = sueldoMin;
    await cargarVacantes(modalidad: modalidad, ubicacion: ubicacion,
        sueldoMin: sueldoMin, resetIndex: true);
  }

  void limpiarFiltros() {
    _filtroModalidad = null; _filtroUbicacion = null; _filtroSueldoMin = null;
    cargarVacantes(resetIndex: false);
  }

  // ── Like ──────────────────────────────────────────────────────────────────
  Future<bool> likeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return false;
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    if (vacanteId != null) {
      await _repo.registrarVista(vacanteId);
      _vacanteIdsVistas.add(vacanteId);
    }

    _dailySwipes++;
    _currentIndex++;

    bool esMatch = false;
    if (vacanteId != null) {
      final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
      if (matchRes != null) {
        esMatch = true;
        _matches.insert(0, {...matchRes, 'vacante': v});
      }
    }

    final localItem = <String, dynamic>{
      ...v, 'tipo': 'like',
      'timestamp': DateTime.now().toIso8601String(),
      'match': esMatch, 'le_dio_like': true, 'total_visualizaciones': 1,
    };
    _historial.removeWhere((h) => h['id'] == vacanteId);
    _historial.insert(0, localItem);
    notifyListeners();
    return esMatch;
  }

  // ── Dislike ───────────────────────────────────────────────────────────────
  Future<void> dislikeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return;
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    if (vacanteId != null) {
      await _repo.registrarVista(vacanteId);
      _vacanteIdsVistas.add(vacanteId);
    }

    final localItem = <String, dynamic>{
      ...v, 'tipo': 'dislike',
      'timestamp': DateTime.now().toIso8601String(),
      'match': false, 'le_dio_like': false, 'total_visualizaciones': 1,
    };
    _historial.removeWhere((h) => h['id'] == vacanteId);
    _historial.insert(0, localItem);

    _dailySwipes++;
    _currentIndex++;
    notifyListeners();

    if (vacanteId != null) {
      await _repo.registrarSwipe(estudianteId, vacanteId, false);
    }
  }

  // ── Cambiar dislike → like ────────────────────────────────────────────────
  // PARCHE para student_provider.dart
// Busca el método cambiarOpinion y reemplázalo con este:

  Future<bool> cambiarOpinion(int estudianteId, int historialIndex) async {
    if (historialIndex < 0 || historialIndex >= _historial.length) return false;

    // Copiar la lista para poder mutar (el getter devuelve unmodifiable)
    final item = Map<String, dynamic>.from(_historial[historialIndex]);
    if (item['tipo'] == 'like') return false;

    final vacanteId = item['id'] as int?;
    if (vacanteId == null) return false;

    // Actualizar localmente PRIMERO
    item['tipo']       = 'like';
    item['le_dio_like'] = true;
    item['timestamp']  = DateTime.now().toIso8601String();
    _historial[historialIndex] = item;
    notifyListeners();

    // Llamar al servidor
    final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
    if (matchRes != null) {
      final updated = Map<String, dynamic>.from(_historial[historialIndex]);
      updated['match'] = true;
      _historial[historialIndex] = updated;
      _matches.insert(0, {...matchRes, 'vacante': item});
      notifyListeners();
      return true;
    }
    return false;
  }

// TAMBIÉN busca deshacerLike y reemplaza con:
  void deshacerLike(int historialIndex) {
    if (historialIndex < 0 || historialIndex >= _historial.length) return;
    final item = Map<String, dynamic>.from(_historial[historialIndex]);
    // Solo permite descartar likes que NO sean matches
    if (item['tipo'] != 'like' || item['match'] == true) return;
    item['tipo']       = 'dislike';
    item['le_dio_like'] = false;
    item['match']      = false;
    item['timestamp']  = DateTime.now().toIso8601String();
    _historial[historialIndex] = item;
    notifyListeners();
  }

  void resetDailySwipes() { _dailySwipes = 0; notifyListeners(); }

  void limpiar() {
    _vacantes = []; _historial.clear(); _matches.clear();
    _vacanteIdsVistas.clear();
    _currentIndex = 0; _dailySwipes = 0;
    notifyListeners();
  }
}