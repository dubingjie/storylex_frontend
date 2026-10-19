import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_controller.dart';
import '../state/learn_controller.dart';
import '../data/learn_models.dart';
import 'journal.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({
    super.key,
    required this.controller,
    required this.onBack,
    this.reviewMode = false,
  });
  final AppController controller;
  final VoidCallback onBack;
  final bool reviewMode;
  @override
  State<LearnScreen> createState() => LearnScreenState();
}

class LearnScreenState extends State<LearnScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _feedbackKey = GlobalKey();
  late final _token = widget.controller.session?.token;
  late final _study = LearnController(
    widget.controller.repository,
    widget.controller.learningStore,
    '${widget.controller.learningOwner}${widget.reviewMode ? ':review' : ''}',
    () => widget.controller.session?.token == _token,
    reviewMode: widget.reviewMode,
  );
  Object? _lastFeedback, _lastSummary;
  int? _lastWord;
  bool _hideMeanings = false;
  @override
  void initState() {
    super.initState();
    _study.addListener(_changed);
    _study.load();
  }

  void _changed() {
    if (!mounted) return;
    final newFeedback =
        _study.feedback != null && _study.feedback != _lastFeedback;
    final newWord =
        _study.feedback == null &&
        (_study.current?.id != _lastWord || _lastFeedback != null);
    _lastFeedback = _study.feedback;
    _lastWord = _study.current?.id;
    if (_study.summary != null && _study.summary != _lastSummary) {
      _lastSummary = _study.summary;
      widget.controller.refreshHome();
    }
    setState(() {});
    if (newFeedback || newWord)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        if (newFeedback && _feedbackKey.currentContext != null) {
          Scrollable.ensureVisible(
            _feedbackKey.currentContext!,
            alignment: 1,
            duration: Duration.zero,
          );
        } else if (newWord) {
          _scroll.jumpTo(0);
        }
      });
  }

  Future<void> pauseBeforeLeaving() => _study.pauseScreen();
  @override
  void dispose() {
    _study.removeListener(_changed);
    _study.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = JournalLayout.of(context).mobile;
    return SingleChildScrollView(
      controller: _scroll,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 28,
              mobile ? 10 : 24,
              mobile ? 16 : 28,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, size: 17),
                      label: const Text('返回'),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.reviewMode ? '今日复习' : '单词学习',
                        style: Journal.hand(mobile ? 19 : 23)
                            .copyWith(color: const Color(0xFF7B654A)),
                      ),
                    ),
                    SizedBox(
                      width: mobile ? 98 : 142,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '本组进度',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Journal.muted,
                                ),
                              ),
                              Text(
                                '${widget.reviewMode ? (_study.summary?.completedCount ?? _study.group?.passedCount ?? 0) : (_study.summary?.words.length ?? _study.group?.passedCount ?? 0)} / ${widget.reviewMode ? (_study.summary?.totalCount ?? _study.group?.total ?? 0) : (_study.summary?.words.length ?? _study.group?.total ?? 0)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Journal.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          LinearProgressIndicator(
                            minHeight: 5,
                            value: _study.summary != null
                                ? 1
                                : (_study.group?.total ?? 0) > 0
                                ? _study.group!.passedCount /
                                      _study.group!.total
                                : 0,
                            color: const Color(0xFFB7C99B),
                            backgroundColor: const Color(0xFFE8E7D5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: mobile ? 16 : 22),
                if (_study.notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      _study.notice!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Journal.muted,
                      ),
                    ),
                  ),
                if (_study.error != null) ...[
                  ErrorNote(_study.error!),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (_study.pending != null)
                        WaitButton(
                          text: '重试本次提交',
                          busy: _study.busy,
                          onPressed: _study.retryPending,
                        ),
                      OutlinedButton(
                        onPressed: _study.busy || _study.loading
                            ? null
                            : () => _study.load(discardPending: true),
                        child: const Text('重新读取题组'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
                if (_study.loading)
                  const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_study.summary != null)
                  _summary()
                else if (_study.group?.total == 0)
                  _empty()
                else if (_study.displayWord != null)
                  _question(mobile)
                else if (_study.allPassed)
                  Paper(
                    child: Column(
                      children: [
                        Text('这一组，全部通过了。', style: Journal.hand(27)),
                        const SizedBox(height: 15),
                        WaitButton(
                          text: '结算本组并查看小结',
                          busy: _study.busy,
                          onPressed: _study.locked ? null : _study.complete,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _question(bool mobile) {
    final word = _study.displayWord!, feedback = _study.feedback;
    final options = feedback?.kind == 'mastered'
        ? <Json>[]
        : feedback == null
        ? word.options
        : word.options
              .where(
                (o) =>
                    o['key'] == feedback.correctKey ||
                    o['key'] == feedback.selectedKey,
              )
              .toList();
    return Paper(
      padding: EdgeInsets.all(mobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '本组 ${_study.group!.total} 词 · ${widget.reviewMode ? '复习' : '新学'}',
                  style: TextStyle(
                    fontSize: mobile ? 9 : 11,
                    color: Journal.muted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _study.loading || _study.busy || _study.favoriteBusy
                    ? null
                    : _study.favoriteAction,
                icon: Icon(
                  _study.favorite == true
                      ? Icons.favorite_rounded
                      : _study.favorite == null
                      ? Icons.sync
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: const Color(0xFFBB9299),
                ),
                label: Text(
                  _study.favorite == null
                      ? '核对收藏'
                      : _study.favorite == true
                      ? '已收藏'
                      : '收藏',
                  style: TextStyle(fontSize: mobile ? 10 : 12),
                ),
              ),
              const SizedBox(width: 5),
              if (!widget.reviewMode)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: _study.locked || _study.current?.passed == true
                      ? null
                      : _study.master,
                  child: Text(_study.current?.mastered == true ? '已掌握' : '熟'),
                ),
            ],
          ),
          if (_study.favoriteError != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                _study.favoriteError!,
                style: const TextStyle(fontSize: 11, color: Journal.muted),
              ),
            ),
          SizedBox(height: mobile ? 13 : 22),
          Text(
            word.word,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JournalSans',
              fontFamilyFallback: const ['JournalSansFull'],
              fontSize: mobile ? 36 : 46,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF796347),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 5,
            children: [
              if (word.uk.isNotEmpty)
                Text(
                  '英 /${word.uk}/',
                  style: const TextStyle(
                    fontFamily: 'JournalPhonetic',
                    fontFamilyFallback: ['JournalSansFull'],
                    fontSize: 13,
                    color: Journal.muted,
                  ),
                ),
              if (word.us.isNotEmpty)
                Text(
                  '美 /${word.us}/',
                  style: const TextStyle(
                    fontFamily: 'JournalPhonetic',
                    fontFamilyFallback: ['JournalSansFull'],
                    fontSize: 13,
                    color: Journal.muted,
                  ),
                ),
            ],
          ),
          SizedBox(height: mobile ? 20 : 27),
          if (options.isNotEmpty)
            Text(
              feedback == null ? '选出这个单词对应的中文释义' : '本题作答',
              style: const TextStyle(fontSize: 12, color: Journal.muted),
            ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final columns = feedback == null && box.maxWidth >= 580 ? 2 : 1;
              return Wrap(
                spacing: 14,
                runSpacing: mobile ? 9 : 14,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: (box.maxWidth - 14 * (columns - 1)) / columns,
                      child: _option(option, feedback != null, mobile),
                    ),
                ],
              );
            },
          ),
          if (feedback == null) ...[
            SizedBox(height: mobile ? 10 : 16),
            TextButton(
              onPressed: _study.locked ? null : () => _study.answer(null),
              child: Text(widget.reviewMode ? '想不起来，查看答案' : '暂时想不起来，看答案'),
            ),
            if (_study.busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 19),
            _feedback(),
          ],
        ],
      ),
    );
  }

  Widget _option(Json option, bool answered, bool mobile) {
    final feedback = _study.feedback, key = option['key'] as String;
    final correct = answered && key == feedback?.correctKey;
    final wrong =
        answered && key == feedback?.selectedKey && key != feedback?.correctKey;
    final color = correct
        ? const Color(0xFFEAF1DF)
        : wrong
        ? const Color(0xFFF5E7E1)
        : Journal.paper;
    final border = correct
        ? const Color(0xFFBED0A4)
        : wrong
        ? const Color(0xFFE2BEB5)
        : Journal.line;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(44, mobile ? 48 : 68),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 12 : 17,
          vertical: mobile ? 10 : 16,
        ),
        backgroundColor: color,
        disabledBackgroundColor: color,
        foregroundColor: Journal.ink,
        disabledForegroundColor: Journal.ink,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      onPressed: answered || _study.locked ? null : () => _study.answer(key),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: correct
                  ? const Color(0xFFD8E5C5)
                  : const Color(0xFFF7F0DC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(key, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              option['trans'] as String,
              style: TextStyle(fontSize: mobile ? 13 : 14, height: 1.7),
            ),
          ),
          if (correct || wrong) ...[
            const SizedBox(width: 7),
            Icon(
              correct ? Icons.check : Icons.close,
              size: 18,
              color: correct ? Journal.green : const Color(0xFFAF7468),
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedback() {
    final f = _study.feedback!,
        wrong = f.kind == 'wrong',
        mastered = f.kind == 'mastered';
    final detail = f.detail;
    String? optionText(String? key) {
      if (key == null) return null;
      for (final option in f.word.options) {
        if (option['key'] == key) return option['trans'] as String?;
      }
      return null;
    }

    final correctText = optionText(f.correctKey);
    final selectedText = optionText(f.selectedKey);
    final checkedAnswer = widget.reviewMode && wrong && f.selectedKey == null;
    final translation = detail == null
        ? ''
        : learnTranslation(detail['translations']);
    final sentences = detail?['sentences'] is List
        ? (detail!['sentences'] as List).whereType<Map>().take(2).toList()
        : <Map>[];
    final phrases = detail?['phrases'] is List
        ? (detail!['phrases'] as List).whereType<Map>().take(4).toList()
        : <Map>[];
    var memory = detail?['rem_method'];
    if (memory is String && memory.trim().startsWith('{')) {
      try {
        memory = jsonDecode(memory);
      } catch (_) {
        memory = null;
      }
    }
    if (memory is Map) memory = memory['val'];
    return Container(
      key: _feedbackKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: wrong ? const Color(0xFFF8ECE6) : const Color(0xFFF0F4E8),
        border: Border.all(
          color: wrong ? const Color(0xFFE9D3C7) : const Color(0xFFDCE5CE),
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.reviewMode
                ? (wrong ? (checkedAnswer ? '你查看了答案' : '这题答错了') : '回答正确！')
                : (mastered
                      ? '这个单词，你已经掌握了。'
                      : wrong
                      ? '再看一遍，下一次会记得。'
                      : '选对了，记住这一个。'),
            style: Journal.hand(21).copyWith(
              color: widget.reviewMode && wrong
                  ? const Color(0xFFA76559)
                  : Journal.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reviewMode
                ? (wrong
                      ? '${checkedAnswer ? '正确答案' : '你的答案'}：${checkedAnswer ? (correctText ?? '见下方释义') : (selectedText ?? '未选择')}${!checkedAnswer && correctText != null ? '\n正确答案：$correctText' : ''}\n本次复习已记录，之后会再安排复习。'
                      : '本次复习已记录。')
                : (mastered
                      ? '已直接通过本词，不再强制作答。'
                      : wrong
                      ? '本词暂未通过，会在本组稍后重新出现。'
                      : '本词已通过。'),
            style: const TextStyle(
              fontSize: 13,
              height: 1.8,
              color: Journal.muted,
            ),
          ),
          if (translation.isNotEmpty) ...[
            const SizedBox(height: 17),
            Text(
              translation,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
          ],
          for (final sentence in sentences) ...[
            if ((sentence['sContent'] ?? sentence['sentence']) is String)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Text(
                  (sentence['sContent'] ?? sentence['sentence']) as String,
                  style: const TextStyle(fontSize: 14, height: 1.9),
                ),
              ),
            if ((sentence['sCn'] ?? sentence['translation']) is String)
              Text(
                (sentence['sCn'] ?? sentence['translation']) as String,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: Journal.muted,
                ),
              ),
          ],
          for (final phrase in phrases)
            if (phrase['pContent'] is String)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${phrase['pContent']}  ${phrase['pCn'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.8,
                    color: Journal.muted,
                  ),
                ),
              ),
          if (memory is String && memory.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                memory,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: Journal.muted,
                ),
              ),
            ),
          const SizedBox(height: 19),
          Align(
            alignment: Alignment.centerRight,
            child: WaitButton(
              text: _study.allPassed
                  ? (widget.reviewMode ? '查看本轮小结' : '结算并查看小结')
                  : '下一词 →',
              busy: _study.busy,
              onPressed: _study.locked ? null : _study.advance,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final words = _study.summary!.words;
    return Paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 42,
            color: Journal.green,
          ),
          const SizedBox(height: 15),
          Text(
            widget.reviewMode ? '这一轮，复习好了。' : '这一组，记住了。',
            textAlign: TextAlign.center,
            style: Journal.hand(30),
          ),
          const SizedBox(height: 12),
          Text(
            widget.reviewMode
                ? '本轮复习 ${_study.summary!.completedCount} / ${_study.summary!.totalCount} 词'
                : '本组 ${words.length} 词已结算',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Journal.muted),
          ),
          if (widget.reviewMode && words.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                _summaryStat(
                  '${words.where((w) => w['is_correct'] == true).length}',
                  '答对',
                ),
                _summaryStat(
                  '${words.where((w) => w['is_correct'] != true && w['is_skipped'] != true).length}',
                  '答错/看答案',
                ),
                _summaryStat(
                  '${words.where((w) => w['is_skipped'] == true).length}',
                  '跳过',
                ),
              ],
            ),
          ],
          TextButton(
            onPressed: () => setState(() => _hideMeanings = !_hideMeanings),
            child: Text(_hideMeanings ? '显示释义' : '隐藏释义'),
          ),
          const SizedBox(height: 12),
          if (widget.reviewMode && words.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '答题结果已记录到今日复习统计。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Journal.muted),
              ),
            ),
          for (final word in words)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word['word'] as String,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!_hideMeanings) ...[
                          const SizedBox(height: 6),
                          Text(
                            (word['trans'] as String?) ?? '释义待补充',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Journal.muted,
                              height: 1.8,
                            ),
                          ),
                        ],
                        if (widget.reviewMode &&
                            word['is_correct'] != true &&
                            word['is_skipped'] != true) ...[
                          const SizedBox(height: 5),
                          Text(
                            '你的答案：${word['selected_text'] ?? '查看答案'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA76559),
                            ),
                          ),
                          Text(
                            '正确答案：${word['correct_text'] ?? word['trans'] ?? '释义待补充'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Journal.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    word['performance'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          widget.reviewMode &&
                              word['is_correct'] != true &&
                              word['is_skipped'] != true
                          ? const Color(0xFFA76559)
                          : Journal.green,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: widget.onBack,
                child: Text(widget.reviewMode ? '返回复习' : '返回首页'),
              ),
              WaitButton(
                text: widget.reviewMode ? '刷新复习队列' : '下一组 →',
                busy: _study.loading,
                onPressed: _study.locked ? null : _study.nextGroup,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: Journal.hand(24).copyWith(color: Journal.green)),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Journal.muted),
        ),
      ],
    ),
  );

  Widget _empty() => Paper(
    child: Column(
      children: [
        const Icon(Icons.auto_stories_outlined, size: 40, color: Journal.green),
        const SizedBox(height: 18),
        Text(
          widget.reviewMode
              ? (widget.controller.home?.dashboard.review.completed == true
                    ? '今日复习目标已完成。'
                    : '当前没有到期待复习的单词。')
              : (widget.controller.home?.dashboard.learn.completed == true
                    ? '今日新学目标已完成。'
                    : '当前没有可新学的单词。'),
          textAlign: TextAlign.center,
          style: Journal.hand(26),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: widget.onBack, child: const Text('回到首页')),
      ],
    ),
  );
}
