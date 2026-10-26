import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
    // 免费后端冷启动常需 30~60 秒，超时须覆盖唤醒时间，否则首次请求必失败。
    this.timeout = const Duration(seconds: 90),
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
    Duration? requestTimeout,
    bool retryOnTimeout = false,
  }) async {
    // GET 与显式允许的请求（如登录）在超时后自动重试一次，
    // 以便后端冷启动超过单次超时时仍有机会成功；
    // 答题等写请求不重试，避免服务端已处理却因响应丢失而重复提交。
    final canRetry = method == 'GET' || retryOnTimeout;
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await _requestOnce(
          method,
          path,
          body: body,
          auth: auth,
          requestTimeout: requestTimeout,
        );
      } on TimeoutException {
        if (canRetry && attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        throw const ApiException('连接超时，请检查网络后重试。');
      }
    }
  }

  Future<Json> _requestOnce(
    String method,
    String path, {
    Json? body,
    bool auth = true,
    Duration? requestTimeout,
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
      ))().timeout(requestTimeout ?? timeout);
      return _decodeResponse(response, auth: auth, sentToken: sentToken);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on http.ClientException {
      throw const ApiException('无法连接服务，请检查网络和后端服务是否已启动。');
    } catch (_) {
      throw const ApiException('暂时无法完成请求，请稍后重试。');
    }
  }

  Future<Json> uploadFile(
    String path, {
    required Uint8List bytes,
    required String filename,
    required Json fields,
    bool auth = true,
  }) async {
    final sentToken = auth ? token : null;
    try {
      final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..fields.addAll(fields.map((key, value) => MapEntry(key, '$value')))
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
      if (sentToken != null) {
        request.headers['Authorization'] = 'Bearer $sentToken';
      }
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      return _decodeResponse(response, auth: auth, sentToken: sentToken);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('上传超时，请检查网络后重试。');
    } on http.ClientException {
      throw const ApiException('无法连接服务，请检查网络和后端服务是否已启动。');
    } catch (_) {
      throw const ApiException('暂时无法完成上传，请稍后重试。');
    }
  }

  Json _decodeResponse(
    http.Response response, {
    required bool auth,
    required String? sentToken,
  }) {
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
      final message = code is num && code >= 500
          ? '服务暂时不可用，请稍后重试。'
          : envelope['msg'] as String? ?? '请求未成功，请重试。';
      throw ApiException(
        message,
        code: code is int ? code : response.statusCode,
      );
    }
    return object(envelope['data'] ?? <String, dynamic>{});
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
      // 登录可安全重试（冷启动兜底）；注册不重试，避免重复提交后误报已存在。
      retryOnTimeout: !register,
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
