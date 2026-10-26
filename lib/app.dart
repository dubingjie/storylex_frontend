import 'dart:async';

import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'ui/app_shell.dart';
import 'ui/auth_screen.dart';
import 'ui/books_screen.dart';
import 'ui/journal.dart';

class StoryLexApp extends StatefulWidget {
  const StoryLexApp({super.key, required this.controller});
  final AppController controller;
  @override
  State<StoryLexApp> createState() => _StoryLexAppState();
}

class _StoryLexAppState extends State<StoryLexApp> {
  final _navigator = GlobalKey<NavigatorState>();
  String? _lastToken;
  bool _bootSlow = false;
  Timer? _bootTimer;

  @override
  void initState() {
    super.initState();
    _lastToken = widget.controller.session?.token;
    widget.controller.addListener(_changed);
    _trackBooting();
  }

  // 启动恢复会话超过 6 秒时提示后端可能在唤醒，避免用户以为卡死。
  void _trackBooting() {
    if (widget.controller.booting) {
      _bootTimer ??= Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _bootSlow = true);
      });
    } else {
      _bootTimer?.cancel();
      _bootTimer = null;
      if (_bootSlow) _bootSlow = false;
    }
  }

  @override
  void didUpdateWidget(StoryLexApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _lastToken = widget.controller.session?.token;
    }
  }

  void _changed() {
    _trackBooting();
    final token = widget.controller.session?.token;
    if (token != _lastToken) {
      _lastToken = token;
      // Close private dialogs without replacing the app's render/navigation root.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigator.currentState?.popUntil((route) => route.isFirst);
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _bootTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final Widget home;
    if (controller.booting) {
      home = Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(height: 18),
              const Text('正在打开你的手帐…'),
              if (_bootSlow) ...[
                const SizedBox(height: 10),
                const Text(
                  '服务正在唤醒，可能需要半分钟左右，请稍候…',
                  style: TextStyle(color: Journal.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (controller.session == null) {
      home = AuthScreen(controller: controller);
    } else if (controller.session!.needsBook) {
      home = Scaffold(
        appBar: AppBar(
          title: const Text('StoryLex'),
          backgroundColor: Journal.cream,
        ),
        body: BooksScreen(controller: controller, onDone: () {}),
      );
    } else {
      home = AppShell(controller: controller);
    }
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'StoryLex · 英语学习手帐',
      debugShowCheckedModeBanner: false,
      theme: Journal.theme,
      home: home,
    );
  }
}
