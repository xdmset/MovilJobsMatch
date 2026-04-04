// lib/presentation/providers/student_provider.dart

import 'package:flutter/material.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  final _repo = StudentRepository.instance;

  // ── Vacantes ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _vacantes = [];
  int  _currentIndex  = 0;
  int  _dailySwipes   = 0;
  final int _maxSwipes = 10;
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

  // IDs de vacantes ya procesadas (vistas+swipeadas en el servidor)
  // Este Set es la FUENTE DE VERDAD para no repetir vacantes.
  final Set<int> _vacanteIdsVistas = {};
  Set<int> get vacanteIdsVistas => Set.unmodifiable(_vacanteIdsVistas);

  // ── Cargar historial PRIMERO ──────────────────────────────────────────────
  // Siempre debe llamarse antes de cargarVacantes al iniciar sesión.
  Future<void> cargarHistorial(int estudianteId) async {
    _cargandoHistorial = true;
    notifyListeners();
    try {
      final serverItems = await _repo.getHistorialEstudiante(estudianteId);
      debugPrint('[Historial] ${serverItems.length} items del servidor');

      // Reconstruir set de IDs vistos
      _vacanteIdsVistas.clear();
      for (final v in serverItems) {
        final id = v['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }
      debugPrint('[Historial] IDs vistos: $_vacanteIdsVistas');

      // Convertir al formato interno
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

      // Conservar items locales que el servidor aún no tiene
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

      // Si ya hay vacantes cargadas, sincronizar índice inmediatamente
      if (_vacantes.isNotEmpty) {
        _sincronizarIndice();
        debugPrint('[Historial] Índice sincronizado a $_currentIndex');
      }
    } catch (e) {
      debugPrint('[Historial] ERROR: $e');
    }
    _cargandoHistorial = false;
    notifyListeners();
  }

  // ── Cargar vacantes DESPUÉS del historial ─────────────────────────────────
  Future<void> cargarVacantes({
    String? modalidad, String? ubicacion, double? sueldoMin,
    bool resetIndex = false,
  }) async {
    _cargandoVacantes = true;
    notifyListeners();
    try {
      _vacantes = await _repo.getVacantes(
        modalidad: modalidad ?? _filtroModalidad,
        ubicacion: ubicacion ?? _filtroUbicacion,
        sueldoMin: sueldoMin ?? _filtroSueldoMin,
      );
      debugPrint('[Vacantes] ${_vacantes.length} vacantes cargadas');

      if (resetIndex) {
        _currentIndex = 0;
        _dailySwipes  = 0;
        debugPrint('[Vacantes] Reset índice a 0');
      } else {
        _sincronizarIndice();
        debugPrint('[Vacantes] Índice sincronizado a $_currentIndex / ${_vacantes.length}');
      }
    } catch (e) {
      debugPrint('[Vacantes] ERROR: $e');
      _vacantes = [];
    }
    _cargandoVacantes = false;
    notifyListeners();
  }

  // Avanza el índice hasta la primera vacante NO vista
  void _sincronizarIndice() {
    if (_vacanteIdsVistas.isEmpty) {
      _currentIndex = 0;
      _dailySwipes  = 0;
      return;
    }
    int idx = 0;
    while (idx < _vacantes.length) {
      final id = _vacantes[idx]['id'] as int?;
      if (id == null || !_vacanteIdsVistas.contains(id)) break;
      idx++;
    }
    _currentIndex = idx;
    // dailySwipes refleja cuántas se han procesado hoy
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

    // 1. Registrar vista (hace que aparezca en historial del servidor)
    if (vacanteId != null) {
      await _repo.registrarVista(vacanteId);
      _vacanteIdsVistas.add(vacanteId);
    }

    _dailySwipes++;
    _currentIndex++;

    // 2. Registrar swipe (puede generar match)
    bool esMatch = false;
    if (vacanteId != null) {
      final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
      if (matchRes != null) {
        esMatch = true;
        _matches.insert(0, {...matchRes, 'vacante': v});
      }
    }

    // 3. Actualizar historial local
    final localItem = <String, dynamic>{
      ...v, 'tipo': 'like', 'timestamp': DateTime.now().toIso8601String(),
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

    // Registrar vista para que el servidor sepa que se vio
    if (vacanteId != null) {
      await _repo.registrarVista(vacanteId);
      _vacanteIdsVistas.add(vacanteId);
    }

    final localItem = <String, dynamic>{
      ...v, 'tipo': 'dislike', 'timestamp': DateTime.now().toIso8601String(),
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
  Future<bool> cambiarOpinion(int estudianteId, int historialIndex) async {
    if (historialIndex < 0 || historialIndex >= _historial.length) return false;
    final item      = Map<String, dynamic>.from(_historial[historialIndex]);
    if (item['tipo'] == 'like') return false;
    final vacanteId = item['id'] as int?;
    if (vacanteId == null) return false;

    item['tipo'] = 'like'; item['le_dio_like'] = true;
    _historial[historialIndex] = item;
    notifyListeners();

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

  void deshacerLike(int historialIndex) {
    if (historialIndex < 0 || historialIndex >= _historial.length) return;
    final item = Map<String, dynamic>.from(_historial[historialIndex]);
    if (item['tipo'] != 'like' || item['match'] == true) return;
    item['tipo'] = 'dislike'; item['le_dio_like'] = false; item['match'] = false;
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