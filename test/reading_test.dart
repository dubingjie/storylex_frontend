import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:storylex/core/api.dart';
import 'package:storylex/core/story_repository.dart';
import 'package:storylex/data/models.dart';
import 'package:storylex/data/story_models.dart';
import 'package:storylex/state/reading_controller.dart';

import 'support.dart';
import 'story_support.dart';

void main() {
  test('Story text decodes entities, keeps word markers and rune offsets, excludes executable elements', () {
    final doc = StoryDocument(
      '雨 &amp; 😀<word id="41">wander</word>\n\n<script>secret()</script><p>下一页</p>',
    );
    expect(doc.paragraphs.first.runs.map((r) => r.text).join(), '雨 & 😀wander');
    expect(doc.paragraphs.first.runs.last.wordId, 41);
    expect(
      doc.paragraphs.map((p) => p.runs.map((r) => r.text).join()).join(),
      isNot(contains('secret')),
    );
    expect(doc.paragraphs.last.offset, 13);
  });
  test('Library sends encoded server filters and mutations use actual story and word contracts', () async {
    final calls = <String>[];
    final api = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((r) async {
        calls.add(r.url.path);
        if (r.url.path == '/api/stories/list') {
          expect(r.url.queryParameters['keyword'], '雨 后&书');
          expect(r.url.queryParameters['scope'], 'mine');
          expect(r.url.queryParameters['category'], 'favorites');
          expect(r.url.queryParameters['page'], '2');
          return response({
            'total': 8,
            'page': 2,
            'page_size': 6,
            'list': [storyJson(1)],
          });
        }
        final body = object(jsonDecode(r.body));
        if (r.url.path == '/api/words/favorite/toggle') {
          expect(body, {'word_id': 41, 'source_type': 'story'});
          return response({'is_favorited': true});
        }
        if (r.url.path == '/api/stories/complete') {
          expect(body, {'story_id': 1});
          return response({});
        }
        expect(body, {'is_favorited': true});
        return response({'is_favorited': true});
      }),
    );
    final repo = StoryLexRepository(api);
    final page = await repo.stories(
      scope: 'mine',
      category: 'favorites',
      keyword: '雨 后&书',
      page: 2,
    );
    expect(page.pages, 2);
    await repo.favoriteStory(1, true);
    await repo.favoriteReadingWord(41);
    await repo.completeReading(1);
    expect(calls.length, 4);
    api.close();
  });
  test('Reading position writes serialize with latest version; reaching 100 never completes a story', () async {
    final first = Completer<void>(), started = Completer<void>();
    final versions = <int>[], positions = <int>[];
    var serverVersion = 0, completed = 0;
    final api = ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient((r) async {
        if (r.url.path.contains('/detail/'))
          return response(detailJson(content: '一' * 200));
        if (r.url.path.endsWith('/complete')) {
          completed++;
          return response({});
        }
        if (r.method == 'PUT') {
          final j = object(jsonDecode(r.body));
          versions.add(number(j['version']));
          positions.add(number(j['position']));
          if (versions.length == 1) {
            started.complete();
            await first.future;
          }
          expect(j['version'], serverVersion);
          serverVersion++;
          return response({
            'progress': j['progress'],
            'position': j['position'],
            'version': serverVersion,
          });
        }
        return response({'progress': 0, 'position': 0, 'version': 0});
      }),
    );
    final c = ReadingController(StoryLexRepository(api), 1, () => true);
    await c.load();
    c.updatePosition(20, 10);
    final saving = c.flush();
    await started.future;
    c.updatePosition(200, 100);
    first.complete();
    expect(await saving, true);
    expect(versions, [0, 1]);
    expect(positions, [20, 200]);
    expect(c.saved!.version, 2);
    expect(completed, 0);
    expect(await c.complete(), true);
    expect(completed, 1);
    c.dispose();
    api.close();
  });
  test('Conflicting progress stays visible for recovery and stale account responses are discarded', () async {
    var current = true;
    final backend = StoryBackend(),
        api = ApiClient(
          client: MockClient(backend.handle),
          baseUrl: 'http://api.test',
        );
    final c = ReadingController(StoryLexRepository(api), 1, () => current);
    await c.load();
    backend.version = 5;
    c.updatePosition(4, 20);
    expect(await c.flush(), false);
    expect(c.conflict, true);
    expect(c.saveError, isNotNull);
    final count = backend.requests.length;
    await c.flush();
    expect(backend.requests.length, count);
    current = false;
    expect(await c.complete(), false);
    expect(backend.completionCalls, 0);
    c.dispose();
    api.close();
  });
  test('Fresh reading keeps the server version but starts at zero; continue reading restores saved position', () async {
    final backend = StoryBackend()
      ..version = 7
      ..position = 12
      ..percent = 80;
    final api = ApiClient(
      client: MockClient(backend.handle),
      baseUrl: 'http://api.test',
    );
    final c = ReadingController(StoryLexRepository(api), 1, () => true);
    await c.load(resume: false);
    expect(c.position, 0);
    expect(c.percent, 0);
    expect(c.saved!.version, 7);
    expect(c.dirty, false);
    await c.load();
    expect(c.position, 12);
    expect(c.percent, 80);
    expect(backend.requests.where((r) => r.method == 'PUT'), isEmpty);
    c.dispose();
    api.close();
  });
}
