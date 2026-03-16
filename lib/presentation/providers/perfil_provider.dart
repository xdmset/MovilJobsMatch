// lib/presentation/providers/perfil_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/errors/api_exceptions.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/perfil_repository.dart';
import '../../data/repositories/media_repository.dart';

enum PerfilStatus { inicial, cargando, cargado, error }

class PerfilProvider extends ChangeNotifier {
  final _repo  = PerfilRepository.instance;
  final _media = MediaRepository.instance;

  PerfilStatus _status = PerfilStatus.inicial;
  PerfilEstudiante? _perfil;
  String? _error;
  bool _uploadingFoto = false;
  bool _uploadingCv   = false;

  PerfilStatus get status      => _status;
  PerfilEstudiante? get perfil => _perfil;
  String? get error            => _error;
  bool get cargando            => _status == PerfilStatus.cargando;
  bool get uploadingFoto       => _uploadingFoto;
  bool get uploadingCv         => _uploadingCv;
  bool get tienePerfil         => _perfil != null;

  // ── Cargar ────────────────────────────────────────────────────────────────
  Future<void> cargarPerfil(int usuarioId) async {
    _status = PerfilStatus.cargando;
    _error  = null;
    notifyListeners();
    try {
      _perfil = await _repo.getPerfil(usuarioId);
      _status = PerfilStatus.cargado;
    } on ApiException catch (e) {
      _error  = e.message;
      _status = PerfilStatus.error;
    } catch (_) {
      _error  = 'Error al cargar el perfil.';
      _status = PerfilStatus.error;
    }
    notifyListeners();
  }

  // ── Actualizar datos ──────────────────────────────────────────────────────
  Future<bool> actualizarPerfil(
    int usuarioId, {
    String? nombreCompleto,
    String? institucionEducativa,
    String? nivelAcademico,
    String? biografia,
    String? habilidades,
    String? ubicacion,
    String? modalidadPreferida,
  }) async {
    _status = PerfilStatus.cargando;
    _error  = null;
    notifyListeners();
    try {
      _perfil = await _repo.updatePerfil(
        usuarioId,
        nombreCompleto:       nombreCompleto,
        institucionEducativa: institucionEducativa,
        nivelAcademico:       nivelAcademico,
        biografia:            biografia,
        habilidades:          habilidades,
        ubicacion:            ubicacion,
        modalidadPreferida:   modalidadPreferida,
      );
      _status = PerfilStatus.cargado;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error  = e.message;
      _status = PerfilStatus.error;
      notifyListeners();
      return false;
    } catch (_) {
      _error  = 'Error al actualizar el perfil.';
      _status = PerfilStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Subir foto ────────────────────────────────────────────────────────────
  Future<bool> subirFoto(int usuarioId, File foto) async {
    _uploadingFoto = true;
    _error = null;
    notifyListeners();
    try {
      await _media.uploadFotoEstudiante(usuarioId, foto);
      // Recargar perfil completo para obtener la URL firmada actualizada
      _perfil = await _repo.getPerfil(usuarioId);
      _status = PerfilStatus.cargado;
      _uploadingFoto = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _uploadingFoto = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Error al subir la foto.';
      _uploadingFoto = false;
      notifyListeners();
      return false;
    }
  }

  // ── Eliminar foto ─────────────────────────────────────────────────────────
  Future<bool> eliminarFoto(int usuarioId) async {
    _uploadingFoto = true;
    _error = null;
    notifyListeners();
    try {
      await _media.deleteFotoEstudiante(usuarioId);
      if (_perfil != null) {
        _perfil = PerfilEstudiante(
          usuarioId:           _perfil!.usuarioId,
          nombreCompleto:      _perfil!.nombreCompleto,
          institucionEducativa:_perfil!.institucionEducativa,
          nivelAcademico:      _perfil!.nivelAcademico,
          biografia:           _perfil!.biografia,
          habilidades:         _perfil!.habilidades,
          ubicacion:           _perfil!.ubicacion,
          modalidadPreferida:  _perfil!.modalidadPreferida,
          cvUrl:               _perfil!.cvUrl,
          cvTipoArchivo:       _perfil!.cvTipoArchivo,
          fotoPerfilUrl:       null,
        );
      }
      _uploadingFoto = false;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Error al eliminar la foto.';
      _uploadingFoto = false;
      notifyListeners();
      return false;
    }
  }

  // ── Subir CV ──────────────────────────────────────────────────────────────
  Future<bool> subirCv(int usuarioId, File cv) async {
    _uploadingCv = true;
    _error = null;
    notifyListeners();
    try {
      await _media.uploadCvEstudiante(usuarioId, cv);
      // Recargar perfil completo para obtener la URL firmada actualizada
      _perfil = await _repo.getPerfil(usuarioId);
      _status = PerfilStatus.cargado;
      _uploadingCv = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _uploadingCv = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Error al subir el CV.';
      _uploadingCv = false;
      notifyListeners();
      return false;
    }
  }

  // ── Eliminar CV ───────────────────────────────────────────────────────────
  Future<bool> eliminarCv(int usuarioId) async {
    _uploadingCv = true;
    _error = null;
    notifyListeners();
    try {
      await _media.deleteCvEstudiante(usuarioId);
      if (_perfil != null) {
        _perfil = PerfilEstudiante(
          usuarioId:           _perfil!.usuarioId,
          nombreCompleto:      _perfil!.nombreCompleto,
          institucionEducativa:_perfil!.institucionEducativa,
          nivelAcademico:      _perfil!.nivelAcademico,
          biografia:           _perfil!.biografia,
          habilidades:         _perfil!.habilidades,
          ubicacion:           _perfil!.ubicacion,
          modalidadPreferida:  _perfil!.modalidadPreferida,
          cvUrl:               null,
          cvTipoArchivo:       null,
          fotoPerfilUrl:       _perfil!.fotoPerfilUrl,
        );
      }
      _uploadingCv = false;
      notifyListeners();
      return true;
    } catch (_) {
      _error = 'Error al eliminar el CV.';
      _uploadingCv = false;
      notifyListeners();
      return false;
    }
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}