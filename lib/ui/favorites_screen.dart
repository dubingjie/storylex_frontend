import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/favorite_repository.dart';
import '../data/favorite_models.dart';
import '../data/models.dart';
import '../state/app_controller.dart';
import 'journal.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _search = TextEditingController();
  final _selected = <int>{};
  final _answers = <String, String?>{};
  final _shownAnswers = <String>{};
  Timer? _debounce;
  FavoritePageData? _data;
  FavoritePracticeSession? _practice;
  Json? _practiceResult;
  Json? _pendingAnswer;
  final _feedbackById = <String, Json>{};
  bool _showingSummary = false;
  String? _pendingCreateId;
  List<int>? _pendingCreateWords;
  String? _error;
  int _page = 1, _questionIndex = 0, _generation = 0;
  bool _loading = true, _busy = false, _hideMeanings = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _page = page;
    });
    try {
      final value = await widget.controller.repository.favorites(
        keyword: _search.text.trim(),
        page: _page,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = value;
        _loading = false;
        final currentIds = value.words.map((word) => word.id).toSet();
        _selected.removeWhere(
          (id) => !currentIds.contains(id) && value.total == 0,
        );
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = _message(e);
      });
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(page: 1));
  }

  List<FavoriteWord> get _visible => _data?.words ?? const [];
  int get _selectedOnPage =>
      _visible.where((word) => _selected.contains(word.id)).length;
  bool get _allVisibleSelected =>
      _visible.isNotEmpty && _selectedOnPage == _visible.length;

  void _toggleVisible(bool value) {
    setState(() {
      for (final word in _visible) {
        if (value) {
          _selected.add(word.id);
        } else {
          _selected.remove(word.id);
        }
      }
      _pendingCreateId = null;
      _pendingCreateWords = null;
    });
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty || _busy) return;
    final ids = _selected.toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Journal.paper,
        title: const Text('取消收藏这些单词？'),
        content: Text('将从收藏夹移除 ${ids.length} 个单词。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (var start = 0; start < ids.length; start += 200) {
        final end = (start + 200).clamp(0, ids.length);
        await widget.controller.repository.removeFavorites(
          ids.sublist(start, end),
        );
      }
      if (!mounted) return;
      setState(() => _selected.removeAll(ids));
      await _load(page: _page);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startPractice() async {
    if (_selected.isEmpty || _selected.length > 20 || _busy) return;
    final ids = _selected.toList()..sort();
    if (_pendingCreateId == null ||
        !_sameIds(ids, _pendingCreateWords ?? const [])) {
      _pendingCreateId = widget.controller.repository
          .newFavoritePracticeRequestId();
      _pendingCreateWords = ids;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.controller.repository.createFavoritePractice(
        ids,
        _pendingCreateId!,
      );
      if (!mounted) return;
      setState(() {
        _practice = session;
        _practiceResult = session.result;
        _pendingAnswer = null;
        _feedbackById.clear();
        _showingSummary = session.result != null;
        _answers.clear();
        _shownAnswers.clear();
        _questionIndex = 0;
        _pendingCreateId = null;
        _pendingCreateWords = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _sameIds(List<int> a, List<int> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  Future<void> _choose(String key) => _answerCurrent(key);

  Future<void> _showAnswer() => _answerCurrent(null, showAnswer: true);

  Future<void> _answerCurrent(String? key, {bool showAnswer = false}) async {
    final session = _practice;
    if (session == null || _busy || _pendingAnswer != null) return;
    final question = session.questions[_questionIndex];
    if (_feedbackById.containsKey(question.id)) return;
    final payload = <String, dynamic>{
      'request_id': widget.controller.repository.newFavoritePracticeRequestId(),
      'answer': {
        'question_id': question.id,
        'word_id': question.wordId,
        'selected_key': key,
        'is_show_answer': showAnswer,
      },
    };
    setState(() {
      _answers[question.id] = key;
      if (showAnswer) {
        _shownAnswers.add(question.id);
      } else {
        _shownAnswers.remove(question.id);
      }
      _pendingAnswer = payload;
      _error = null;
    });
    await _sendCurrentAnswer();
  }

  Future<void> _sendCurrentAnswer() async {
    final session = _practice;
    final payload = _pendingAnswer;
    if (session == null || payload == null || _busy) return;
    final answer = object(payload['answer']);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.controller.repository
          .answerFavoritePractice(
            session.id,
            payload['request_id'] as String,
            answer,
          );
      if (!mounted) return;
      setState(() {
        _feedbackById[answer['question_id'] as String] = response;
        if (response['summary'] is Map) {
          _practiceResult = object(response['summary']);
        }
        _pendingAnswer = null;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) =>
      error is ApiException ? error.message : '暂时无法完成操作，请重试。';

  @override
  Widget build(BuildContext context) =>
      _practice == null ? _listPage(context) : _practicePage(context);

  Widget _listPage(BuildContext context) {
    final mobile = JournalLayout.of(context).mobile;
    return SingleChildScrollView(
      child: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('我的单词收藏', style: Journal.hand(mobile ? 27 : 34)),
                      const SizedBox(height: 4),
                      const Text(
                        '那些想多看一眼的词，都收在这里。',
                        style: TextStyle(color: Journal.muted),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _hideMeanings = !_hideMeanings),
                  icon: Icon(
                    _hideMeanings
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 17,
                  ),
                  label: Text(_hideMeanings ? '显示释义' : '隐藏释义'),
                ),
              ],
            ),
            SizedBox(height: mobile ? 16 : 24),
            TextField(
              controller: _search,
              onChanged: _searchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(page: 1),
              decoration: InputDecoration(
                hintText: '搜索收藏的英文单词',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          _search.clear();
                          _load(page: 1);
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 11),
            _selectionBar(mobile),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorNote(_error!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(45),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_visible.isEmpty)
              _empty()
            else
              Paper(
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 13 : 24,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _visible.length; i++) ...[
                      _wordRow(_visible[i], i, mobile),
                      if (i + 1 < _visible.length) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            if (!_loading && (_data?.pages ?? 1) > 1) _pagination(mobile),
            const SizedBox(height: 16),
            const Text(
              '自主练习只用于巩固收藏词，不计入每日新学或正式复习，也不会改变掌握状态。',
              style: TextStyle(fontSize: 12, height: 1.8, color: Journal.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionBar(bool mobile) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 8,
    spacing: 12,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: _allVisibleSelected
                ? true
                : (_selectedOnPage > 0 ? null : false),
            tristate: true,
            onChanged: _loading || _visible.isEmpty
                ? null
                : (value) => _toggleVisible(value != false),
            visualDensity: VisualDensity.compact,
          ),
          GestureDetector(
            onTap: _visible.isEmpty
                ? null
                : () => _toggleVisible(!_allVisibleSelected),
            child: const Text('全选当前结果'),
          ),
          const SizedBox(width: 7),
          Text(
            '共 ${_data?.total ?? 0} 个',
            style: const TextStyle(fontSize: 12, color: Journal.muted),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '已选 ${_selected.length} 词',
            style: const TextStyle(fontSize: 12, color: Journal.muted),
          ),
          const SizedBox(width: 7),
          OutlinedButton(
            onPressed: _selected.isEmpty || _busy ? null : _removeSelected,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('取消收藏'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _selected.isEmpty || _selected.length > 20 || _busy
                ? null
                : _startPractice,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(_busy && _practice == null ? '准备中…' : '练习所选单词 →'),
          ),
        ],
      ),
    ],
  );

  Widget _wordRow(FavoriteWord word, int index, bool mobile) => Padding(
    padding: EdgeInsets.symmetric(vertical: mobile ? 12 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _selected.contains(word.id),
          onChanged: _busy
              ? null
              : (value) => setState(() {
                  if (value == true) {
                    _selected.add(word.id);
                  } else {
                    _selected.remove(word.id);
                  }
                  _pendingCreateId = null;
                  _pendingCreateWords = null;
                }),
        ),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                word.word,
                style: TextStyle(
                  fontSize: mobile ? 17 : 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF786347),
                ),
              ),
              if (word.uk.isNotEmpty)
                Text(
                  '英 /${word.uk}/',
                  style: const TextStyle(fontSize: 11, color: Journal.muted),
                ),
              if (word.us.isNotEmpty)
                Text(
                  '美 /${word.us}/',
                  style: const TextStyle(fontSize: 11, color: Journal.muted),
                ),
              if (!_hideMeanings)
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    word.meaning,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: Journal.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!mobile) const SizedBox(width: 12),
      ],
    ),
  );

  Widget _empty() => Paper(
    color: Journal.sage,
    child: Column(
      children: [
        const Icon(
          Icons.bookmark_border_rounded,
          size: 38,
          color: Journal.green,
        ),
        const SizedBox(height: 12),
        Text(
          _search.text.isEmpty ? '这里暂时没有单词' : '没有匹配的收藏单词',
          style: Journal.hand(22),
        ),
        const SizedBox(height: 6),
        Text(
          _search.text.isEmpty ? '可以在学习或阅读时收藏想练习的单词。' : '试试其他英文单词关键词。',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Journal.muted),
        ),
        if (_search.text.isNotEmpty)
          TextButton(
            onPressed: () {
              _search.clear();
              _load(page: 1);
            },
            child: const Text('清空搜索'),
          ),
      ],
    ),
  );

  Widget _pagination(bool mobile) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: _page <= 1 || _loading
              ? null
              : () => _load(page: _page - 1),
          child: const Text('上一页'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 20),
          child: Text(
            '$_page / ${_data!.pages}',
            style: const TextStyle(color: Journal.muted),
          ),
        ),
        OutlinedButton(
          onPressed: _page >= _data!.pages || _loading
              ? null
              : () => _load(page: _page + 1),
          child: const Text('下一页'),
        ),
      ],
    ),
  );

  Widget _practicePage(BuildContext context) {
    final session = _practice!;
    final mobile = JournalLayout.of(context).mobile;
    if (_showingSummary && _practiceResult != null) return _resultPage(mobile);
    if (session.questions.isEmpty) return _emptyPractice();
    final question = session.questions[_questionIndex];
    final value = _answers[question.id];
    final shown = _shownAnswers.contains(question.id);
    final feedback = _feedbackById[question.id];
    final answered = feedback != null;
    final navigationLocked = _busy || _pendingAnswer != null;
    final locked = navigationLocked || answered;
    return SingleChildScrollView(
      child: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _leavePractice,
                  icon: const Icon(Icons.arrow_back, size: 17),
                  label: const Text('返回收藏'),
                ),
                const Spacer(),
                Text(
                  '练习 ${_questionIndex + 1} / ${session.questions.length}',
                  style: const TextStyle(fontSize: 12, color: Journal.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              ErrorNote(_error!),
              if (_pendingAnswer != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _sendCurrentAnswer,
                    child: const Text('重试本题'),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            Paper(
              padding: EdgeInsets.all(mobile ? 16 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '收藏自主练习 · ${question.type == 'en_to_zh' ? '英译中' : '中译英'}',
                    style: TextStyle(
                      fontSize: mobile ? 9 : 11,
                      color: Journal.muted,
                    ),
                  ),
                  SizedBox(height: mobile ? 13 : 22),
                  Text(
                    question.prompt,
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
                  if (question.type == 'en_to_zh' &&
                      (question.uk.isNotEmpty || question.us.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        '英 ${question.uk.isEmpty ? '' : '/${question.uk}/'}',
                        '美 ${question.us.isEmpty ? '' : '/${question.us}/'}',
                      ].where((v) => v.trim().isNotEmpty).join('　'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Journal.muted,
                      ),
                    ),
                  ],
                  SizedBox(height: mobile ? 20 : 27),
                  Text(
                    question.type == 'en_to_zh'
                        ? '选出这个单词对应的中文释义'
                        : '选出这段中文对应的英文单词',
                    style: const TextStyle(fontSize: 12, color: Journal.muted),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) {
                      final columns = box.maxWidth >= 580 ? 2 : 1;
                      final gap = 14.0;
                      return Wrap(
                        spacing: gap,
                        runSpacing: mobile ? 9 : 14,
                        children: [
                          for (final option in question.options)
                            SizedBox(
                              width:
                                  (box.maxWidth - gap * (columns - 1)) /
                                  columns,
                              child: _practiceOption(
                                option,
                                value == option['key'],
                                locked,
                                mobile,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (feedback != null) _answerFeedback(question, feedback),
                  if (!answered)
                    TextButton(
                      onPressed: locked || shown ? null : _showAnswer,
                      child: const Text('暂时想不起来，查看答案'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: _questionIndex == 0 || navigationLocked
                      ? null
                      : () => setState(() => _questionIndex--),
                  child: const Text('上一题'),
                ),
                if (_questionIndex + 1 < session.questions.length)
                  FilledButton(
                    onPressed: navigationLocked
                        ? null
                        : () => setState(() => _questionIndex++),
                    child: const Text('下一题 →'),
                  )
                else
                  FilledButton(
                    onPressed:
                        !answered || _practiceResult == null || navigationLocked
                        ? null
                        : () => setState(() => _showingSummary = true),
                    child: const Text('查看练习小结'),
                  ),
              ],
            ),
            if (!answered)
              const Padding(
                padding: EdgeInsets.only(top: 9),
                child: Text(
                  '选择答案后会立即判定，也可以点“查看答案”。',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Journal.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _answerFeedback(FavoritePracticeQuestion question, Json feedback) {
    final correct = feedback['is_correct'] == true;
    final shown = feedback['is_show_answer'] == true;
    final correctKey = feedback['correct_key'] as String?;
    final selectedKey = feedback['selected_key'] as String?;
    String? optionText(String? key) => key == null
        ? null
        : question.options
                  .where((option) => option['key'] == key)
                  .firstOrNull?['text']
              as String?;
    final detail = feedback['word_detail'] is Map
        ? object(feedback['word_detail'])
        : <String, dynamic>{};
    final translations = detail['translations'] is List
        ? (detail['translations'] as List)
              .map((item) {
                final value = object(item);
                return '${value['pos'] ?? ''} ${value['tranCn'] ?? value['tran'] ?? ''}'
                    .trim();
              })
              .where((text) => text.isNotEmpty)
              .join('；')
        : '';
    final wrong = shown || !correct;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(15),
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
            shown ? '答案揭晓' : (correct ? '回答正确！' : '这题答错了'),
            style: Journal.hand(20),
          ),
          const SizedBox(height: 7),
          if (!correct && !shown)
            Text(
              '你的答案：${optionText(selectedKey) ?? '未选择'}',
              style: const TextStyle(fontSize: 13, height: 1.7),
            ),
          Text(
            '正确答案：${optionText(correctKey) ?? '见下方释义'}',
            style: const TextStyle(fontSize: 13, height: 1.7),
          ),
          if (translations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                translations,
                style: const TextStyle(fontSize: 14, height: 1.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _practiceOption(Json option, bool selected, bool locked, bool mobile) {
    final key = option['key'] as String;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(44, mobile ? 48 : 68),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(
          horizontal: mobile ? 12 : 17,
          vertical: mobile ? 10 : 16,
        ),
        backgroundColor: selected ? Journal.sage : Journal.paper,
        disabledBackgroundColor: selected ? Journal.sage : Journal.paper,
        foregroundColor: Journal.ink,
        disabledForegroundColor: Journal.ink,
        side: BorderSide(
          color: selected ? const Color(0xFFB7C99B) : Journal.line,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      onPressed: locked ? null : () => _choose(key),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F0DC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(key, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              (option['text'] ?? '').toString(),
              style: TextStyle(fontSize: mobile ? 13 : 14, height: 1.7),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 7),
            const Icon(
              Icons.radio_button_checked,
              size: 18,
              color: Journal.green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultPage(bool mobile) {
    final result = _practiceResult!;
    final outcomes = (result['results'] as List? ?? const [])
        .map(object)
        .toList();
    final outcomeById = {
      for (final outcome in outcomes) outcome['question_id']: outcome,
    };
    return SingleChildScrollView(
      child: PageFrame(
        child: Paper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 42,
                color: Journal.green,
              ),
              const SizedBox(height: 12),
              Text(
                '这轮练习完成了。',
                textAlign: TextAlign.center,
                style: Journal.hand(29),
              ),
              const SizedBox(height: 8),
              Text(
                '答对 ${result['correct_count']} / ${result['total']} 词　·　${result['score']} 分',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Journal.green),
              ),
              const SizedBox(height: 18),
              for (final question in _practice!.questions)
                _practiceResultRow(question, outcomeById[question.id], mobile),
              const SizedBox(height: 17),
              Align(
                alignment: Alignment.center,
                child: FilledButton(
                  onPressed: _leavePractice,
                  child: const Text('回到我的收藏'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '自主练习不会修改正式学习、掌握或复习进度。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Journal.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _practiceResultRow(
    FavoritePracticeQuestion question,
    Json? outcome,
    bool mobile,
  ) {
    final correct = outcome?['is_correct'] == true;
    final correctKey = outcome?['correct_key'] as String?;
    final answer = question.options
        .where((option) => option['key'] == correctKey)
        .firstOrNull?['text'];
    final selectedKey = _answers[question.id];
    final selected = question.options
        .where((option) => option['key'] == selectedKey)
        .firstOrNull?['text'];
    final detail = outcome?['word_detail'] is Map
        ? object(outcome!['word_detail'])
        : null;
    final trans = detail?['translations'] is List
        ? (detail!['translations'] as List)
              .map((e) {
                final item = object(e);
                return '${item['pos'] ?? ''} ${item['tranCn'] ?? ''}'.trim();
              })
              .join('；')
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Journal.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                correct
                    ? '答对'
                    : (_shownAnswers.contains(question.id) ? '查看答案' : '答错'),
                style: TextStyle(
                  fontSize: 12,
                  color: correct ? Journal.green : const Color(0xFFA76559),
                ),
              ),
            ],
          ),
          if (trans.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                trans,
                style: const TextStyle(fontSize: 12, color: Journal.muted),
              ),
            ),
          if (!correct)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                '${_shownAnswers.contains(question.id) ? '未作答' : '你的选择：${selected ?? '未作答'}'}　正确答案：${answer ?? '见释义'}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Journal.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyPractice() => Paper(
    child: Column(
      children: [
        const Text('这轮没有生成题目。'),
        TextButton(onPressed: _leavePractice, child: const Text('返回收藏')),
      ],
    ),
  );

  void _leavePractice() {
    setState(() {
      _practice = null;
      _practiceResult = null;
      _pendingAnswer = null;
      _feedbackById.clear();
      _showingSummary = false;
      _practiceResult = null;
      _answers.clear();
      _shownAnswers.clear();
      _questionIndex = 0;
      _error = null;
    });
    _load(page: _page);
  }
}
