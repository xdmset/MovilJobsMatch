// lib/presentation/providers/student_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/retroalimentacion_repository.dart';

class StudentProvider extends ChangeNotifier {
  final _repo      = StudentRepository.instance;
  final _retroRepo = RetroalimentacionRepository.instance;

  int? _estudianteId;

  // ── Premium flag ───────────────────────────────────────────────────────────
  // Inyectado desde AuthProvider. Cuando es true, hasReachedLimit siempre
  // devuelve false (swipes ilimitados) y remainingSwipes devuelve null.
  bool _esPremium = false;

  void setPremium(bool value) {
    if (_esPremium == value) return;
    _esPremium = value;
    notifyListeners();
    debugPrint('[StudentProvider] esPremium → $_esPremium');
  }

  bool get esPremium => _esPremium;

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

  // CAMBIO CLAVE: premium → nunca llega al límite
  bool get hasReachedLimit => _esPremium ? false : _dailySwipes >= maxSwipes;

  // null cuando es premium (ilimitado), número concreto cuando no lo es
  int? get remainingSwipes => _esPremium ? null : maxSwipes - _dailySwipes;

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

  // ── NUEVOS ENDPOINTS ESPECÍFICOS DE SWIPES ────────────────────────────────
  final List<Map<String, dynamic>> _aceptadas = [];
  final List<Map<String, dynamic>> _pendientes = [];
  final List<Map<String, dynamic>> _rechazadasPorEmpresa = [];

  List<Map<String, dynamic>> get aceptadas =>
      List.unmodifiable(_aceptadas);
  List<Map<String, dynamic>> get pendientes =>
      List.unmodifiable(_pendientes);
  List<Map<String, dynamic>> get rechazadasPorEmpresa =>
      List.unmodifiable(_rechazadasPorEmpresa);

  // ── Historial ─────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> get historial => List.unmodifiable(_historial);
  bool _cargandoHistorial = false;
  bool get cargandoHistorial => _cargandoHistorial;

  // FIX PRINCIPAL: Set de IDs ya procesados — única fuente de verdad.
  final Set<int> _vacanteIdsVistas = {};

  bool _historialCargado = false;
  bool get historialCargado => _historialCargado;

