import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/story_repository.dart';
import '../data/models.dart';
import '../data/story_models.dart';
import '../state/app_controller.dart';
import 'journal.dart';

class ReadingWordDialog extends StatefulWidget {
  const ReadingWordDialog({
    super.key,
    required this.controller,
    required this.storyId,
    required this.word,
  });
  final AppController controller;
  final int storyId;
  final StoryWord word;
  @override
  State<ReadingWordDialog> createState() => _ReadingWordDialogState();
}

class _ReadingWordDialogState extends State<ReadingWordDialog> {
  late final _token = widget.controller.session?.token;
  bool _busy = false, _uncertain = false;
  String? _error;
  bool get _alive => mounted && widget.controller.session?.token == _token;
  Future<void> _act({bool master = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_uncertain && !master) {
        final latest = await widget.controller.repository.story(widget.storyId);
        if (!_alive) return;
        final word = latest.words.firstWhere((w) => w.id == widget.word.id);
        widget.word.favorite = word.favorite;
        widget.word.mastered = word.mastered;
        _uncertain = false;
      } else if (master) {
        await widget.controller.repository.masterReadingWord(widget.word.id);
        if (!_alive) return;
        widget.word.mastered = true;
        widget.controller.refreshHome();
      } else {
        final value = await widget.controller.repository.favoriteReadingWord(
          widget.word.id,
        );
        if (!_alive) return;
        widget.word.favorite = value;
      }
    } catch (e) {
      if (_alive) {
        _error = e is ApiException ? e.message : '操作未能完成，请重试。';
        if (!master) _uncertain = true;
      }
    } finally {
      if (_alive) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    return AlertDialog(
      backgroundColor: Journal.paper,
      title: Row(
        children: [
          Expanded(
            child: Text(
              word.word,
              style: const TextStyle(
                fontFamily: 'JournalSans',
                fontFamilyFallback: ['JournalSansFull'],
                fontSize: 30,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: Journal.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: '关闭单词释义',
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (word.book.isNotEmpty)
                Text(
                  '${word.book}${word.outOfBook ? ' · 当前词书外' : ''}',
                  style: const TextStyle(fontSize: 11, color: Journal.muted),
                ),
              const SizedBox(height: 13),
              if (word.us.isNotEmpty)
                Text(
                  '美 /${word.us}/',
                  style: const TextStyle(
                    fontFamily: 'JournalPhonetic',
                    fontFamilyFallback: ['JournalSansFull'],
                    fontSize: 14,
                    color: Journal.muted,
                  ),
                ),
              if (word.uk.isNotEmpty)
                Text(
                  '英 /${word.uk}/',
                  style: const TextStyle(
                    fontFamily: 'JournalPhonetic',
                    fontFamilyFallback: ['JournalSansFull'],
                    fontSize: 14,
                    color: Journal.muted,
                  ),
                ),
              const SizedBox(height: 17),
              Text(
                word.meaning,
                style: const TextStyle(fontSize: 16, height: 1.9),
              ),
              const SizedBox(height: 18),
              const Text(
                '收藏仅保存到收藏夹，不加入正式复习队列。',
                style: TextStyle(fontSize: 11, color: Journal.muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorNote(_error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : () => _act(),
          child: Text(
            _uncertain
                ? '重新核对收藏状态'
                : word.favorite
                ? '取消单词收藏'
                : '收藏单词',
          ),
        ),
        FilledButton(
          onPressed: _busy || word.mastered ? null : () => _act(master: true),
          child: Text(word.mastered ? '已掌握' : '标记已掌握'),
        ),
      ],
    );
  }
}

class ReadingPracticeDialog extends StatefulWidget {
  const ReadingPracticeDialog({
    super.key,
    required this.controller,
    required this.storyId,
    required this.onFinished,
  });
  final AppController controller;
  final int storyId;
  final VoidCallback onFinished;
  @override
  State<ReadingPracticeDialog> createState() => _ReadingPracticeDialogState();
}

class _ReadingPracticeDialogState extends State<ReadingPracticeDialog> {
  late final _token = widget.controller.session?.token;
  final _answers = <String, Json>{};
  final _requestId = newRequestId();
  ReadingPractice? _practice;
  Json? _result;
  List<Json>? _sealedAnswers;
  int _index = 0;
  bool _loading = true, _submitting = false;
  String? _error;
  bool get _alive => mounted && widget.controller.session?.token == _token;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.controller.repository.readingPractice(
        widget.storyId,
      );
      if (_alive) setState(() => _practice = data);
    } catch (e) {
      if (_alive)
        setState(
          () => _error = e is ApiException ? e.message : '练习暂时没能打开，请重试。',
        );
    } finally {
      if (_alive) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting ||
        _practice?.session == null ||
        _answers.length != _practice!.questions.length)
      return;
    _sealedAnswers ??= _practice!.questions
        .map((q) => Map<String, dynamic>.from(_answers[q.id]!))
        .toList();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.controller.repository.submitReadingPractice(
        widget.storyId,
        _practice!.session!,
        _requestId,
        _sealedAnswers!,
      );
      if (!_alive) return;
      setState(() => _result = result);
      widget.onFinished();
      widget.controller.refreshHome();
    } catch (e) {
      if (_alive)
        setState(
          () => _error = e is ApiException ? e.message : '提交未能确认，请重试本次提交。',
        );
    } finally {
      if (_alive) setState(() => _submitting = false);
    }
  }

  void _choose(ReadingQuestion q, String? key) {
    if (_sealedAnswers != null) return;
    setState(() {
      if (key == null && _answers[q.id]?['is_show_answer'] == true) {
        _answers.remove(q.id);
      } else {
        _answers[q.id] = {
          'question_id': q.id,
          'word_id': q.wordId,
          'selected_key': key,
          'is_show_answer': key == null,
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Journal.paper,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 650,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _result == null ? '这一页的小练习' : '练习完成',
                    style: Journal.hand(26),
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  tooltip: '关闭阅读练习',
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ErrorNote(_error!),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(25),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_practice == null)
                      TextButton(onPressed: _load, child: const Text('重新打开练习'))
                    else if (_practice!.questions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('这篇文章暂无可出题词汇，先去读一篇新的故事吧。'),
                      )
                    else if (_result != null)
                      _resultView()
                    else
                      _questionView(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _questionView() {
    final q = _practice!.questions[_index], answer = _answers[q.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_index + 1} / ${_practice!.questions.length} · 选择这个单词的意思',
          style: const TextStyle(fontSize: 12, color: Journal.muted),
        ),
        const SizedBox(height: 20),
        Text(
          q.word,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, color: Journal.ink),
        ),
        const SizedBox(height: 22),
        for (final option in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: answer?['selected_key'] == option['key']
                    ? Journal.sage
                    : Journal.paper,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _sealedAnswers != null
                  ? null
                  : () => _choose(q, option['key'] as String),
              child: Text('${option['key']}  ${option['trans']}'),
            ),
          ),
        TextButton(
          onPressed: _sealedAnswers != null ? null : () => _choose(q, null),
          child: Text(
            answer?['is_show_answer'] == true ? '已选择：暂时不会（再次点击取消）' : '暂时不会',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: _index == 0 || _submitting
                  ? null
                  : () => setState(() => _index--),
              child: const Text('上一题'),
            ),
            if (_index < _practice!.questions.length - 1)
              FilledButton(
                onPressed: answer == null || _submitting
                    ? null
                    : () => setState(() => _index++),
                child: const Text('下一题 →'),
              )
            else
              WaitButton(
                text: _sealedAnswers == null ? '提交练习' : '重试本次提交',
                busy: _submitting,
                onPressed: _answers.length == _practice!.questions.length
                    ? _submit
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 15),
        const Text(
          '答题结果以提交后显示为准。完成练习不会自动标记文章已阅读。',
          style: TextStyle(fontSize: 11, color: Journal.muted),
        ),
      ],
    );
  }

  Widget _resultView() {
    final result = _result!,
        results = (result['results'] as List).map(object).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${result['score']} 分',
          style: Journal.hand(38),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          '答对 ${result['correct_count']} / ${result['total']} 题',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          '${result['wrong_words_queued']} 个错词已安排后续复习。已掌握或暂停复习的词保持原状态。',
          style: const TextStyle(fontSize: 12, color: Journal.muted),
        ),
        const SizedBox(height: 20),
        for (final q in _practice!.questions)
          Builder(
            builder: (context) {
              final r = results.firstWhere((r) => r['question_id'] == q.id);
              final correct = q.options.firstWhere(
                (o) => o['key'] == r['correct_key'],
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r['is_correct'] == true
                      ? Icons.check_circle_outline
                      : Icons.close,
                  color: r['is_correct'] == true
                      ? Journal.green
                      : const Color(0xFFAF7468),
                ),
                title: Text(q.word),
                subtitle: Text('${correct['key']} · ${correct['trans']}'),
              );
            },
          ),
        const SizedBox(height: 15),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('回到故事'),
        ),
      ],
    );
  }
}
