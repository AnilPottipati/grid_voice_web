import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// A failed server call, with the server's own message when it gave one.
class ApiException implements Exception {
  const ApiException(this.message, {this.status});

  final String message;
  final int? status;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Talks to the Grid server. Sends the session cookie with every call.
class ApiClient {
  ApiClient() : _http = BrowserClient()..withCredentials = true;

  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(AppConfig.serverOrigin);
    return base.replace(path: path, queryParameters: query);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _send(() => _http.get(_uri(path, query)));
    return _decode(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _send(
      () => _http.post(
        _uri(path),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> postBytes(
    String path,
    Uint8List bytes, {
    Map<String, String>? query,
  }) async {
    final res = await _send(
      () => _http.post(
        _uri(path, query),
        headers: const {'Content-Type': 'application/octet-stream'},
        body: bytes,
      ),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _send(() => _http.delete(_uri(path, query)));
    return _decode(res);
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call();
    } catch (_) {
      throw const ApiException('Could not reach the server.');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = {};
    try {
      final parsed = jsonDecode(utf8.decode(res.bodyBytes));
      if (parsed is Map<String, dynamic>) body = parsed;
    } catch (_) {}
    if (res.statusCode >= 400) {
      final detail = body['detail'];
      throw ApiException(
        detail is String ? detail : 'Request failed (HTTP ${res.statusCode}).',
        status: res.statusCode,
      );
    }
    return body;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
