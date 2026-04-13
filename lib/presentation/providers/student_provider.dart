// lib/presentation/providers/student_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider extends ChangeNotifier {
  final _repo = StudentRepository.instance;

  int? _estudianteId;

  // ── Feed ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _vacantes = [];
  int  _currentIndex  = 0;
  int  _dailySwipes   = 0;
  // FIX: maxSwipes es público para que la UI lo use en la barra de progreso
  final int maxSwipes = 20;
  bool _cargandoVacantes = false;

  // ── Filtros ───────────────────────────────────────────────────────────────
  String? _filtroModalidad;
  String? _filtroUbicacion;
  double? _filtroSueldoMin;
  // Filtros nuevos
  String? _filtroBusqueda;
  String? _filtroContrato;
  String? _filtroEmpresa;

  List<Map<String, dynamic>> get vacantes      => _vacantes;
  int  get currentIndex                         => _currentIndex;
  bool get hasReachedLimit                      => _dailySwipes >= maxSwipes;
  int  get remainingSwipes                      => maxSwipes - _dailySwipes;
  bool get cargandoVacantes                     => _cargandoVacantes;
  String? get filtroModalidad                   => _filtroModalidad;
  String? get filtroUbicacion                   => _filtroUbicacion;
  double? get filtroSueldoMin                   => _filtroSueldoMin;
  String? get filtroBusqueda                    => _filtroBusqueda;
  String? get filtroContrato                    => _filtroContrato;
  String? get filtroEmpresa                     => _filtroEmpresa;

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

  // Set de IDs vistos — única fuente de verdad
  final Set<int> _vacanteIdsVistas = {};

  // ── Clave para persistir swipes del día ───────────────────────────────────
  static String _prefKeySwipes(int id) => 'daily_swipes_${id}_${_hoyKey()}';
  static String _hoyKey() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2,'0')}${n.day.toString().padLeft(2,'0')}';
  }

  // ── Cargar historial ──────────────────────────────────────────────────────
  Future<void> cargarHistorial(int estudianteId) async {
    _estudianteId = estudianteId;
    _cargandoHistorial = true;
    notifyListeners();
    try {
      // FIX: restaurar swipes del día desde SharedPreferences
      await _restaurarSwipesDiarios(estudianteId);

      final serverItems = await _repo.getHistorialEstudiante(estudianteId);
      debugPrint('[StudentProvider] historial: ${serverItems.length} items');

      _vacanteIdsVistas.clear();
      for (final v in serverItems) {
        final id = v['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }
      for (final h in _historial) {
        final id = h['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }

      final deServidor = serverItems.map((v) {
        final leDioLike = v['le_dio_like'] as bool? ?? false;
        final ts = leDioLike
            ? (v['fecha_like'] as String? ?? v['ultima_visualizacion'] as String? ?? '')
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

      _filtrarVacantesVistas();
    } catch (e) {
      debugPrint('[StudentProvider] cargarHistorial error: $e');
    }
    _cargandoHistorial = false;
    notifyListeners();
  }

  // FIX: restaurar contador de swipes del día actual desde prefs
  Future<void> _restaurarSwipesDiarios(int estudianteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefKeySwipes(estudianteId);
      _dailySwipes = prefs.getInt(key) ?? 0;
      // Limpiar claves de días anteriores
      final keysViejas = prefs.getKeys()
          .where((k) => k.startsWith('daily_swipes_${estudianteId}_') && k != key);
      for (final k in keysViejas) await prefs.remove(k);
    } catch (_) {}
  }

  Future<void> _guardarSwipesDiarios() async {
    if (_estudianteId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKeySwipes(_estudianteId!), _dailySwipes);
    } catch (_) {}
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
    String? modalidad, String? ubicacion, double? sueldoMin,
    String? busqueda, String? contrato, String? empresa,
    bool resetIndex = false, int? estudianteId,
  }) async {
    if (estudianteId != null) _estudianteId = estudianteId;
    final id = _estudianteId;

    _cargandoVacantes = true;
    notifyListeners();

    try {
      final modFinal    = modalidad ?? _filtroModalidad;
      final ubicFinal   = ubicacion ?? _filtroUbicacion;
      final sueldoFinal = sueldoMin ?? _filtroSueldoMin;
      final buscFinal   = busqueda  ?? _filtroBusqueda;
      final contrFinal  = contrato  ?? _filtroContrato;
      final empFinal    = empresa   ?? _filtroEmpresa;

      final hayFiltros = modFinal != null || ubicFinal != null ||
          sueldoFinal != null || buscFinal != null ||
          contrFinal != null || empFinal != null;

      List<Map<String, dynamic>> lista = [];

      if (!hayFiltros && id != null) {
        lista = await _repo.getVacantesFeed(id);
      } else {
        lista = await _repo.getVacantes(
          modalidad: modFinal,
          ubicacion: ubicFinal,
          sueldoMin: sueldoFinal,
        );
      }

      // FIX: filtros locales para los que el backend no soporta query params
      lista = _aplicarFiltrosLocales(lista,
          busqueda: buscFinal, contrato: contrFinal, empresa: empFinal);

      lista = _deduplicar(lista);
      _vacantes = lista;
      debugPrint('[StudentProvider] vacantes disponibles: ${lista.length}');
      _currentIndex = 0;
    } catch (e) {
      debugPrint('[StudentProvider] cargarVacantes error: $e');
      _vacantes = [];
      _currentIndex = 0;
    }
    _cargandoVacantes = false;
    notifyListeners();
  }

  // Filtros que se aplican localmente sobre los resultados del servidor
  List<Map<String, dynamic>> _aplicarFiltrosLocales(
    List<Map<String, dynamic>> lista, {
    String? busqueda, String? contrato, String? empresa,
  }) {
    return lista.where((v) {
      // Búsqueda por título o nombre de empresa
      if (busqueda != null && busqueda.isNotEmpty) {
        final q = busqueda.toLowerCase();
        final titulo    = (v['titulo']         as String? ?? '').toLowerCase();
        final empNombre = (v['empresa_nombre'] as String? ?? '').toLowerCase();
        final desc      = (v['descripcion']    as String? ?? '').toLowerCase();
        if (!titulo.contains(q) && !empNombre.contains(q) && !desc.contains(q)) {
          return false;
        }
      }
      // Filtro por tipo de contrato
      if (contrato != null && contrato.isNotEmpty) {
        final c = (v['tipo_contrato'] as String? ?? '').toLowerCase();
        if (!c.contains(contrato.toLowerCase())) return false;
      }
      // Filtro por nombre de empresa
      if (empresa != null && empresa.isNotEmpty) {
        final e = (v['empresa_nombre'] as String? ?? '').toLowerCase();
        if (!e.contains(empresa.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _deduplicar(List<Map<String, dynamic>> lista) {
    final vistos = <int>{};
    final resultado = <Map<String, dynamic>>[];
    for (final v in lista) {
      final id = v['id'] as int?;
      if (id == null) continue;
      if (_vacanteIdsVistas.contains(id)) continue;
      if (vistos.contains(id)) continue;
      vistos.add(id);
      resultado.add(v);
    }
    return resultado;
  }

  void _filtrarVacantesVistas() {
    if (_vacanteIdsVistas.isEmpty) { _currentIndex = 0; return; }
    _vacantes = _deduplicar(_vacantes);
    _currentIndex = 0;
    // FIX: NO sobreescribir _dailySwipes con el conteo del historial
    // porque el historial incluye días anteriores. Solo usar el valor
    // restaurado desde SharedPreferences (_restaurarSwipesDiarios).
  }

  // ── Aplicar / limpiar filtros ─────────────────────────────────────────────
  Future<void> aplicarFiltros({
    String? modalidad, String? ubicacion, double? sueldoMin,
    String? busqueda, String? contrato, String? empresa,
  }) async {
    _filtroModalidad = modalidad;
    _filtroUbicacion = ubicacion;
    _filtroSueldoMin = sueldoMin;
    _filtroBusqueda  = busqueda;
    _filtroContrato  = contrato;
    _filtroEmpresa   = empresa;
    await cargarVacantes(
      modalidad: modalidad, ubicacion: ubicacion, sueldoMin: sueldoMin,
      busqueda: busqueda, contrato: contrato, empresa: empresa,
      resetIndex: true,
    );
  }

  void limpiarFiltros() {
    _filtroModalidad = null;
    _filtroUbicacion = null;
    _filtroSueldoMin = null;
    _filtroBusqueda  = null;
    _filtroContrato  = null;
    _filtroEmpresa   = null;
    cargarVacantes(resetIndex: true);
  }

  // ── Like ──────────────────────────────────────────────────────────────────
  // FIX: se eliminó registrarVista() — el swipe ya lo registra en el backend.
  Future<bool> likeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return false;
    _estudianteId = estudianteId;
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    if (vacanteId != null) _vacanteIdsVistas.add(vacanteId);
    _dailySwipes++;
    _currentIndex++;
    await _guardarSwipesDiarios();

    bool esMatch = false;
    if (vacanteId != null) {
      final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
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

    if (vacanteId != null) _vacanteIdsVistas.add(vacanteId);

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
    await _guardarSwipesDiarios();
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
    _repo.limpiarCache();
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
    _filtroBusqueda  = null;
    _filtroContrato  = null;
    _filtroEmpresa   = null;
    notifyListeners();
  }
}