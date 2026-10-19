import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storylex/core/api.dart';
import 'package:storylex/core/session_store.dart';
import 'package:storylex/data/models.dart';
import 'package:storylex/state/app_controller.dart';

import 'support.dart';

void main() {
  test('Registration keeps book-choice requirement across refresh, and never stores password', () async {
    final backend = FakeBackend(), store = MemorySessions();
    final controller = backend.controller(store);
    await controller.bootstrap();
    await controller.authenticate(
      'new-user',
      'private-password',
      register: true,
    );
    expect(controller.session!.needsBook, true);
    expect(controller.catalog!.books.length, 2);
    expect(
      store.value!.toJson().toString(),
      isNot(contains('private-password')),
    );
    controller.dispose();
    final restored = backend.controller(store);
    await restored.bootstrap();
    expect(restored.session!.needsBook, true);
    expect(await restored.chooseBook('KaoYan_2'), true);
    expect(restored.home!.dashboard.bookId, 'KaoYan_2');
    expect(store.value!.needsBook, false);
    expect(restored.home!.stats.learned, 326);
    restored.dispose();
  });
  test('Switch failure retains current book; target save refreshes independent server counts', () async {
    final backend = FakeBackend(),
        store = MemorySessions(const Session('test-token', '测试读者'));
    final controller = backend.controller(store);
    await controller.bootstrap();
    backend.failSwitch = true;
    expect(await controller.chooseBook('KaoYan_2'), false);
    expect(controller.home!.dashboard.bookId, 'CET6luan_1');
    expect(await controller.updateTarget('new', 15), true);
    expect(controller.home!.dashboard.learn.target, 15);
    expect(controller.home!.dashboard.review.target, 10);
    expect(controller.home!.dashboard.review.available, 7);
    final count = backend.requests.length;
    expect(await controller.updateTarget('new', 201), false);
    expect(backend.requests.length, count);
    controller.dispose();
  });
  test('Offline restore preserves session for retry; 401 clears it', () async {
    final backend = FakeBackend()..offline = true;
    final store = MemorySessions(const Session('test-token', '测试读者'));
    final controller = backend.controller(store);
    await controller.bootstrap();
    expect(controller.session, isNotNull);
    expect(store.value, isNotNull);
    expect(controller.error, isNotNull);
    backend.offline = false;
    await controller.refreshHome();
    expect(controller.home, isNotNull);
    backend.expired = true;
    await controller.refreshHome();
    await Future<void>.delayed(Duration.zero);
    expect(controller.session, isNull);
    expect(store.value, isNull);
    expect(controller.home, isNull);
    controller.dispose();
  });
  test(
    'Late home response cannot put private data back after logout',
    () async {
      final backend = FakeBackend(),
          store = MemorySessions(const Session('test-token', '测试读者'));
      final controller = backend.controller(store);
      await controller.bootstrap();
      final delayed = Completer<HomeData>();
      final repository = _DelayedHomeRepository(
        controller.repository.api,
        delayed,
      );
      final late = AppController(repository, store)..session = store.value;
      final refresh = late.refreshHome();
      await late.logout();
      delayed.complete(controller.home!);
      await refresh;
      expect(late.home, isNull);
      expect(late.session, isNull);
      late.dispose();
      controller.dispose();
    },
  );
  test(
    'Session writes and logout clear execute in order even on slow storage',
    () async {
      final storage = _SlowSessions();
      // Use a single underlying storage with an intentionally delayed first write.
      final queue = SerialSessionStore(storage);
      final write = queue.write(const Session('test-token', 'reader'));
      final clear = queue.clear();
      await Future<void>.delayed(Duration.zero);
      storage.gate.complete();
      await write;
      await clear;
      expect(storage.value, isNull);
    },
  );
}

class _DelayedHomeRepository extends StoryLexRepository {
  _DelayedHomeRepository(super.api, this.pending);
  final Completer<HomeData> pending;
  @override
  Future<HomeData> home() => pending.future;
}

class _SlowSessions extends MemorySessions {
  final gate = Completer<void>();
  @override
  Future<void> write(Session session) async {
    await gate.future;
    value = session;
  }
}
