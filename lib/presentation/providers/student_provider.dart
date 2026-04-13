// lib/presentation/providers/student_provider.dart

import 'package:flutter/material.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  final _repo = StudentRepository.instance;

  int? _estudianteId;

  // ── Feed ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _vacantes     = [];
  int  _currentIndex  = 0;
  int  _dailySwipes   = 0;
  final int _maxSwipes = 20;
  bool _cargandoVacantes = false;

  String? _filtroModalidad;
  String? _filtroUbicacion;
  double? _filtroSueldoMin;

  List<Map<String, dynamic>> get vacantes      => _vacantes;
  int  get currentIndex                         => _currentIndex;
  bool get hasReachedLimit                      => _dailySwipes >= _maxSwipes;
  int  get remainingSwipes                      => _maxSwipes - _dailySwipes;
  bool get cargandoVacantes                     => _cargandoVacantes;
  String? get filtroModalidad                   => _filtroModalidad;
  String? get filtroUbicacion                   => _filtroUbicacion;
  double? get filtroSueldoMin                   => _filtroSueldoMin;

  Map<String, dynamic>? get currentVacancy =>
      _currentIndex < _vacantes.length ? _vacantes[_currentIndex] : null;

  // ── Matches ───────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _matchesServidor = [];
  final List<Map<String, dynamic>> _matchesSesion   = [];

  List<Map<String, dynamic>> get matches =>
      [..._matchesSesion, ..._matchesServidor];

  // ── Historial ─────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> get historial => List.unmodifiable(_historial);

  bool _cargandoHistorial = false;
  bool get cargandoHistorial => _cargandoHistorial;

  // FIX: Set de IDs vistos — única fuente de verdad para deduplicación
  final Set<int> _vacanteIdsVistas = {};

  // ── Cargar historial ──────────────────────────────────────────────────────
  Future<void> cargarHistorial(int estudianteId) async {
    _estudianteId = estudianteId;
    _cargandoHistorial = true;
    notifyListeners();
    try {
      final serverItems = await _repo.getHistorialEstudiante(estudianteId);
      debugPrint('[StudentProvider] historial: ${serverItems.length} items');

      // Reconstruir el set de IDs vistos desde el servidor
      _vacanteIdsVistas.clear();
      for (final v in serverItems) {
        final id = v['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }
      // También añadir los que registramos localmente en esta sesión
      for (final h in _historial) {
        final id = h['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }

      final deServidor = serverItems.map((v) {
        final leDioLike = v['le_dio_like'] as bool? ?? false;
        final ts = leDioLike
            ? (v['fecha_like'] as String?
                ?? v['ultima_visualizacion'] as String? ?? '')
            : (v['ultima_visualizacion'] as String? ?? '');
        return <String, dynamic>{
          ...v,
          'tipo':        leDioLike ? 'like' : 'dislike',
          'timestamp':   ts,
          'match':       false,
          'le_dio_like': leDioLike,
        };
      }).toList();

      // Mantener entradas locales que aún no llegaron al servidor
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

      // FIX: siempre filtrar vacantes en memoria al actualizar historial
      _filtrarVacantesVistas();

    } catch (e) {
      debugPrint('[StudentProvider] cargarHistorial error: $e');
    }
    _cargandoHistorial = false;
    notifyListeners();
  }

  // ── Cargar matches ────────────────────────────────────────────────────────
  Future<void> cargarMatches(int estudianteId) async {
    _estudianteId = estudianteId;
    try {
      final lista = await _repo.getMatches(estudianteId);
      _matchesServidor.clear();
      for (final m in lista) {
        final vacanteId = m['vacante_id'] as int?;
        final vacanteData = vacanteId != null
            ? _historial.firstWhere(
                (h) => h['id'] == vacanteId, orElse: () => {})
            : <String, dynamic>{};
        _matchesServidor.add({
          ...m,
          'vacante': vacanteData.isNotEmpty ? vacanteData : {'id': vacanteId},
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StudentProvider] cargarMatches error: $e');
    }
  }

  // ── Cargar vacantes ───────────────────────────────────────────────────────
  Future<void> cargarVacantes({
    String? modalidad,
    String? ubicacion,
    double? sueldoMin,
    bool resetIndex = false,
    int? estudianteId,
  }) async {
    if (estudianteId != null) _estudianteId = estudianteId;
    final id = _estudianteId;

    _cargandoVacantes = true;
    notifyListeners();

    try {
      final modFinal    = modalidad ?? _filtroModalidad;
      final ubicFinal   = ubicacion ?? _filtroUbicacion;
      final sueldoFinal = sueldoMin ?? _filtroSueldoMin;
      final hayFiltros  =
          modFinal != null || ubicFinal != null || sueldoFinal != null;

      List<Map<String, dynamic>> lista = [];

      if (!hayFiltros && id != null) {
        // Feed del servidor ya filtra las vistas, pero deduplicamos por si acaso
        lista = await _repo.getVacantesFeed(id);
      } else {
        lista = await _repo.getVacantes(
          modalidad: modFinal,
          ubicacion: ubicFinal,
          sueldoMin: sueldoFinal,
        );
      }

      // FIX: deduplicar SIEMPRE, sin importar si el backend ya lo hizo
      lista = _deduplicar(lista);

      _vacantes = lista;
      debugPrint('[StudentProvider] vacantes disponibles: ${lista.length} '
          '(filtros: mod=$modFinal, ubic=$ubicFinal, sueldo=$sueldoFinal)');

      if (resetIndex) {
        _currentIndex = 0;
      } else {
        _currentIndex = 0;
      }
    } catch (e) {
      debugPrint('[StudentProvider] cargarVacantes error: $e');
      _vacantes = [];
      _currentIndex = 0;
    }
    _cargandoVacantes = false;
    notifyListeners();
  }

  // FIX: elimina vacantes ya vistas Y deduplica por id dentro del mismo array
  List<Map<String, dynamic>> _deduplicar(List<Map<String, dynamic>> lista) {
    final vistos = <int>{};
    final resultado = <Map<String, dynamic>>[];
    for (final v in lista) {
      final id = v['id'] as int?;
      if (id == null) continue;
      // Excluir si ya fue vista o ya la procesamos en esta misma lista
      if (_vacanteIdsVistas.contains(id)) continue;
      if (vistos.contains(id)) continue;
      vistos.add(id);
      resultado.add(v);
    }
    return resultado;
  }

  // Elimina del array en memoria las vacantes que ya se registraron como vistas
  void _filtrarVacantesVistas() {
    if (_vacanteIdsVistas.isEmpty) {
      _currentIndex = 0;
      return;
    }
    _vacantes = _deduplicar(_vacantes);
    _currentIndex = 0;
    _dailySwipes = _vacanteIdsVistas.length.clamp(0, _maxSwipes);
  }

  // ── Aplicar / limpiar filtros ─────────────────────────────────────────────
  Future<void> aplicarFiltros({
    String? modalidad,
    String? ubicacion,
    double? sueldoMin,
  }) async {
    _filtroModalidad = modalidad;
    _filtroUbicacion = ubicacion;
    _filtroSueldoMin = sueldoMin;
    await cargarVacantes(
      modalidad: modalidad,
      ubicacion: ubicacion,
      sueldoMin: sueldoMin,
      resetIndex: true,
    );
  }

  void limpiarFiltros() {
    _filtroModalidad = null;
    _filtroUbicacion = null;
    _filtroSueldoMin = null;
    cargarVacantes(resetIndex: true);
  }

  // ── Like ──────────────────────────────────────────────────────────────────
  Future<bool> likeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return false;
    _estudianteId = estudianteId;
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    // Marcar como vista ANTES de avanzar
    if (vacanteId != null) {
      _vacanteIdsVistas.add(vacanteId);
      await _repo.registrarVista(vacanteId);
    }

    _dailySwipes++;
    _currentIndex++;

    bool esMatch = false;
    if (vacanteId != null) {
      final matchRes =
          await _repo.registrarSwipe(estudianteId, vacanteId, true);
      if (matchRes != null) {
        esMatch = true;
        _matchesSesion.insert(0, {...matchRes, 'vacante': v});
      }
    }

    final localItem = <String, dynamic>{
      ...v,
      'tipo':      'like',
      'timestamp': DateTime.now().toIso8601String(),
      'match':     esMatch,
      'le_dio_like': true,
      'total_visualizaciones': 1,
    };
    _historial.removeWhere((h) => h['id'] == vacanteId);
    _historial.insert(0, localItem);
    notifyListeners();
    return esMatch;
  }

  // ── Dislike ───────────────────────────────────────────────────────────────
  Future<void> dislikeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return;
    _estudianteId = estudianteId;
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    // Marcar como vista ANTES de avanzar
    if (vacanteId != null) {
      _vacanteIdsVistas.add(vacanteId);
      await _repo.registrarVista(vacanteId);
    }

    final localItem = <String, dynamic>{
      ...v,
      'tipo':      'dislike',
      'timestamp': DateTime.now().toIso8601String(),
      'match':     false,
      'le_dio_like': false,
      'total_visualizaciones': 1,
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
  Future<bool> cambiarOpinion(int estudianteId, int historialIndex) async {
    if (historialIndex < 0 || historialIndex >= _historial.length) return false;
    final item = Map<String, dynamic>.from(_historial[historialIndex]);
    if (item['tipo'] == 'like') return false;
    final vacanteId = item['id'] as int?;
    if (vacanteId == null) return false;

    item['tipo'] = 'like';
    item['le_dio_like'] = true;
    item['timestamp'] = DateTime.now().toIso8601String();
    _historial[historialIndex] = item;
    notifyListeners();

    final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
    if (matchRes != null) {
      final updated = Map<String, dynamic>.from(_historial[historialIndex]);
      updated['match'] = true;
      _historial[historialIndex] = updated;
      _matchesSesion.insert(0, {...matchRes, 'vacante': item});
      notifyListeners();
      return true;
    }
    return false;
  }

  void deshacerLike(int historialIndex) {
    if (historialIndex < 0 || historialIndex >= _historial.length) return;
    final item = Map<String, dynamic>.from(_historial[historialIndex]);
    if (item['tipo'] != 'like' || item['match'] == true) return;
    item['tipo'] = 'dislike';
    item['le_dio_like'] = false;
    item['match'] = false;
    item['timestamp'] = DateTime.now().toIso8601String();
    _historial[historialIndex] = item;
    notifyListeners();
  }

  void resetDailySwipes() { _dailySwipes = 0; notifyListeners(); }

  void limpiar() {
    _vacantes = [];
    _historial.clear();
    _matchesSesion.clear();
    _matchesServidor.clear();
    _vacanteIdsVistas.clear();
    _currentIndex = 0;
    _dailySwipes  = 0;
    _estudianteId = null;
    _filtroModalidad = null;
    _filtroUbicacion = null;
    _filtroSueldoMin = null;
    notifyListeners();
  }
}