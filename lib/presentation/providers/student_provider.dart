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

  // Filtros activos
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

  // ── Matches (sesión) ──────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> get matches => List.unmodifiable(_matches);

  // ── Historial ─────────────────────────────────────────────────────────────
  // Fuente de verdad: GET /vacante/historial/estudiante/{id}
  // El endpoint devuelve SOLO vacantes vistas (tiene primera_visualizacion).
  // Los dislikes sin vista previa se guardan localmente en _soloLocales.
  //
  // Formato de cada item:
  // { ...campos vacante, tipo: 'like'|'dislike', timestamp, match: bool,
  //   le_dio_like: bool, total_visualizaciones: int? }
  final List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> get historial => List.unmodifiable(_historial);

  bool _cargandoHistorial = false;
  bool get cargandoHistorial => _cargandoHistorial;

  // ── Cargar vacantes ───────────────────────────────────────────────────────
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
      if (resetIndex || _historial.isEmpty) {
        _currentIndex = 0;
        _dailySwipes  = 0;
      }
    } catch (_) { _vacantes = []; }
    _cargandoVacantes = false;
    notifyListeners();
  }

  // Aplicar filtros y recargar
  Future<void> aplicarFiltros({
    String? modalidad, String? ubicacion, double? sueldoMin,
  }) async {
    _filtroModalidad = modalidad;
    _filtroUbicacion = ubicacion;
    _filtroSueldoMin = sueldoMin;
    await cargarVacantes(
        modalidad: modalidad, ubicacion: ubicacion,
        sueldoMin: sueldoMin, resetIndex: true);
  }

  void limpiarFiltros() {
    _filtroModalidad = null; _filtroUbicacion = null; _filtroSueldoMin = null;
    cargarVacantes(resetIndex: true);
  }

  // ── Registrar vista ───────────────────────────────────────────────────────
  Future<void> registrarVista(int vacanteId) async =>
      _repo.registrarVista(vacanteId);

  // ── Cargar historial del servidor ─────────────────────────────────────────
  // Siempre recarga del servidor — es la fuente de verdad.
  // Los dislikes puros (sin vista) que están en _historial local se preservan.
  Future<void> cargarHistorial(int estudianteId) async {
    _cargandoHistorial = true;
    notifyListeners();
    try {
      final serverItems = await _repo.getHistorialEstudiante(estudianteId);

      // Convertir al formato interno
      final deServidor = serverItems.map((v) {
        final leDioLike = v['le_dio_like'] as bool? ?? false;
        // Preferir fecha_like, luego ultima_visualizacion
        final ts = (leDioLike
            ? v['fecha_like'] as String?
            : v['ultima_visualizacion'] as String?) ?? '';
        return <String, dynamic>{
          ...v,
          'tipo':        leDioLike ? 'like' : 'dislike',
          'timestamp':   ts,
          'match':       false,
          'le_dio_like': leDioLike,
        };
      }).toList();

      // IDs que vienen del servidor
      final idsServidor = deServidor
          .map((v) => v['id'] as int?)
          .whereType<int>()
          .toSet();

      // Conservar solo los items locales que el servidor NO conoce
      // (dislikes puros sin vista, que nunca llegaron al historial del servidor)
      final soloLocales = _historial
          .where((h) => !idsServidor.contains(h['id'] as int?))
          .toList();

      _historial
        ..clear()
        ..addAll(deServidor)
        ..addAll(soloLocales);

      // Ordenar por timestamp descendente
      _historial.sort((a, b) {
        final ta = a['timestamp'] as String? ?? '';
        final tb = b['timestamp'] as String? ?? '';
        return tb.compareTo(ta);
      });
    } catch (e) {
      debugPrint('[StudentProvider] Error cargarHistorial: $e');
    }
    _cargandoHistorial = false;
    notifyListeners();
  }

  // ── Like ──────────────────────────────────────────────────────────────────
  Future<bool> likeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return false;
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    // Primero registrar la vista para que el historial del servidor lo capture
    if (vacanteId != null) await _repo.registrarVista(vacanteId);

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

    // Actualizar/insertar en historial local inmediatamente
    final localItem = <String, dynamic>{
      ...v,
      'tipo':        'like',
      'timestamp':   DateTime.now().toIso8601String(),
      'match':       esMatch,
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
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    // Registrar vista también en dislike (el servidor trackea la visualización)
    if (vacanteId != null) await _repo.registrarVista(vacanteId);

    final localItem = <String, dynamic>{
      ...v,
      'tipo':        'dislike',
      'timestamp':   DateTime.now().toIso8601String(),
      'match':       false,
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

  // ── Deshacer like ─────────────────────────────────────────────────────────
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
    _currentIndex = 0; _dailySwipes = 0;
    notifyListeners();
  }
}