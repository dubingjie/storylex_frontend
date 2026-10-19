import 'package:flutter/material.dart';

import '../data/story_models.dart';
import '../state/app_controller.dart';
import '../state/reading_controller.dart';
import 'journal.dart';
import 'reading_dialogs.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.controller,
    required this.storyId,
    required this.onBack,
    required this.backLabel,
    this.resumePosition = false,
  });
  final AppController controller;
  final int storyId;
  final VoidCallback onBack;
  final String backLabel;
  final bool resumePosition;
  @override
  State<ReadingScreen> createState() => ReadingScreenState();
}

class ReadingScreenState extends State<ReadingScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _viewport = GlobalKey();
  late final String? _token = widget.controller.session?.token;
  late final _reader = ReadingController(
    widget.controller.repository,
    widget.storyId,
    () => widget.controller.session?.token == _token,
  );
  StoryDocument? _document;
  List<GlobalKey> _paragraphKeys = [];
  bool _showMeanings = false, _restoring = false;
  bool get _alive => mounted && _reader.alive;
  @override
  void initState() {
    super.initState();
    _reader.addListener(_changed);
    _scroll.addListener(_scrolled);
    _reader.load(resume: widget.resumePosition);
  }

  void _changed() {
    if (!mounted) return;
    if (_reader.document != null && _reader.document != _document) {
      _document = _reader.document;
      _paragraphKeys = List.generate(
        _document!.paragraphs.length,
        (_) => GlobalKey(),
      );
      _restoring = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_alive) _restorePosition();
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _reader.removeListener(_changed);
    _reader.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> flushBeforeLeaving() async {
    if (!_reader.dirty) return;
    final saved = await _reader.flush();
    if (_alive && !saved)
      showNote(context, '本次阅读位置未保存。${_reader.saveError ?? '请检查网络。'}');
  }

  void _restorePosition() {
    if (!_scroll.hasClients || _document == null) {
      _restoring = false;
      return;
    }
    final offset = _reader.position;
    if (offset > 0 && _document!.paragraphs.isNotEmpty) {
      var index = _document!.paragraphs.lastIndexWhere(
        (p) => p.offset <= offset,
      );
      if (index < 0) index = 0;
      final paragraph = _document!.paragraphs[index],
          box = _paragraphKeys[index].currentContext?.findRenderObject(),
          viewport = _viewport.currentContext?.findRenderObject();
      if (box is RenderBox && viewport is RenderBox) {
        final fraction = ((offset - paragraph.offset) / paragraph.length).clamp(
          0.0,
          1.0,
        );
        final target =
            _scroll.offset +
            box.localToGlobal(Offset.zero).dy -
            viewport.localToGlobal(Offset.zero).dy +
            box.size.height * fraction;
        _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoring = false;
    });
  }

  void _scrolled() {
    if (!_alive ||
        _restoring ||
        _document == null ||
        !_scroll.hasClients ||
        _reader.loading)
      return;
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    var offset = 0;
    for (var i = 0; i < _paragraphKeys.length; i++) {
      final box = _paragraphKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height > top + 12) {
        final p = _document!.paragraphs[i];
        final fraction = ((top - y) / box.size.height).clamp(0.0, 1.0);
        offset = p.offset + (p.length * fraction).floor();
        break;
      }
      offset =
          _document!.paragraphs[i].offset + _document!.paragraphs[i].length;
    }
    if (_scroll.offset >= _scroll.position.maxScrollExtent - 2 &&
        _scroll.offset > 0)
      offset = _document!.length;
    if (_scroll.offset <= 0) offset = 0;
    _reader.updatePosition(
      offset,
      _document!.length == 0 ? 0 : 100 * offset / _document!.length,
    );
  }

  Future<void> _word(StoryWord word) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ReadingWordDialog(
        controller: widget.controller,
        storyId: widget.storyId,
        word: word,
      ),
    );
    if (_alive) setState(() {});
  }

  void _vocabulary() {
    final mobile = JournalLayout.of(context).mobile;
    Widget panel(BuildContext panelContext) => Padding(
      padding: EdgeInsets.all(mobile ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '全文词表 · ${_reader.detail!.words.length} 词',
                  style: Journal.hand(mobile ? 24 : 28),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(panelContext),
                tooltip: '关闭词表',
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: _wordList((word) {
                Navigator.pop(panelContext);
                _word(word);
              }),
            ),
          ),
        ],
      ),
    );
    if (mobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Journal.paper,
        builder: (panelContext) => SizedBox(
          height: MediaQuery.sizeOf(panelContext).height * .82,
          child: panel(panelContext),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (panelContext) => Dialog(
          backgroundColor: Journal.paper,
          insetPadding: const EdgeInsets.all(32),
          child: SizedBox(
            width: 820,
            height: MediaQuery.sizeOf(panelContext).height * .78,
            child: panel(panelContext),
          ),
        ),
      );
    }
  }

  void _practice() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReadingPracticeDialog(
        controller: widget.controller,
        storyId: widget.storyId,
        onFinished: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _reader.detail, layout = JournalLayout.of(context);
    return SizedBox.expand(
      key: _viewport,
      child: SingleChildScrollView(
        controller: _scroll,
        child: PageFrame(
          width: 1240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 17),
                  label: Text(widget.backLabel),
                ),
              ),
              const SizedBox(height: 15),
              if (_reader.loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (detail == null) ...[
                ErrorNote(_reader.error ?? '故事暂时没能打开。'),
                TextButton(
                  onPressed: _reader.load,
                  child: const Text('重新打开故事'),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        detail.title,
                        style: Journal.hand(layout.mobile ? 27 : 32),
                      ),
                    ),
                    IconButton(
                      onPressed: _reader.favoriteBusy ? null : _reader.favorite,
                      tooltip: detail.favorite ? '取消文章收藏' : '收藏文章',
                      icon: Icon(
                        detail.favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: const Color(0xFFBB9299),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children:
                      [
                            Text(storySource(detail.source)),
                            Text('${detail.words.length} 个生词'),
                            Text(detail.completed ? '已阅读' : '阅读中'),
                          ]
                          .map(
                            (text) => DefaultTextStyle.merge(
                              style: const TextStyle(
                                fontSize: 11,
                                color: Journal.muted,
                              ),
                              child: text,
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 23),
                if (_reader.error != null) ErrorNote(_reader.error!),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFAF0),
                    border: Border.all(color: Journal.line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _showMeanings = !_showMeanings);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_alive) _scrolled();
                              });
                            },
                            icon: Icon(
                              _showMeanings
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 17,
                            ),
                            label: Text(_showMeanings ? '隐藏释义' : '显示释义'),
                          ),
                          TextButton.icon(
                            onPressed: _vocabulary,
                            icon: const Icon(
                              Icons.format_list_bulleted,
                              size: 17,
                            ),
                            label: Text('词表 ${detail.words.length}'),
                          ),
                        ],
                      ),
                      Text(
                        '阅读进度 ${_reader.percent.round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Journal.green,
                        ),
                      ),
                      TextButton(
                        onPressed: _reader.saving
                            ? null
                            : () async {
                                if (_reader.conflict) {
                                  await _reader.load();
                                  return;
                                }
                                final ok = await _reader.flush();
                                if (_alive && ok) showNote(context, '阅读位置已保存。');
                              },
                        child: Text(
                          _reader.conflict
                              ? '重新载入位置'
                              : _reader.saving
                              ? '保存中…'
                              : '保存位置',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_reader.saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ErrorNote(_reader.saveError!),
                  ),
                const SizedBox(height: 25),
                LayoutBuilder(
                  builder: (context, box) {
                    final side = box.maxWidth >= 850;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Paper(
                            padding: EdgeInsets.all(layout.mobile ? 20 : 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var i = 0;
                                  i < _document!.paragraphs.length;
                                  i++
                                )
                                  Padding(
                                    key: _paragraphKeys[i],
                                    padding: const EdgeInsets.only(bottom: 22),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 684,
                                        ),
                                        child: _paragraph(
                                          _document!.paragraphs[i],
                                          detail,
                                          layout,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                const Text(
                                  '— 本篇完 —',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Journal.muted,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    WaitButton(
                                      text: detail.completed
                                          ? '已标记阅读完成'
                                          : '完成阅读',
                                      busy: _reader.completeBusy,
                                      onPressed: detail.completed
                                          ? null
                                          : () async {
                                              final done = await _reader
                                                  .complete();
                                              if (_alive && done) {
                                                showNote(context, '已标记为已阅读。');
                                                widget.controller.refreshHome();
                                              }
                                            },
                                    ),
                                    OutlinedButton(
                                      onPressed: _practice,
                                      child: const Text('去练习 →'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  '读到末尾不会自动完读，点“完成阅读”才会标记。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Journal.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (side) ...[
                          const SizedBox(width: 25),
                          SizedBox(
                            width: 220,
                            child: Paper(
                              tape: false,
                              padding: const EdgeInsets.all(17),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('这一页的单词', style: Journal.hand(21)),
                                  const SizedBox(height: 10),
                                  _wordList(_word),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _paragraph(
    StoryParagraph paragraph,
    StoryDetail detail,
    JournalLayout layout,
  ) {
    final words = {for (final w in detail.words) w.id: w};
    final textStyle = TextStyle(
      fontSize: layout.mobile ? 16 : 18,
      height: 2.15,
      color: const Color(0xFF65523F),
    );
    return Text.rich(
      TextSpan(
        style: textStyle,
        children: [
          for (final run in paragraph.runs)
            if (run.wordId != null && words[run.wordId] != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: const Color(0xFFF8EFCF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  onPressed: () => _word(words[run.wordId]!),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        run.text,
                        style: textStyle.copyWith(
                          color: const Color(0xFF8D7445),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      if (_showMeanings)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            words[run.wordId]!.meaning,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Journal.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              TextSpan(text: run.text),
        ],
      ),
    );
  }

  Widget _wordList(ValueChanged<StoryWord> onTap) => Material(
    type: MaterialType.transparency,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_reader.detail!.words.isEmpty)
          const Padding(
            padding: EdgeInsets.all(15),
            child: Text('这篇故事没有内嵌单词。'),
          ),
        for (final word in _reader.detail!.words)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => onTap(word),
            title: Text(word.word, style: const TextStyle(fontSize: 16)),
            subtitle: Text(
              word.meaning,
              style: const TextStyle(fontSize: 12, height: 1.7),
            ),
            trailing: word.mastered
                ? const Icon(Icons.check, size: 17, color: Journal.green)
                : word.favorite
                ? const Icon(Icons.favorite, size: 16, color: Color(0xFFBB9299))
                : null,
          ),
      ],
    ),
  );
}
