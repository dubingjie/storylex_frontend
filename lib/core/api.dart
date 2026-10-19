import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code});
  final String message;
  final int? code;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.30.97:5000',
    ),
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;
  String? token;
  void Function()? onUnauthorized;

  Future<Json> request(
    String method,
    String path, {
    Json? body,
    bool auth = true,
  }) async {
    final sentToken = auth ? token : null;
    try {
      final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (sentToken != null) {
        request.headers['Authorization'] = 'Bearer $sentToken';
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      if (response.statusCode == 401) {
        if (auth && sentToken != null && token == sentToken) {
          onUnauthorized?.call();
        }
        throw const ApiException('登录已过期，请重新登录。', code: 401);
      }
      Json envelope;
      try {
        envelope = object(jsonDecode(utf8.decode(response.bodyBytes)));
      } catch (_) {
        throw const ApiException('服务响应异常，请稍后重试。');
      }
      final code = envelope['code'];
      if (code != 200 ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        if (code == 401 && auth && sentToken != null && token == sentToken) {
          onUnauthorized?.call();
        }
        // Do not render raw SQL errors, stack traces or HTML to the user.
        final message = code is num && code >= 500
            ? '服务暂时不可用，请稍后重试。'
            : envelope['msg'] as String? ?? '请求未成功，请重试。';
        throw ApiException(
          message,
          code: code is int ? code : response.statusCode,
        );
      }
      return object(envelope['data'] ?? <String, dynamic>{});
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('连接超时，请检查网络后重试。');
    } on http.ClientException {
      throw const ApiException('无法连接服务，请检查网络和后端服务是否已启动。');
    } catch (_) {
      throw const ApiException('暂时无法完成请求，请稍后重试。');
    }
  }

  void close() => _client.close();
}

class StoryLexRepository {
  StoryLexRepository(this.api);
  final ApiClient api;
  Future<Session> authenticate(
    String username,
    String password, {
    required bool register,
  }) async {
    final data = await api.request(
      'POST',
      '/api/auth/${register ? 'register' : 'login'}',
      auth: false,
      body: {'username': username.trim(), 'password': password},
    );
    return Session(
      data['token'] as String,
      data['username'] as String,
      needsBook: register,
    );
  }

  Future<String> me() async =>
      (await api.request('GET', '/api/auth/me'))['username'] as String;
  Future<BookCatalog> books() async =>
      BookCatalog.fromJson(await api.request('GET', '/api/user/books'));
  Future<HomeData> home() async {
    final values = await Future.wait([
      api.request('GET', '/api/words/dashboard/summary'),
      api.request('GET', '/api/user/stats'),
      api.request('GET', '/api/user/books'),
    ]);
    return HomeData(
      Dashboard.fromJson(values[0]),
      UserStats.fromJson(values[1]),
      BookCatalog.fromJson(values[2]),
    );
  }

  Future<void> switchBook(String id) async {
    await api.request('PUT', '/api/user/book', body: {'book_id': id});
  }

  Future<void> updateTarget(String type, int count) async {
    await api.request(
      'PUT',
      '/api/words/target/update',
      body: {'task_type': type, 'target_count': count},
    );
  }
}
