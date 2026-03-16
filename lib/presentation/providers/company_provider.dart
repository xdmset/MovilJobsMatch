// lib/presentation/providers/company_provider.dart

import 'package:flutter/material.dart';
import '../../core/errors/api_exceptions.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/company_repository.dart';

enum CompanyStatus { inicial, cargando, cargado, error }

class CompanyProvider extends ChangeNotifier {
  final _repo = CompanyRepository.instance;

  CompanyStatus _status = CompanyStatus.inicial;
  PerfilEmpresa? _perfil;
  List<Map<String, dynamic>> _vacantes = [];
  List<Map<String, dynamic>> _postulaciones = [];
  String? _error;
  bool _updatingPerfil = false;

  CompanyStatus get status       => _status;
  PerfilEmpresa? get perfil      => _perfil;
  List<Map<String, dynamic>> get vacantes      => _vacantes;
  List<Map<String, dynamic>> get postulaciones => _postulaciones;
  String? get error              => _error;
  bool get cargando              => _status == CompanyStatus.cargando;
  bool get updatingPerfil        => _updatingPerfil;

  // ── Cargar todo el dashboard ──────────────────────────────────────────────
  Future<void> cargarDashboard(int userId) async {
    _status = CompanyStatus.cargando;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getPerfil(userId),
        _repo.getVacantes(userId),
        _repo.getPostulaciones(userId),
      ]);
      _perfil        = results[0] as PerfilEmpresa;
      _vacantes      = results[1] as List<Map<String, dynamic>>;
      _postulaciones = results[2] as List<Map<String, dynamic>>;
      _status = CompanyStatus.cargado;
    } on ApiException catch (e) {
      _error  = e.message;
      _status = CompanyStatus.error;
    } catch (_) {
      _error  = 'Error al cargar el dashboard.';
      _status = CompanyStatus.error;
    }
    notifyListeners();
  }

  Future<void> recargarPostulaciones(int userId) async {
    try {
      _postulaciones = await _repo.getPostulaciones(userId);
      notifyListeners();
    } catch (_) {}
  }

  // ── Actualizar perfil ─────────────────────────────────────────────────────
  Future<bool> actualizarPerfil(int userId, {
    String? nombreComercial,
    String? sector,
    String? descripcion,
    String? sitioWeb,
    String? ubicacionSede,
  }) async {
    _updatingPerfil = true;
    _error = null;
    notifyListeners();
    try {
      _perfil = await _repo.updatePerfil(userId,
        nombreComercial: nombreComercial,
        sector: sector,
        descripcion: descripcion,
        sitioWeb: sitioWeb,
        ubicacionSede: ubicacionSede,
      );
      _updatingPerfil = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _updatingPerfil = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Error al actualizar el perfil.';
      _updatingPerfil = false;
      notifyListeners();
      return false;
    }
  }

  void limpiar() {
    _status = CompanyStatus.inicial;
    _perfil = null;
    _vacantes = [];
    _postulaciones = [];
    _error = null;
    notifyListeners();
  }
}