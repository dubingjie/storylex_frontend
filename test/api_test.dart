import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storylex/core/api.dart';

import 'support.dart';

void main() {
  test('Checks business error codes inside HTTP 200 and retains backend validation messages', () async {
    final api = ApiClient(
      client: MockClient((_) async => response({}, code: 400, msg: '用户名或密码错误')),
    );
    await expectLater(
      api.request('POST', '/api/auth/login', auth: false),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', '用户名或密码错误'),
      ),
    );
    api.close();
  });
  test('Sends UTF8 JSON and bearer token; does not send stale authorization on login', () async {
    final seen = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        seen.add(request);
        return response({'title': '六级词书'});
      }),
    )..token = 'synthetic';
    final result = await api.request(
      'PUT',
      '/api/user/book',
      body: {'book_id': '词书'},
    );
    expect(result['title'], '六级词书');
    expect(seen.single.headers['authorization'], 'Bearer synthetic');
    expect(jsonDecode(seen.single.body)['book_id'], '词书');
    await api.request('POST', '/api/auth/login', auth: false);
    expect(seen.last.headers.containsKey('authorization'), false);
    api.close();
  });
  test(
    'Both HTTP and business 401 invalidate an authenticated session',
    () async {
      for (final http401 in [false, true]) {
        var invalidated = 0;
        final api =
            ApiClient(
                client: MockClient(
                  (_) async => http401
                      ? http.Response('unauthorized', 401)
                      : response({}, code: 401),
                ),
              )
              ..token = 'expired'
              ..onUnauthorized = () => invalidated++;
        await expectLater(
          api.request('GET', '/api/auth/me'),
          throwsA(isA<ApiException>()),
        );
        expect(invalidated, 1);
        api.close();
      }
    },
  );
  test('Does not expose raw SQL failures, malformed responses or transport exceptions', () async {
    for (final value in [
      response({}, code: 500, msg: 'SQL secret'),
      http.Response('<html>failure</html>', 502),
    ]) {
      final api = ApiClient(client: MockClient((_) async => value));
      try {
        await api.request('GET', '/api/user/stats');
        fail('must fail');
      } on ApiException catch (e) {
        expect(e.message, isNot(contains('SQL')));
        expect(e.message, isNot(contains('<html>')));
      }
      api.close();
    }
  });
  test('Times out hanging requests', () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      api.request('GET', '/api/auth/me'),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', contains('超时')),
      ),
    );
    pending.complete(response({}));
    api.close();
  });
}
