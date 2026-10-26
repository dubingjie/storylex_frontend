import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'journal.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _register = false, _showPassword = false;
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_busyChanged);
  }

  // 请求超过 6 秒还没回来，多半是后端在冷启动唤醒，给用户一句说明，
  // 免得对着转圈以为卡死。
  void _busyChanged() {
    if (widget.controller.busy) {
      _slowTimer ??= Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _slow = true);
      });
    } else {
      _slowTimer?.cancel();
      _slowTimer = null;
      if (_slow && mounted) setState(() => _slow = false);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_busyChanged);
    _slowTimer?.cancel();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final password = _password.text;
    await widget.controller.authenticate(
      _name.text,
      password,
      register: _register,
    );
    if (mounted && widget.controller.session != null) {
      _password.clear();
      _confirm.clear();
    }
  }

  void _mode(bool value) {
    if (widget.controller.busy) return;
    setState(() {
      _register = value;
      _confirm.clear();
      _form.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            width: 1140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'StoryLex',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: wide ? 72 : 28),
                    Text(
                      '从一个单词，\n读进一个故事。',
                      style: Journal.hand(wide ? 40 : 29),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '把每天的一点进步，\n写进自己的英语学习手帐。',
                      style: TextStyle(color: Journal.muted, height: 2),
                    ),
                    if (wide)
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Image.asset(
                          'assets/images/journal-elephant.png',
                          width: 280,
                          height: 220,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                  ],
                );
                final card = Paper(
                  padding: const EdgeInsets.all(28),
                  child: AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              _tab('登录', false),
                              const SizedBox(width: 16),
                              _tab('注册', true),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (controller.notice != null)
                            ErrorNote(controller.notice!),
                          if (controller.error != null)
                            ErrorNote(controller.error!),
                          TextFormField(
                            key: const Key('username'),
                            controller: _name,
                            enabled: !controller.busy,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            maxLength: 50,
                            decoration: const InputDecoration(
                              labelText: '用户名',
                              counterText: '',
                            ),
                            validator: (v) {
                              final name = (v ?? '').trim();
                              if (name.isEmpty) return '请输入用户名';
                              if (_register &&
                                  (name.runes.length < 3 ||
                                      name.runes.length > 50)) {
                                return '用户名需要 3～50 个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            key: const Key('password'),
                            controller: _password,
                            enabled: !controller.busy,
                            obscureText: !_showPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: _register
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_register && !controller.busy) _submit();
                            },
                            decoration: InputDecoration(
                              labelText: '密码',
                              suffixIcon: IconButton(
                                tooltip: _showPassword ? '隐藏密码' : '显示密码',
                                onPressed: () => setState(
                                  () => _showPassword = !_showPassword,
                                ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) return '请输入密码';
                              if (_register && v!.runes.length < 6) {
                                return '密码至少 6 个字符';
                              }
                              return null;
                            },
                          ),
                          if (_register) ...[
                            const SizedBox(height: 20),
                            TextFormField(
                              key: const Key('confirm-password'),
                              controller: _confirm,
                              enabled: !controller.busy,
                              obscureText: !_showPassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: '确认密码',
                              ),
                              onFieldSubmitted: (_) {
                                if (!controller.busy) _submit();
                              },
                              validator: (v) =>
                                  v != _password.text ? '两次输入的密码不一致' : null,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '用户名 3～50 个字符，密码至少 6 个字符。',
                              style: TextStyle(
                                fontSize: 11,
                                color: Journal.muted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          WaitButton(
                            key: const Key('auth-submit'),
                            text: _register ? '注册，开启我的手帐' : '登录我的手帐',
                            busy: controller.busy,
                            onPressed: () {
                              _submit();
                            },
                          ),
                          if (controller.busy && _slow) ...[
                            const SizedBox(height: 14),
                            const Text(
                              '服务正在唤醒，可能需要半分钟左右，请稍候…',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Journal.muted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            _register ? '注册后，选一本想学的词书。' : '欢迎回来，今天也慢慢积累。',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Journal.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: 70),
                        SizedBox(width: 420, child: card),
                      ],
                    ),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading,
                        const SizedBox(height: 34),
                        card,
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(String title, bool register) => Semantics(
    selected: _register == register,
    button: true,
    child: InkWell(
      onTap: widget.controller.busy ? null : () => _mode(register),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _register == register
                  ? const Color(0xFFB8C99B)
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 21,
            color: _register == register ? Journal.ink : Journal.muted,
          ),
        ),
      ),
    ),
  );
}
