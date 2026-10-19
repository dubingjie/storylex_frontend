import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:storylex/core/api.dart';
import 'package:storylex/core/learning_store.dart';
import 'package:storylex/state/learn_controller.dart';

import 'learn_support.dart';

Future<void> favoriteReady(LearnController c) async {
  for (var i = 0; i < 10 && c.favoriteBusy; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

LearnController buildController(
  LearnBackend backend,
  LearningStore store, {
  String owner = 'owner',
  bool Function()? current,
}) => LearnController(
  StoryLexRepository(
    ApiClient(client: MockClient(backend.handle), baseUrl: 'http://api.test'),
  ),
  store,
  owner,
  current ?? () => true,
);
void main() {
  test('Wrong answers use server retry versions and queue; mastered words pass without answering; small groups settle once', () async {
    final b = LearnBackend()..target = 3;
    final c = buildController(b, MemoryLearningStore());
    await c.load();
    await favoriteReady(c);
    expect(c.group!.total, 2);
    await c.answer('B');
    expect(c.feedback!.kind, 'wrong');
    expect(c.current!.questionId, 'q1-v1');
    expect(c.feedback!.word.questionId, 'q1-v0');
    expect(c.group!.passedCount, 0);
    await c.advance();
    await favoriteReady(c);
    expect(c.current!.id, 2);
    await c.master();
    expect(c.feedback!.kind, 'mastered');
    expect(c.group!.passedCount, 1);
    expect(b.answerWrites, 1);
    await c.advance();
    await favoriteReady(c);
    expect(c.current!.id, 1);
    expect(
      c.current!.options.firstWhere((o) => o['key'] == 'C')['trans'],
      'adj. 失明的',
    );
    await c.answer('C');
    expect(c.group!.passedCount, 2);
    await c.advance();
    expect(c.summary!.words.length, 2);
    expect(b.settlements, 1);
    await c.complete();
    expect(b.settlements, 1);
    await c.nextGroup();
    await favoriteReady(c);
    expect(c.group!.total, 1);
    expect(c.current!.id, 3);
    await c.master();
    await c.advance();
    expect(c.summary!.words.length, 1);
    expect(b.settledWords, 3);
    await c.nextGroup();
    expect(c.group!.total, 0);
    expect(b.settlements, 2);
    for (final body in b.answerBodies) {
      expect(body.containsKey('options'), false);
      expect(body.containsKey('is_correct'), false);
      expect(body['group_id'], 'group-1');
    }
    c.dispose();
    c.repository.api.close();
  });
  test('An unconfirmed committed answer survives refresh with the identical request and counts a mistake once', () async {
    final b = LearnBackend()
      ..target = 1
      ..failAnswerAfterCommit = true;
    final store = SerialLearningStore(MemoryLearningStore()),
        c = buildController(b, store);
    await c.load();
    await favoriteReady(c);
    await c.answer('B');
    expect(c.pending, isNotNull);
    expect(b.mistakes, 1);
    final id = c.pending!.body['request_id'];
    c.dispose();
    final restored = buildController(b, store);
    await restored.load();
    await favoriteReady(restored);
    expect(restored.pending, isNull);
    expect(restored.feedback!.kind, 'wrong');
    expect(restored.current!.questionId, 'q1-v1');
    expect(b.mistakes, 1);
    expect(b.answerBodies.map((j) => j['request_id']).toSet(), {id});
    expect(b.answerWrites, 1);
    restored.dispose();
    c.repository.api.close();
    restored.repository.api.close();
  });
  test('A committed settlement is recovered without double counting; wrong-owner checkpoints never replay', () async {
    final b = LearnBackend()
      ..target = 1
      ..failCompleteAfterCommit = true;
    final store = SerialLearningStore(MemoryLearningStore()),
        c = buildController(b, store);
    await c.load();
    await favoriteReady(c);
    await c.master();
    await c.advance();
    expect(c.pending!.kind, 'complete');
    expect(b.settlements, 1);
    c.dispose();
    final restored = buildController(b, store);
    await restored.load();
    expect(restored.summary!.words.length, 1);
    expect(b.settlements, 1);
    restored.dispose();
    await store.write({
      'owner': 'someone-else',
      'open': true,
      'pending': {
        'kind': 'complete',
        'body': {'group_id': 'foreign'},
      },
    });
    final other = buildController(b, store);
    await other.load();
    expect(other.pending, isNull);
    expect(other.error, isNull);
    expect(b.settlements, 1);
    other.dispose();
    c.repository.api.close();
    restored.repository.api.close();
    other.repository.api.close();
  });
  test('Looking at the answer fails the word, a crossed-day group reloads, and favorite state comes from its own endpoint', () async {
    final b = LearnBackend()..target = 1;
    final c = buildController(b, MemoryLearningStore());
    await c.load();
    await favoriteReady(c);
    await c.favoriteAction();
    expect(b.favorites, {1});
    expect(b.favoriteWrites, 1);
    await c.answer(null);
    expect(c.feedback!.kind, 'wrong');
    expect(c.group!.passedCount, 0);
    expect(b.answerBodies.last['selected_key'], isNull);
    expect(b.answerBodies.last['is_show_answer'], true);
    await c.load(discardPending: true);
    await favoriteReady(c);
    expect(c.favorite, true);
    expect(c.current!.favorite, false);
    b.stale = true;
    await c.answer('C');
    expect(c.needsReload, true);
    expect(c.pending, isNull);
    await c.load(discardPending: true);
    await favoriteReady(c);
    expect(c.group!.id, 'group-2');
    expect(c.needsReload, false);
    c.dispose();
    c.repository.api.close();
  });
  test(
    'A late response after logout cannot recreate cleared checkpoint data',
    () async {
      final b = LearnBackend()
        ..target = 1
        ..answerGate = Completer<void>();
      final store = SerialLearningStore(MemoryLearningStore());
      var current = true;
      final c = buildController(b, store, current: () => current);
      await c.load();
      await favoriteReady(c);
      final answer = c.answer('A');
      await b.answerStarted.future;
      expect((await store.read())!['pending'], isNotNull);
      current = false;
      await store.clear();
      b.answerGate!.complete();
      await answer;
      expect(await store.read(), isNull);
      c.dispose();
      c.repository.api.close();
    },
  );
}
