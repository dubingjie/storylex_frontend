import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storylex/app.dart';
import 'package:storylex/data/models.dart';
import 'package:storylex/ui/reading_screen.dart';

import 'support.dart';
import 'story_support.dart';

void main() {
  testWidgets(
    'Library and reader fit desktop, tablet and phones; reading does not auto-complete',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [1440.0, 840.0, 390.0, 320.0]) {
        tester.view.physicalSize = Size(width, 950);
        final backend = StoryBackend();
        final app = backend.controller(
          MemorySessions(const Session('test-token', '测试读者')),
        );
        await app.bootstrap();
        await tester.pumpWidget(StoryLexApp(controller: app));
        await tester.pumpAndSettle();
        await tester.tap(find.text('文章库').first);
        await tester.pumpAndSettle();
        expect(find.text('我的书库'), findsOneWidget);
        expect(find.text('系统推荐文章'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.widgetWithText(TextButton, '开始阅读  →').first,
        );
        await tester.tap(find.widgetWithText(TextButton, '开始阅读  →').first);
        await tester.pumpAndSettle();
        expect(find.text('返回文章库'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(backend.completionCalls, 0);
        await tester.ensureVisible(find.text('完成阅读'));
        await tester.pumpAndSettle();
        expect(backend.completionCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        app.dispose();
      }
    },
  );
  testWidgets(
    'Back preserves library page; vocabulary and manual completion use server state; practice submits choices only',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = StoryBackend();
      final controller = backend.controller(
        MemorySessions(const Session('test-token', '测试读者')),
      );
      await controller.bootstrap();
      await tester.pumpWidget(StoryLexApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('文章库').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, '下一页'));
      await tester.tap(find.widgetWithText(TextButton, '下一页'));
      await tester.pumpAndSettle();
      expect(find.text('晴天的来信8'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextButton, '开始阅读  →').first,
      );
      await tester.tap(find.widgetWithText(TextButton, '开始阅读  →').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回文章库'));
      await tester.pumpAndSettle();
      expect(find.text('晴天的来信8'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(TextButton, '上一页'));
      await tester.tap(find.widgetWithText(TextButton, '上一页'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(TextButton, '开始阅读  →').first,
      );
      await tester.tap(find.widgetWithText(TextButton, '开始阅读  →').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('wander').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('收藏单词'));
      await tester.pumpAndSettle();
      expect(backend.wordFavorite, true);
      await tester.tap(find.text('标记已掌握'));
      await tester.pumpAndSettle();
      expect(backend.mastered, true);
      await tester.tap(find.byTooltip('关闭单词释义'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('完成阅读'));
      await tester.pumpAndSettle();
      expect(backend.completionCalls, 0);
      await tester.tap(find.text('完成阅读'));
      await tester.pumpAndSettle();
      expect(backend.completionCalls, 1);
      await tester.ensureVisible(find.text('去练习 →'));
      await tester.tap(find.text('去练习 →'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A  v. 漫步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一题 →'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('暂时不会'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('已选择：暂时不会（再次点击取消）'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交练习'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('暂时不会'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('提交练习'));
      await tester.pumpAndSettle();
      expect(find.text('50 分'), findsOneWidget);
      expect(backend.practiceSubmits, 1);
      final answers = backend.submission!['answers'] as List;
      expect(answers.every((a) => !(a as Map).containsKey('is_correct')), true);
      expect(answers.last['is_show_answer'], true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'Library reopening starts at top; vocabulary is large on desktop and a bottom sheet on phones',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 950);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = StoryBackend()
        ..position = 200
        ..percent = 75
        ..version = 4;
      backend.content = List.filled(
        30,
        '她走进了 <word id="41">wander</word> 的故事，书页在微风中缓缓翻动。',
      ).join('\n\n');
      final app = backend.controller(
        MemorySessions(const Session('test-token', '测试读者')),
      );
      await app.bootstrap();
      await tester.pumpWidget(StoryLexApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('文章库').first);
      await tester.pumpAndSettle();
      expect(find.text('搜索同时适用于我的书库与系统推荐。'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, '开始阅读  →').first);
      await tester.pumpAndSettle();
      final scrollFinder = find
          .descendant(
            of: find.byType(ReadingScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(tester.state<ScrollableState>(scrollFinder).position.pixels, 0);
      await tester.tap(find.text('词表 2'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Dialog)).width, greaterThan(700));
      await tester.tap(find.byTooltip('关闭词表'));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(scrollFinder).position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.text('首页').first);
      await tester.pumpAndSettle();
      expect(backend.percent, 100);
      await tester.tap(find.text('文章库').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '开始阅读  →').first);
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollFinder).position.pixels, 0);
      expect(find.text('阅读进度 0%'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.text('词表 2'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getSize(find.byType(BottomSheet)).height, greaterThan(500));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭词表'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );
}
