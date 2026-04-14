// lib/presentation/providers/student_provider.dart

import 'dart:async';
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
  final int maxSwipes = 20;
  bool _cargandoVacantes = false;

  // ── Filtros ───────────────────────────────────────────────────────────────
  String? _filtroModalidad;
  String? _filtroUbicacion;
  double? _filtroSueldoMin;
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
  String? get filtrosBusqueda                   => _filtroBusqueda;
  String? get filtroBusqueda                    => _filtroBusqueda;
  String? get filtroContrato                    => _filtroContrato;
  String? get filtroEmpresa                     => _filtroEmpresa;

  bool get hayFiltrosActivos =>
      _filtroModalidad != null || _filtroUbicacion != null ||
      _filtroSueldoMin != null || _filtroBusqueda != null ||
      _filtroContrato  != null || _filtroEmpresa  != null;

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

  // FIX PRINCIPAL: Set de IDs ya procesados — única fuente de verdad.
  // Se llena desde el historial del servidor en cargarHistorial().
  // TODO los métodos de carga de vacantes lo usan para deduplicar.
  final Set<int> _vacanteIdsVistas = {};

  // Flag para saber si el historial ya fue cargado
  bool _historialCargado = false;
  bool get historialCargado => _historialCargado;

  // ── Clave SharedPreferences para swipes del día ───────────────────────────
  static String _prefKeySwipes(int id) => 'daily_swipes_${id}_${_hoyKey()}';
  static String _hoyKey() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2,'0')}${n.day.toString().padLeft(2,'0')}';
  }

  // ── Cargar historial — SIEMPRE llamar antes de cargarVacantes ────────────
  Future<void> cargarHistorial(int estudianteId) async {
    _estudianteId = estudianteId;
    _cargandoHistorial = true;
    notifyListeners();
    try {
      await _restaurarSwipesDiarios(estudianteId);

      final serverItems = await _repo.getHistorialEstudiante(estudianteId);
      debugPrint('[StudentProvider] historial: ${serverItems.length} items');

      // Preservar IDs locales de sesión ANTES de limpiar
      // (son los swipes que ya registramos en esta sesión pero el servidor
      //  aún no los tiene en el historial porque /view puede tardar o fallar)
      final idsLocalesSesion = Set<int>.from(_vacanteIdsVistas);

      // Reconstruir el set completo de IDs vistos desde el servidor
      _vacanteIdsVistas.clear();
      for (final v in serverItems) {
        final id = v['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }
      // Re-agregar los IDs locales (unión servidor + sesión)
      _vacanteIdsVistas.addAll(idsLocalesSesion);
      // También incluir cualquier item del historial local no cubierto
      for (final h in _historial) {
        final id = h['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }

      debugPrint('[StudentProvider] _vacanteIdsVistas: ${_vacanteIdsVistas.length} IDs');

      // IDs con match real del servidor (cargados previamente en cargarMatches)
      final matchVacanteIds = _matchesServidor
          .map((m) => m['vacante_id'] as int?)
          .whereType<int>()
          .toSet();

      final deServidor = serverItems.map((v) {
        final leDioLike = v['le_dio_like'] as bool? ?? false;
        final vacanteId = v['id'] as int?;
        final tieneMatch = vacanteId != null &&
            matchVacanteIds.contains(vacanteId);
        final ts = leDioLike
            ? (v['fecha_like'] as String? ?? v['ultima_visualizacion'] as String? ?? '')
            : (v['ultima_visualizacion'] as String? ?? '');

        // Preservar estado_postulacion y feedback si vienen del servidor
        return <String, dynamic>{
          ...v,
          'tipo':               leDioLike ? 'like' : 'dislike',
          'timestamp':          ts,
          'match':              tieneMatch,
          'le_dio_like':        leDioLike,
          // Preservar campos de postulación si existen
          if (v['estado_postulacion'] != null)
            'estado_postulacion': v['estado_postulacion'],
          if (v['feedback'] != null) 'feedback': v['feedback'],
          if (v['campos_mejora'] != null) 'campos_mejora': v['campos_mejora'],
          if (v['sugerencias_perfil'] != null)
            'sugerencias_perfil': v['sugerencias_perfil'],
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

      _historialCargado = true;

      // FIX: filtrar las vacantes en memoria que ya fueron vistas
      if (_vacantes.isNotEmpty) {
        _vacantes = _deduplicar(_vacantes);
        _currentIndex = 0;
      }

    } catch (e) {
      debugPrint('[StudentProvider] cargarHistorial error: $e');
    }
    _cargandoHistorial = false;
    notifyListeners();
  }

  Future<void> _restaurarSwipesDiarios(int estudianteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefKeySwipes(estudianteId);
      _dailySwipes = prefs.getInt(key) ?? 0;
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
  // FIX: siempre espera a que el historial esté cargado antes de pedir el feed,
  // así _vacanteIdsVistas tiene todos los IDs y _deduplicar() funciona bien.
  Future<void> cargarVacantes({
    String? modalidad, String? ubicacion, double? sueldoMin,
    String? busqueda, String? contrato, String? empresa,
    bool resetIndex = false, int? estudianteId,
  }) async {
    if (estudianteId != null) _estudianteId = estudianteId;
    final id = _estudianteId;

    // FIX: si el historial no se cargó todavía, cargarlo primero
    // para tener _vacanteIdsVistas completo antes de pedir el feed
    if (!_historialCargado && id != null) {
      await cargarHistorial(id);
    }

    _cargandoVacantes = true;
    notifyListeners();

    try {
      final modFinal    = modalidad ?? _filtroModalidad;
      final ubicFinal   = ubicacion ?? _filtroUbicacion;
      final sueldoFinal = sueldoMin ?? _filtroSueldoMin;
      final buscFinal   = busqueda  ?? _filtroBusqueda;
      final contrFinal  = contrato  ?? _filtroContrato;
      final empFinal    = empresa   ?? _filtroEmpresa;

      List<Map<String, dynamic>> lista = [];

      // SIEMPRE usar el feed del servidor (filtra las ya vistas en el backend).
      // Los filtros de modalidad, ubicación y sueldo que el backend soporta se
      // envían como query params; el resto se aplica localmente después.
      // De esta forma _deduplicar() siempre tiene _vacanteIdsVistas completo.
      if (id != null) {
        lista = await _repo.getVacantesFeed(
          id,
          modalidad: modFinal,
          ubicacion: ubicFinal,
          sueldoMin: sueldoFinal,
        );
        debugPrint('[StudentProvider] feed servidor: ${lista.length} vacantes '
            '(modalidad: $modFinal, ubicacion: $ubicFinal, sueldo: $sueldoFinal)');
      }

      // Filtros locales: búsqueda de texto, tipo de contrato y empresa
      final hayFiltrosLocales = buscFinal != null || contrFinal != null || empFinal != null;
      if (hayFiltrosLocales) {
        lista = _aplicarFiltrosLocales(lista,
            busqueda: buscFinal, contrato: contrFinal, empresa: empFinal);
        debugPrint('[StudentProvider] tras filtros locales: ${lista.length} vacantes');
      }

      // FIX: siempre deduplicar — elimina tanto repetidos en el array
      // como los que ya están en _vacanteIdsVistas (historial del servidor)
      lista = _deduplicar(lista);

      _vacantes = lista;
      _currentIndex = 0;
      debugPrint('[StudentProvider] vacantes disponibles tras dedup: ${lista.length} '
          '(vistas: ${_vacanteIdsVistas.length})');

      // Registrar vista de la primera tarjeta del feed para que aparezca
      // en el historial del backend desde el primer momento
      if (lista.isNotEmpty) {
        final primerIdVacante = lista.first['id'] as int?;
        if (primerIdVacante != null) {
          unawaited(_repo.registrarVista(primerIdVacante));
        }
      }
    } catch (e) {
      debugPrint('[StudentProvider] cargarVacantes error: $e');
      _vacantes = [];
      _currentIndex = 0;
    }
    _cargandoVacantes = false;
    notifyListeners();
  }

  // Filtros que el backend no soporta y se aplican en memoria
  List<Map<String, dynamic>> _aplicarFiltrosLocales(
    List<Map<String, dynamic>> lista, {
    String? busqueda, String? contrato, String? empresa,
  }) {
    return lista.where((v) {
      // Búsqueda de texto: título, nombre de empresa, descripción y requisitos
      if (busqueda != null && busqueda.isNotEmpty) {
        final q      = busqueda.toLowerCase().trim();
        final titulo = (v['titulo']         as String? ?? '').toLowerCase();
        final empN   = (v['empresa_nombre'] as String? ?? '').toLowerCase();
        final desc   = (v['descripcion']    as String? ?? '').toLowerCase();
        final requi  = (v['requisitos']     as String? ?? '').toLowerCase();
        if (!titulo.contains(q) && !empN.contains(q) &&
            !desc.contains(q) && !requi.contains(q)) return false;
      }
      // Tipo de contrato: comparación case-insensitive, acepta parcial
      if (contrato != null && contrato.isNotEmpty) {
        final cFiltro = contrato.toLowerCase().trim();
        final cVac    = (v['tipo_contrato'] as String? ?? '').toLowerCase().trim();
        // Si la vacante no tiene contrato definido y se filtra por contrato → excluir
        if (cVac.isEmpty) return false;
        if (!cVac.contains(cFiltro) && !cFiltro.contains(cVac)) return false;
      }
      // Empresa: comparación case-insensitive
      if (empresa != null && empresa.isNotEmpty) {
        final e = (v['empresa_nombre'] as String? ?? '').toLowerCase();
        if (!e.contains(empresa.toLowerCase().trim())) return false;
      }
      return true;
    }).toList();
  }

  // FIX: elimina duplicados dentro del array Y las ya vistas
  List<Map<String, dynamic>> _deduplicar(List<Map<String, dynamic>> lista) {
    final vistos = <int>{};
    final resultado = <Map<String, dynamic>>[];
    for (final v in lista) {
      final id = v['id'] as int?;
      if (id == null) continue;
      if (_vacanteIdsVistas.contains(id)) continue; // ya procesada
      if (vistos.contains(id)) continue;             // duplicada en el array
      vistos.add(id);
      resultado.add(v);
    }
    return resultado;
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
  Future<bool> likeVacancy(int estudianteId) async {
    if (hasReachedLimit || currentVacancy == null) return false;
    _estudianteId = estudianteId;
    final v         = currentVacancy!;
    final vacanteId = v['id'] as int?;

    // Marcar como vista ANTES de avanzar el índice
    if (vacanteId != null) _vacanteIdsVistas.add(vacanteId);
    _dailySwipes++;
    _currentIndex++;
    await _guardarSwipesDiarios();

    bool esMatch = false;
    if (vacanteId != null) {
      // Registrar vista en el historial del backend (necesario para que
      // aparezca en /vacante/historial/estudiante/{id})
      unawaited(_repo.registrarVista(vacanteId));
      final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
      if (matchRes != null) {
        esMatch = true;
        _matchesSesion.insert(0, {...matchRes, 'vacante': v});
      }
    }

    // Registrar vista de la SIGUIENTE tarjeta si existe
    final nextVacancy = currentVacancy;
    final nextId = nextVacancy?['id'] as int?;
    if (nextId != null) unawaited(_repo.registrarVista(nextId));

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

    if (vacanteId != null) {
      _vacanteIdsVistas.add(vacanteId);
      // Registrar vista en el historial del backend
      unawaited(_repo.registrarVista(vacanteId));
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
    await _guardarSwipesDiarios();
    notifyListeners();

    // Registrar vista de la SIGUIENTE tarjeta si existe
    final nextId = currentVacancy?['id'] as int?;
    if (nextId != null) unawaited(_repo.registrarVista(nextId));

    if (vacanteId != null) {
      unawaited(_repo.registrarSwipe(estudianteId, vacanteId, false));
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
    _historialCargado = false;
    _filtroModalidad = null;
    _filtroUbicacion = null;
    _filtroSueldoMin = null;
    _filtroBusqueda  = null;
    _filtroContrato  = null;
    _filtroEmpresa   = null;
    notifyListeners();
  }
}