  // ── Clave SharedPreferences para swipes por hora ────────────────────────
  static String _prefKeySwipes(int id) => 'hourly_swipes_${id}_${_horaKey()}';
  static String _horaKey() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2,'0')}${n.day.toString().padLeft(2,'0')}${n.hour.toString().padLeft(2,'0')}';
  }

  // ── Cargar historial — SIEMPRE llamar antes de cargarVacantes ────────────
  Future<void> cargarHistorial(int estudianteId) async {
    _estudianteId = estudianteId;
    _cargandoHistorial = true;
    notifyListeners();
    try {
      await _restaurarSwipesHorarios(estudianteId);

      final serverItems = await _repo.getHistorialEstudiante(estudianteId);
      debugPrint('[StudentProvider] historial: ${serverItems.length} items');

      final idsLocalesSesion = Set<int>.from(_vacanteIdsVistas);

      _vacanteIdsVistas.clear();
      for (final v in serverItems) {
        final id = v['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }
      _vacanteIdsVistas.addAll(idsLocalesSesion);
      for (final h in _historial) {
        final id = h['id'] as int?;
        if (id != null) _vacanteIdsVistas.add(id);
      }

      debugPrint('[StudentProvider] _vacanteIdsVistas: ${_vacanteIdsVistas.length} IDs');

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

        return <String, dynamic>{
          ...v,
          'tipo':               leDioLike ? 'like' : 'dislike',
          'timestamp':          ts,
          'match':              tieneMatch,
          'le_dio_like':        leDioLike,
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

  Future<void> _restaurarSwipesHorarios(int estudianteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefKeySwipes(estudianteId);
      _dailySwipes = prefs.getInt(key) ?? 0;
      final keysViejas = prefs.getKeys()
          .where((k) => k.startsWith('hourly_swipes_${estudianteId}_') && k != key);
      for (final k in keysViejas) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  Future<void> _guardarSwipesDiarios() async {
    if (_estudianteId == null) return;
    // Si es premium, no gastamos el contador (aunque lo incrementamos
    // localmente para analytics, no lo persistimos como límite)
    if (_esPremium) return;
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

        Map<String, dynamic>? vacanteData = vacanteId != null
            ? _historial.cast<Map<String, dynamic>?>()
                .firstWhere((h) => h?['id'] == vacanteId, orElse: () => null)
            : null;

        if ((vacanteData == null || vacanteData.isEmpty) && vacanteId != null) {
          debugPrint('[StudentProvider] match vacante $vacanteId no en historial, cargando...');
          vacanteData = await _repo.getVacanteById(vacanteId);
        }

        _matchesServidor.add({
          ...m,
          'vacante': vacanteData ?? {'id': vacanteId},
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[StudentProvider] cargarMatches error: $e');
    }
  }

  // ── NUEVOS MÉTODOS PARA ENDPOINTS ESPECÍFICOS DE SWIPES ───────────────────

  /// Cargar aceptadas (matches confirmados)
  Future<void> cargarAceptadas(int estudianteId) async {
    _estudianteId = estudianteId;
    try {
      _aceptadas.clear();
      final lista = await _repo.getAceptadasEstudiante(estudianteId);
      _aceptadas.addAll(lista);
      debugPrint('[StudentProvider] aceptadas: ${_aceptadas.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('[StudentProvider] cargarAceptadas error: $e');
    }
  }

  /// Cargar pendientes (vacantes esperando respuesta)
  Future<void> cargarPendientes(int estudianteId) async {
    _estudianteId = estudianteId;
    try {
      _pendientes.clear();
      final lista = await _repo.getPendientesEstudiante(estudianteId);
      // Enriquecer con nombre/foto de empresa igual que el feed
      final enriquecidas = await _repo.enriquecerConEmpresa(lista);
      _pendientes.addAll(enriquecidas);
      debugPrint('[StudentProvider] pendientes: ${_pendientes.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('[StudentProvider] cargarPendientes error: $e');
    }
  }

  /// Cargar rechazadas por empresa, enriquecidas con postulacion_id desde
  /// /retroalimentacion/estudiante/{id} (fuente más fiable que postulaciones).
  Future<void> cargarRechazadoPorEmpresa(int estudianteId) async {
    _estudianteId = estudianteId;
    try {
      _rechazadasPorEmpresa.clear();

      // Cargar en paralelo: vacantes rechazadas + retros + postulaciones
      final (lista, retros, postulaciones) = await (
        _repo.getRechazadoPorEmpresa(estudianteId),
        _retroRepo.getRetrosEstudiante(estudianteId),
        _repo.getPostulacionesEstudiante(estudianteId),
      ).wait;

      // vacante_id → postulacion_id desde postulaciones del estudiante
      final postMap = <int, int>{};
      for (final p in postulaciones) {
        final vid = p['vacante_id'] as int?;
        final pid = p['id'] as int?;
        if (vid != null && pid != null) postMap[vid] = pid;
      }

      // Inyectar postulacion_id desde el mejor source disponible
      final enriquecidas = lista.map((v) {
        final vacanteId = v['id'] as int?;
        // Fuente 1: mapa de postulaciones (postulacion_id por vacante_id)
        final postId = vacanteId != null ? postMap[vacanteId] : null;
        if (postId != null && !v.containsKey('postulacion_id')) {
          return <String, dynamic>{...v, 'postulacion_id': postId};
        }
        return v;
      }).toList();

      _rechazadasPorEmpresa.addAll(enriquecidas);
      final conPostId = enriquecidas.where((v) => v.containsKey('postulacion_id')).length;
      debugPrint('[StudentProvider] rechazadas por empresa: '
          '${_rechazadasPorEmpresa.length} (con postulacion_id: $conPostId, '
          'retros disponibles: ${retros.length})');
      notifyListeners();
    } catch (e) {
      debugPrint('[StudentProvider] cargarRechazadoPorEmpresa error: $e');
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

      final hayFiltrosLocales = buscFinal != null || contrFinal != null || empFinal != null;
      if (hayFiltrosLocales) {
        lista = _aplicarFiltrosLocales(lista,
            busqueda: buscFinal, contrato: contrFinal, empresa: empFinal);
        debugPrint('[StudentProvider] tras filtros locales: ${lista.length} vacantes');
      }

      lista = _deduplicar(lista);

      _vacantes = lista;
      _currentIndex = 0;
      debugPrint('[StudentProvider] vacantes disponibles tras dedup: ${lista.length} '
          '(vistas: ${_vacanteIdsVistas.length})');

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

  List<Map<String, dynamic>> _aplicarFiltrosLocales(
    List<Map<String, dynamic>> lista, {
    String? busqueda, String? contrato, String? empresa,
  }) {
    return lista.where((v) {
      if (busqueda != null && busqueda.isNotEmpty) {
        final q      = busqueda.toLowerCase().trim();
        final titulo = (v['titulo']         as String? ?? '').toLowerCase();
        final empN   = (v['empresa_nombre'] as String? ?? '').toLowerCase();
        final desc   = (v['descripcion']    as String? ?? '').toLowerCase();
        final requi  = (v['requisitos']     as String? ?? '').toLowerCase();
        if (!titulo.contains(q) && !empN.contains(q) &&
            !desc.contains(q) && !requi.contains(q)) {
          return false;
        }
      }
      if (contrato != null && contrato.isNotEmpty) {
        final cFiltro = contrato.toLowerCase().trim();
        final cVac    = (v['tipo_contrato'] as String? ?? '').toLowerCase().trim();
        if (cVac.isEmpty) return false;
        if (!cVac.contains(cFiltro) && !cFiltro.contains(cVac)) return false;
      }
      if (empresa != null && empresa.isNotEmpty) {
        final e = (v['empresa_nombre'] as String? ?? '').toLowerCase();
        if (!e.contains(empresa.toLowerCase().trim())) return false;
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

    if (vacanteId != null) _vacanteIdsVistas.add(vacanteId);
    _dailySwipes++;
    _currentIndex++;
    await _guardarSwipesDiarios();

    bool esMatch = false;
    if (vacanteId != null) {
      unawaited(_repo.registrarVista(vacanteId));
      final matchRes = await _repo.registrarSwipe(estudianteId, vacanteId, true);
      if (matchRes != null) {
        esMatch = true;
        _matchesSesion.insert(0, {...matchRes, 'vacante': v});
      }
    }

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
    _esPremium = false;
    _filtroModalidad = null;
    _filtroUbicacion = null;
    _filtroSueldoMin = null;
    _filtroBusqueda  = null;
    _filtroContrato  = null;
    _filtroEmpresa   = null;
    notifyListeners();
  }
}