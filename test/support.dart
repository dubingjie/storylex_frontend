import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storylex/core/api.dart';
import 'package:storylex/core/session_store.dart';
import 'package:storylex/data/models.dart';
import 'package:storylex/state/app_controller.dart';

class MemorySessions implements SessionStore {
  MemorySessions([this.value]);
  Session? value;
  @override
  Future<Session?> read() async => value;
  @override
  Future<void> write(Session session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

http.Response response(Object data, {int code = 200, String msg = 'success'}) =>
    http.Response(
      jsonEncode({'code': code, 'msg': msg, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

class FakeBackend {
  int target = 10, reviewTarget = 10;
  String book = 'CET6luan_1';
  bool expired = false, failSwitch = false, offline = false;
  final requests = <http.Request>[];
  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (offline) throw http.ClientException('offline');
    final path = request.url.path;
    if (path == '/api/auth/login' || path == '/api/auth/register') {
      return response({
        'token': 'test-token',
        'username': '测试读者',
        'user_id': 9,
      });
    }
    if (expired) return response({}, code: 401, msg: 'Token已过期');
    if (path == '/api/auth/me') {
      return response({'user_id': 9, 'username': '测试读者'});
    }
    if (path == '/api/user/books') {
      return response({
        'current_book_id': book,
        'books': [
          {
            'book_id': 'CET6luan_1',
            'title': '六级核心词汇',
            'description': '大学英语六级',
            'total_words': 1229,
            'learned_words': 214,
            'mastered_words': 42,
            'is_current': book == 'CET6luan_1',
          },
          {
            'book_id': 'KaoYan_2',
            'title': '考研核心词汇',
            'description': '考研阅读词汇',
            'total_words': 2000,
            'learned_words': 70,
            'mastered_words': 12,
            'is_current': book == 'KaoYan_2',
          },
        ],
      });
    }
    if (path == '/api/user/book') {
      if (failSwitch) return response({}, code: 400, msg: '词书暂不可用');
      book = object(jsonDecode(request.body))['book_id'] as String;
      return response({'current_book_id': book});
    }
    if (path == '/api/words/target/update') {
      final body = object(jsonDecode(request.body));
      if (body['task_type'] == 'new') {
        target = body['target_count'] as int;
      } else {
        reviewTarget = body['target_count'] as int;
      }
      return response({});
    }
    if (path == '/api/words/dashboard/summary') {
      return response({
        'current_book': {
          'book_id': book,
          'title': book == 'CET6luan_1' ? '六级核心词汇' : '考研核心词汇',
        },
        'new_task': {
          'target_count': target,
          'learned_today': 3,
          'is_completed': false,
          'available_count': 1000,
          'can_start': true,
        },
        'review_task': {
          'target_count': reviewTarget,
          'reviewed_today': 2,
          'is_completed': false,
          'due_count': 7,
          'can_start': true,
        },
        'last_story': null,
      });
    }
    if (path == '/api/user/stats') {
      return response({
        'total_study_days': 7,
        'total_learned_words': 326,
        'total_mastered_words': 86,
        'total_read_stories': 12,
      });
    }
    throw StateError('Unexpected API: $path');
  }

  AppController controller(MemorySessions store) => AppController(
    StoryLexRepository(
      ApiClient(client: MockClient(handle), baseUrl: 'http://api.test'),
    ),
    store,
  );
}
