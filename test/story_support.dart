import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:storylex/data/models.dart';

import 'support.dart';

Json storyJson(int id, {bool favorite = false, bool completed = false}) => {
  'story_id': id,
  'title': id == 1
      ? '雨后的旧书店'
      : id == 2
      ? '湖畔的一天'
      : '晴天的来信$id',
  'source_type': id == 2 ? 'builtin' : 'imported',
  'embedded_word_count': 2,
  'word_count': 500,
  'is_favorited': favorite,
  'is_completed': completed,
};
Json detailJson({
  bool favorite = false,
  bool completed = false,
  String? content,
}) => {
  ...storyJson(1, favorite: favorite, completed: completed),
  'processed_content': content ?? '雨停了，她决定 <word id="41">wander</word> 一会儿。\n\n旧书店格外 <word id="42">quiet</word>，她打开一本书。',
  'embedded_words': [
    {
      'word_id': 41,
      'word': 'wander',
      'us_phone': 'wɑːndər',
      'uk_phone': 'wɒndə',
      'translations': [
        {'pos': 'v.', 'tranCn': '漫步'},
      ],
      'translation_book_title': '六级核心词汇',
      'is_favorited': false,
      'is_mastered': false,
    },
    {
      'word_id': 42,
      'word': 'quiet',
      'translations': [
        {'pos': 'adj.', 'tranCn': '安静的'},
      ],
      'is_favorited': false,
      'is_mastered': false,
    },
  ],
};

class StoryBackend extends FakeBackend {
  final favorites = <int>{};
  bool completed = false, wordFavorite = false, mastered = false;
  String? content;
  int version = 0, position = 0, completionCalls = 0, practiceSubmits = 0;
  double percent = 0;
  Json? submission;
  @override
  Future<http.Response> handle(http.Request r) async {
    if (!r.url.path.startsWith('/api/stories') &&
        ![
          '/api/words/favorite/toggle',
          '/api/words/master',
        ].contains(r.url.path))
      return super.handle(r);
    requests.add(r);
    if (expired) return response({}, code: 401, msg: 'Token已过期');
    final path = r.url.path;
    if (path == '/api/stories/list') {
      final q = r.url.queryParameters, page = int.parse(q['page']!);
      var rows = q['scope'] == 'recommended'
          ? [storyJson(2, favorite: favorites.contains(2))]
          : [
              for (final id in [1, 3, 4, 5, 6, 7, 8, 9])
                storyJson(
                  id,
                  favorite: favorites.contains(id),
                  completed: id == 1 && completed,
                ),
              if (favorites.contains(2)) storyJson(2, favorite: true),
            ];
      if (q['category'] == 'favorites')
        rows = rows.where((r) => r['is_favorited'] == true).toList();
      if (q['category'] == 'ai_generated') rows = [];
      if (q['keyword']?.isNotEmpty == true)
        rows = rows
            .where((r) => (r['title'] as String).contains(q['keyword']!))
            .toList();
      return response({
        'total': rows.length,
        'page': page,
        'page_size': 6,
        'list': rows.skip((page - 1) * 6).take(6).toList(),
      });
    }
    if (RegExp(r'^/api/stories/detail/\d+$').hasMatch(path)) {
      final j = detailJson(
        content: content,
        favorite: favorites.contains(1),
        completed: completed,
      );
      final id = int.parse(path.split('/').last);
      j['story_id'] = id;
      j['title'] = storyJson(id)['title'];
      final words = j['embedded_words'] as List;
      words[0]['is_favorited'] = wordFavorite;
      words[0]['is_mastered'] = mastered;
      return response(j);
    }
    if (RegExp(r'^/api/stories/\d+/progress$').hasMatch(path)) {
      if (r.method == 'PUT') {
        final j = object(jsonDecode(r.body));
        if (j['version'] != version)
          return response({}, code: 400, msg: '阅读进度已被其他请求更新，请重新获取最新version后提交');
        version++;
        position = number(j['position']);
        percent = (j['progress'] as num).toDouble();
      }
      return response({
        'story_id': 1,
        'progress': percent,
        'position': position,
        'version': version,
      });
    }
    if (path.endsWith('/favorite')) {
      final j = object(jsonDecode(r.body)), id = int.parse(path.split('/')[3]);
      if (j['is_favorited'] == true) {
        favorites.add(id);
      } else {
        favorites.remove(id);
      }
      return response({'story_id': id, 'is_favorited': favorites.contains(id)});
    }
    if (path == '/api/stories/complete') {
      completed = true;
      completionCalls++;
      return response({'story_id': 1, 'is_completed': true});
    }
    if (path == '/api/words/favorite/toggle') {
      wordFavorite = !wordFavorite;
      return response({'is_favorited': wordFavorite});
    }
    if (path == '/api/words/master') {
      mastered = true;
      return response({'word_id': 41, 'is_mastered': true});
    }
    if (path == '/api/stories/1/practice')
      return response({
        'session_id': 'reading-session',
        'story_id': 1,
        'total': 2,
        'skipped_word_ids': [],
        'questions': [
          for (final item in [(41, 'wander'), (42, 'quiet')])
            {
              'question_id': 'q${item.$1}',
              'word_id': item.$1,
              'word': item.$2,
              'options': [
                {'key': 'A', 'trans': 'v. 漫步'},
                {'key': 'B', 'trans': 'adj. 安静的'},
                {'key': 'C', 'trans': 'n. 一本书'},
                {'key': 'D', 'trans': 'v. 行动'},
              ],
            },
        ],
      });
    if (path == '/api/stories/1/practice/submit') {
      practiceSubmits++;
      submission = object(jsonDecode(r.body));
      return response({
        'score': 50,
        'correct_count': 1,
        'wrong_count': 1,
        'total': 2,
        'wrong_words_queued': 1,
        'results': [
          {
            'question_id': 'q41',
            'word_id': 41,
            'is_correct': true,
            'correct_key': 'A',
          },
          {
            'question_id': 'q42',
            'word_id': 42,
            'is_correct': false,
            'correct_key': 'B',
          },
        ],
      });
    }
    throw StateError('Unexpected story API: $path');
  }
}
