// lib/data/repositories/media_repository.dart

import 'dart:io';
import '../../core/services/api_service.dart';

class MediaRepository {
  MediaRepository._();
  static final MediaRepository instance = MediaRepository._();

  final _api = ApiService.instance;

  // ── Foto estudiante ───────────────────────────────────────────────────────
  // Respuesta: { usuario_id, media_type, object_name, bucket, url, content_type, size }
  Future<String> uploadFotoEstudiante(int usuarioId, File foto) async {
    final res = await _api.uploadFile(
      '/media/estudiantes/$usuarioId/foto',
      file: foto,
      fieldName: 'file',
    );
    return res['url'] as String? ?? ''; // ← 'url', no 'foto_perfil_url'
  }

  Future<void> deleteFotoEstudiante(int usuarioId) async {
    await _api.delete('/media/estudiantes/$usuarioId/foto');
  }

  // ── CV estudiante ─────────────────────────────────────────────────────────
  Future<String> uploadCvEstudiante(int usuarioId, File cv) async {
    final res = await _api.uploadFile(
      '/media/estudiantes/$usuarioId/cv',
      file: cv,
      fieldName: 'file',
    );
    return res['url'] as String? ?? ''; // ← 'url', no 'cv_url'
  }

  Future<void> deleteCvEstudiante(int usuarioId) async {
    await _api.delete('/media/estudiantes/$usuarioId/cv');
  }

  // ── Foto empresa ──────────────────────────────────────────────────────────
  // Respuesta: { usuario_id, media_type, object_name, bucket, url, content_type, size }
  Future<String> uploadFotoEmpresa(int usuarioId, File foto) async {
    final res = await _api.uploadFile(
      '/media/empresas/$usuarioId/foto',
      file: foto,
      fieldName: 'file',
    );
    return res['url'] as String? ?? '';
  }

  Future<void> deleteFotoEmpresa(int usuarioId) async {
    await _api.delete('/media/empresas/$usuarioId/foto');
  }
}