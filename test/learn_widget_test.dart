import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:storylex/app.dart';
import 'package:storylex/core/api.dart';
import 'package:storylex/core/learning_store.dart';
import 'package:storylex/data/models.dart';
import 'package:storylex/state/app_controller.dart';
import 'package:storylex/ui/learn_screen.dart';

import 'support.dart';
import 'learn_support.dart';

void main() {
  testWidgets(
    'Study fits desktop and phones; refresh resumes and explicit return stays home',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [
        const Size(1440, 900),
        const Size(840, 650),
        const Size(390, 844),
        const Size(320, 650),
      ]) {
        tester.view.physicalSize = size;
        final backend = LearnBackend()..target = 3;
        final store = MemoryLearningStore();
        AppController makeApp() => AppController(
          StoryLexRepository(
            ApiClient(
              client: MockClient(backend.handle),
              baseUrl: 'http://api.test',
            ),
          ),
          MemorySessions(const Session('test-token', '测试读者')),
          learningStore: store,
        );
        var app = makeApp();
        await app.bootstrap();
        await tester.pumpWidget(StoryLexApp(controller: app));
        await tester.pumpAndSettle();
        final start = find.textContaining('开始学习').first;
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(find.byType(LearnScreen), findsOneWidget);
        expect(find.text('blind'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('熟'));
        await tester.tap(find.text('熟'));
        await tester.pumpAndSettle();
        expect(backend.masterWrites, 1);
        await tester.ensureVisible(find.text('下一词 →'));
        await tester.tap(find.text('下一词 →'));
        await tester.pumpAndSettle();
        expect(find.text('earnestly'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        app.dispose();
        app = makeApp();
        await app.bootstrap();
        await tester.pumpWidget(StoryLexApp(controller: app));
        await tester.pumpAndSettle();
        expect(find.byType(LearnScreen), findsOneWidget);
        expect(find.text('earnestly'), findsOneWidget);
        await tester.ensureVisible(find.text('返回'));
        await tester.tap(find.text('返回'));
        await tester.pumpAndSettle();
        expect(find.byType(LearnScreen), findsNothing);
        expect(store.value?['open'], false);
        await tester.pumpWidget(const SizedBox());
        app.dispose();
        app = makeApp();
        await app.bootstrap();
        await tester.pumpWidget(StoryLexApp(controller: app));
        await tester.pumpAndSettle();
        expect(find.byType(LearnScreen), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        app.dispose();
      }
    },
  );
}
