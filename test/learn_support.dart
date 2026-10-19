import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:storylex/data/models.dart';

import 'support.dart';

Json copyJson(Json j) => object(jsonDecode(jsonEncode(j)));

class LearnBackend extends FakeBackend {
  int settledWords = 0,
      settlements = 0,
      groupCounter = 0,
      mistakes = 0,
      answerWrites = 0,
      masterWrites = 0,
      favoriteWrites = 0;
  bool failAnswerAfterCommit = false,
      failCompleteAfterCommit = false,
      stale = false;
  Completer<void>? answerGate;
  final answerStarted = Completer<void>();
  final favorites = <int>{}, masters = <int>{};
  final groups = <String, Json>{}, receipts = <String, Json>{};
  final answerBodies = <Json>[];
  Json? active;
  Json makeWord(int id) => {
    'word_id': id,
    'word': switch (id) {
      1 => 'blind',
      2 => 'earnestly',
      _ => 'flustered',
    },
    'uk_phone': 'blaɪnd',
    'us_phone': 'blaɪnd',
    'question_id': 'q$id-v0',
    'passed': false,
    'is_mastered': false,
    'is_favorited': favorites.contains(id),
    'version': 0,
    'correct': 'A',
    'mistakes': 0,
    'options': [
      {'key': 'A', 'trans': id == 1 ? 'adj. 失明的' : 'adv. 认真地'},
      {'key': 'B', 'trans': 'n. 天空'},
      {'key': 'C', 'trans': 'v. 保持'},
      {'key': 'D', 'trans': 'adj. 宁静的'},
    ],
  };
  Json packet(Json g) {
    final words = g['words'] as List;
    return {
      'group_id': g['id'],
      'total': words.length,
      'passed_count': words.where((w) => w['passed'] == true).length,
      'words': words
          .map(
            (w) => copyJson(object(w))
              ..remove('correct')
              ..remove('mistakes')
              ..remove('version'),
          )
          .toList(),
    };
  }

