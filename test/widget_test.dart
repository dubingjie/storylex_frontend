import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storylex/app.dart';
import 'package:storylex/data/models.dart';

import 'support.dart';

void main() {
  testWidgets(
    'Registration validates confirmation before sending credentials',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FakeBackend();
      final controller = backend.controller(MemorySessions());
      await controller.bootstrap();
      await tester.pumpWidget(StoryLexApp(controller: controller));
      await tester.tap(find.text('注册'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('username')), 'reader');
      await tester.enterText(find.byKey(const Key('password')), '123456');
      await tester.enterText(
        find.byKey(const Key('confirm-password')),
        '654321',
      );
      await tester.ensureVisible(find.byKey(const Key('auth-submit')));
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('两次输入的密码不一致'), findsOneWidget);
      expect(backend.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'Home and book choice fit desktop and narrow phones; target edit uses server value',
    (tester) async {
      final backend = FakeBackend();
      final controller = backend.controller(
        MemorySessions(const Session('test-token', '测试读者')),
      );
      await controller.bootstrap();
      for (final size in [
        const Size(1440, 900),
        const Size(1440, 650),
        const Size(840, 600),
        const Size(390, 900),
        const Size(320, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(StoryLexApp(controller: controller));
        await tester.pumpAndSettle();
        expect(find.text('我的英语学习手帐'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.tap(find.text('修改目标').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '201');
      await tester.tap(find.text('保存目标'));
      await tester.pumpAndSettle();
      expect(find.text('请输入 1～200 之间的整数'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '15');
      await tester.tap(find.text('保存目标'));
      await tester.pumpAndSettle();
      expect(controller.home!.dashboard.learn.target, 15);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(OutlinedButton, '六级核心词汇'));
      await tester.pumpAndSettle();
      expect(find.text('选一本，开始慢慢积累。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        backend.requests.any((r) => r.url.path == '/api/words/target/update'),
        true,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'Expired session closes private dialogs and clears private screens',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FakeBackend();
      final controller = backend.controller(
        MemorySessions(const Session('test-token', '测试读者')),
      );
      await controller.bootstrap();
      await tester.pumpWidget(StoryLexApp(controller: controller));
      await tester.tap(find.text('修改目标').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      backend.expired = true;
      await controller.refreshHome();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
      expect(find.text('我的英语学习手帐'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
