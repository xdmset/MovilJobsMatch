import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../errors/api_exceptions.dart';
import 'token_storage.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final _client = http.Client();

  // ── Headers ───────────────────────────────────────────────────────────────
  Map<String, String> get _jsonHeaders => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<Map<String, String>> get _authHeaders async {
    final authHeader = await TokenStorage.instance.getAuthHeader();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': authHeader,
    };
  }

  // ── POST JSON ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final uri = Uri.parse('${ApiConstants.apiBaseUrl}$path');
    final headers = auth ? await _authHeaders : _jsonHeaders;
    final bodyStr = jsonEncode(body);

    // ignore: avoid_print
    print('▶ POST $uri\n  body: $bodyStr');

    try {
      final response = await _client
          .post(uri, headers: headers, body: bodyStr)
          .timeout(ApiConstants.timeout);
      // ignore: avoid_print
      print('◀ ${response.statusCode} ${response.body}');
      return _handle(response);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.timeout();
    }
  }

  // ── GET ───────────────────────────────────────────────────────────────────
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    var uri = Uri.parse('${ApiConstants.apiBaseUrl}$path');
    if (query != null) uri = uri.replace(queryParameters: query);
    final headers = auth ? await _authHeaders : _jsonHeaders;

    // ignore: avoid_print
    print('▶ GET $uri');

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(ApiConstants.timeout);
      // ignore: avoid_print
      print('◀ ${response.statusCode} ${response.body}');
      return _handleRaw(response);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.timeout();
    }
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('${ApiConstants.apiBaseUrl}$path');
    final headers = auth ? await _authHeaders : _jsonHeaders;

    try {
      final response = await _client
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(ApiConstants.timeout);
      return _handle(response);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.timeout();
    }
  }

  // ── PATCH ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final uri = Uri.parse('${ApiConstants.apiBaseUrl}$path');
    final headers = auth ? await _authHeaders : _jsonHeaders;

    try {
      final response = await _client
          .patch(uri, headers: headers, body: jsonEncode(body))
          .timeout(ApiConstants.timeout);
      return _handle(response);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.timeout();
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('${ApiConstants.apiBaseUrl}$path');
    final headers = await _authHeaders;

    try {
      final response = await _client
          .delete(uri, headers: headers)
          .timeout(ApiConstants.timeout);
      return _handle(response);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.timeout();
    }
  }

  // ── Upload multipart ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required File file,
    required String fieldName,
  }) async {
    final uri = Uri.parse('${ApiConstants.apiBaseUrl}$path');
    final authHeader = await TokenStorage.instance.getAuthHeader();

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = authHeader
      ..files.add(await http.MultipartFile.fromPath(fieldName, file.path));

    try {
      final streamed = await request.send().timeout(ApiConstants.timeout);
      final response = await http.Response.fromStream(streamed);
      return _handle(response);
    } on SocketException {
      throw ApiException.network();
    } on TimeoutException {
      throw ApiException.timeout();
    }
  }

  // ── Response handlers ─────────────────────────────────────────────────────
  Map<String, dynamic> _handle(http.Response response) {
    final raw = _handleRaw(response);
    if (raw is Map<String, dynamic>) return raw;
    return {'data': raw};
  }

  dynamic _handleRaw(http.Response response) {
    final code = response.statusCode;

    if (code >= 200 && code < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    Map<String, dynamic>? errorBody;
    try {
      errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {}

    throw ApiException.fromStatusCode(code, errorBody);
  }
}