  @override
  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (path == '/api/words/dashboard/summary') {
      final value = await super.handle(r);
      if (expired) return value;
      final envelope = object(jsonDecode(value.body)),
          data = object(envelope['data']);
      data['new_task'] = {
        'target_count': target,
        'learned_today': settledWords,
        'is_completed': settledWords >= target,
        'available_count': math.max(0, 3 - settledWords - masters.length),
        'can_start':
            active != null && active!['completed'] != true ||
            settledWords < target && settledWords < 3,
      };
      return response(data);
    }
    if (![
      '/api/words/learn/group',
      '/api/words/learn/answer',
      '/api/words/learn/group/complete',
      '/api/words/master',
      '/api/words/favorite/list',
      '/api/words/favorite/toggle',
    ].contains(path))
      return super.handle(r);
    requests.add(r);
    if (expired) return response({}, code: 401, msg: 'Token已过期');
    if (path == '/api/words/learn/group') {
      if (stale) {
        active = null;
        stale = false;
      }
      if (active == null || active!['completed'] == true) {
        final count = math.min(
          2,
          math.min(target - settledWords, 3 - settledWords),
        );
        if (count <= 0)
          return response({
            'group_id': null,
            'total': 0,
            'passed_count': 0,
            'words': [],
          });
        active = {
          'id': 'group-${++groupCounter}',
          'completed': false,
          'words': [
            for (var i = 0; i < count; i++) makeWord(settledWords + i + 1),
          ],
        };
        groups[active!['id'] as String] = active!;
      }
      return response(packet(active!));
    }
    if (path == '/api/words/favorite/list') {
      final keyword = r.url.queryParameters['keyword'] ?? '';
      final rows = [
        for (final id in favorites)
          if ((makeWord(id)['word'] as String).contains(keyword))
            {'word_id': id, 'word': makeWord(id)['word']},
      ];
      return response({
        'total': rows.length,
        'page': 1,
        'page_size': 200,
        'list': rows,
      });
    }
    final body = object(jsonDecode(r.body));
    if (path == '/api/words/favorite/toggle') {
      favoriteWrites++;
      final id = number(body['word_id']);
      if (!favorites.add(id)) favorites.remove(id);
      return response({'is_favorited': favorites.contains(id)});
    }
    if (path == '/api/words/learn/answer' &&
        receipts.containsKey(body['request_id'])) {
      answerBodies.add(body);
      return response(receipts[body['request_id']]!);
    }
    final g = groups[body['group_id']];
    if (g == null) return response({}, code: 400, msg: '题组不存在');
    final words = g['words'] as List;
    if (path == '/api/words/learn/group/complete') {
      if (g['completed'] == true) return response(g['summary']);
      if (stale || words.any((w) => w['passed'] != true))
        return response({}, code: 400, msg: '本组尚未全部通过');
      settlements++;
      settledWords += words.length;
      g['completed'] = true;
      final result = {
        'group_id': g['id'],
        'summary_list': [
          for (final w in words)
            {
              'word_id': w['word_id'],
              'word': w['word'],
              'trans': 'adj. 失明的',
              'is_mastered': w['is_mastered'],
              'performance': w['is_mastered'] == true
                  ? '已掌握'
                  : w['mistakes'] == 0
                  ? '一次通过'
                  : '错${w['mistakes']}次',
            },
        ],
      };
      g['summary'] = result;
      if (failCompleteAfterCommit) {
        failCompleteAfterCommit = false;
        return response({}, code: 500);
      }
      return response(result);
    }
    if (stale) return response({}, code: 400, msg: '题组已跨日，请重新获取今日题组');
    final w = words.cast<Json>().firstWhere(
      (w) => w['word_id'] == body['word_id'],
    );
    if (path == '/api/words/master') {
      masterWrites++;
      w['passed'] = true;
      w['is_mastered'] = true;
      masters.add(number(w['word_id']));
      return response({
        'word_id': w['word_id'],
        'is_mastered': true,
        'passed_count': words.where((w) => w['passed'] == true).length,
        'total': words.length,
      });
    }
    answerBodies.add(body);
    if (w['passed'] == true || w['question_id'] != body['question_id'])
      return response({}, code: 400, msg: '题目版本已更新，请重新获取题组');
    answerWrites++;
    final correct =
        body['is_show_answer'] != true && body['selected_key'] == w['correct'];
    final result = <String, dynamic>{
      'is_correct': correct,
      'correct_key': w['correct'],
      'word_detail': {
        'translations': [
          {'pos': 'adj', 'tranCn': '失明的；看不见的'},
        ],
        'sentences': [
          {'sContent': 'He was blind to the truth.', 'sCn': '他对真相视而不见。'},
        ],
        'phrases': [
          {'pContent': 'be blind to', 'pCn': '对…视而不见'},
        ],
        'rem_method': '把词义放进句子里。',
      },
    };
    if (correct) {
      w['passed'] = true;
    } else {
      mistakes++;
      w['mistakes'] = (w['mistakes'] as int) + 1;
      w['version'] = (w['version'] as int) + 1;
      w['question_id'] = 'q${w['word_id']}-v${w['version']}';
      final options = w['options'] as List;
      final old = copyJson(object(options[0]));
      options[0]['trans'] = options[2]['trans'];
      options[2]['trans'] = old['trans'];
      w['correct'] = w['correct'] == 'A' ? 'C' : 'A';
      result['retry_question'] =
          (packet({
                    'id': g['id'],
                    'words': [w],
                  })['words']
                  as List)
              .first;
    }
    result['passed_count'] = words.where((w) => w['passed'] == true).length;
    result['total'] = words.length;
    receipts[body['request_id'] as String] = copyJson(result);
    if (!answerStarted.isCompleted) answerStarted.complete();
    if (answerGate != null) await answerGate!.future;
    if (failAnswerAfterCommit) {
      failAnswerAfterCommit = false;
      return response({}, code: 500);
    }
    return response(result);
  }
}
