import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'env.dart';

/// Error returned by the API ({ success: false, message, errors? }) or by the network.
class ApiException implements Exception {
  final int status;
  final String message;
  final Map<String, List<String>> errors;

  ApiException(this.status, this.message, [this.errors = const {}]);

  /// First field error, e.g. "Choose an assignee first", else the main message.
  String get details => errors.values.expand((e) => e).isNotEmpty
      ? '$message: ${errors.values.expand((e) => e).first}'
      : message;

  @override
  String toString() => details;
}

/// Small HTTP helper around the Next.js REST API.
///
/// Every response looks like `{ success, data, message }`; the helpers return `data`.
/// The session token from /api/auth/login is sent as `Authorization: Bearer <token>`.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'session_token';

  final http.Client _http = http.Client();
  String? _token;

  /// Called when the server answers 401 (session expired) so the app can go back to login.
  void Function()? onUnauthorized;

  String get baseUrl => Env.apiBaseUrl;
  String? get token => _token;

  /// Reads the saved token (secure storage) at app start.
  Future<String?> loadToken() async {
    _token = await _storage.read(key: _tokenKey);
    return _token;
  }

  Future<void> saveToken(String? token) async {
    _token = token;
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Builds `/api/{path}?query`, dropping empty query values.
  Uri uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
    });
    return Uri.parse('$baseUrl/api$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) =>
      _send(() => _http.get(uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _http.post(uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, [Object? body]) =>
      _send(() => _http.patch(uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path, [Object? body]) => _send(
      () => _http.delete(uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)));

  /// Multipart upload (attachments): field name "files".
  Future<dynamic> upload(String path, List<({String name, Uint8List bytes})> files) {
    return _send(() async {
      final req = http.MultipartRequest('POST', uri(path));
      req.headers['Accept'] = 'application/json';
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
      for (final f in files) {
        req.files.add(http.MultipartFile.fromBytes('files', f.bytes, filename: f.name));
      }
      return http.Response.fromStream(await _http.send(req));
    });
  }

  /// Downloads a file (e.g. attachment) with the auth header and returns its bytes.
  Future<Uint8List> download(String path) async {
    final res = await _http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode != 200) throw ApiException(res.statusCode, 'Download failed');
    return res.bodyBytes;
  }

  /// Runs the request, unwraps `data`, and turns failures into [ApiException].
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(const Duration(seconds: 30));
    } on SocketException {
      throw ApiException(0, 'No internet connection or server unreachable');
    } on HttpException {
      throw ApiException(0, 'Network error, please try again');
    } on Exception catch (e) {
      throw ApiException(0, e.toString().contains('Timeout') ? 'The server took too long to respond' : 'Network error');
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(res.statusCode, 'Unexpected server response (${res.statusCode})');
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && json['success'] == true) {
      return json['data'];
    }

    if (res.statusCode == 401 && _token != null) onUnauthorized?.call();
    final errors = <String, List<String>>{};
    (json['errors'] as Map<String, dynamic>?)?.forEach((k, v) => errors[k] = List<String>.from(v as List));
    throw ApiException(res.statusCode, json['message']?.toString() ?? 'Request failed', errors);
  }
}
