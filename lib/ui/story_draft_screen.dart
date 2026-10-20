import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/favorite_repository.dart';
import '../core/story_repository.dart';
import '../data/favorite_models.dart';
import '../data/models.dart';
import '../data/story_models.dart';
import '../state/app_controller.dart';
import 'journal.dart';

class StoryDraftScreen extends StatefulWidget {
  const StoryDraftScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onSaved,
  });
  final AppController controller;
  final VoidCallback onBack, onSaved;

  @override
  State<StoryDraftScreen> createState() => _StoryDraftScreenState();
}

class _StoryDraftScreenState extends State<StoryDraftScreen> {
  final _theme = TextEditingController(text: '温暖、轻松的日常故事');
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _selectedWords = <int, FavoriteWord>{};
  StoryDraft? _draft;
  String? _generationId, _saveId, _error;
  bool _busy = false, _editing = false, _contentSaved = false;

  @override
  void dispose() {
    _theme.dispose();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickWords() async {
    final result = await showDialog<Map<int, FavoriteWord>>(
      context: context,
      builder: (_) => _FavoriteWordPicker(
        repository: widget.controller.repository,
        initial: Map.of(_selectedWords),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedWords
          ..clear()
          ..addAll(result);
        _generationId = null;
        _draft = null;
        _error = null;
      });
    }
  }

  Future<void> _generate({bool newAttempt = false}) async {
    if (_busy) return;
    if (_selectedWords.length < 2 || _selectedWords.length > 20) {
      setState(() => _error = '请选择 2 到 20 个收藏单词。');
      return;
    }
    final theme = _theme.text.trim();
    if (theme.isEmpty) {
      setState(() => _error = '请填写故事主题或风格。');
      return;
    }
    if (newAttempt || _generationId == null) {
      _generationId = newRequestId();
      _draft = null;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var draft = await widget.controller.repository.generateAiDraft(
        requestId: _generationId!,
        wordIds: _selectedWords.keys.toList(),
        storyType: theme,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      );
      if (!mounted) return;
      setState(() => _draft = draft);
      for (
        var attempt = 0;
        draft.status == 'generating' && attempt < 40;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        draft = await widget.controller.repository.storyDraft(draft.id);
        if (!mounted) return;
        setState(() => _draft = draft);
      }
      if (draft.status == 'generating') {
        setState(() => _error = '生成仍在进行，可以稍后点“继续检查”。');
      } else if (draft.status == 'ready') {
        _title.text = draft.title;
        _content.text = draft.content;
        setState(() {
          _editing = false;
          _contentSaved = false;
        });
      } else if (draft.status == 'failed') {
        setState(() => _error = _draftError(draft));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkDraft() async {
    final draft = _draft;
    if (draft == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final latest = await widget.controller.repository.storyDraft(draft.id);
      if (!mounted) return;
      setState(() => _draft = latest);
      if (latest.status == 'ready') {
        _title.text = latest.title;
        _content.text = latest.content;
      } else if (latest.status == 'failed') {
        setState(() => _error = _draftError(latest));
      } else if (latest.status == 'generating') {
        setState(() => _error = '还在生成，请稍后再检查。');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _draftError(StoryDraft draft) =>
      '生成失败${draft.errorCode.isEmpty ? '' : '（${draft.errorCode}）'}：${draft.error.isEmpty ? '请检查服务配置后重试。' : draft.error}';

  String _message(Object error) =>
      error is ApiException ? error.message : '暂时无法完成操作，请重试。';

  void _generationInputsChanged() {
    if (_busy) return;
    setState(() {
      _generationId = null;
      _draft = null;
      _error = null;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.status != 'ready' || _busy) return;
    if (_title.text.trim().isEmpty || _title.text.trim().length > 150) {
      setState(() => _error = '标题需要填写，且不能超过 150 个字符。');
      return;
    }
    if (_content.text.trim().isEmpty) {
      setState(() => _error = '正文不能为空。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var latest = draft;
      final changed =
          _title.text.trim() != draft.title || _content.text != draft.content;
      if (changed && !_contentSaved) {
        latest = await widget.controller.repository.editStoryDraft(
          draft.id,
          version: draft.version,
          title: _title.text.trim(),
          content: _content.text,
        );
        if (!mounted) return;
        setState(() {
          _draft = latest;
          _contentSaved = true;
        });
      }
      _saveId ??= newRequestId();
      await widget.controller.repository.saveStoryDraft(
        draft.id,
        requestId: _saveId!,
        version: latest.version,
      );
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return SingleChildScrollView(
      child: PageFrame(
        width: 1000,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 17),
                label: const Text('返回文章库'),
              ),
            ),
            const SizedBox(height: 8),
            Text('AI 写一篇故事', style: Journal.hand(32)),
            const SizedBox(height: 5),
            const Text(
              '挑选想练习的词，生成草稿后检查内容，再保存到我的书库。',
              style: TextStyle(color: Journal.muted),
            ),
            const SizedBox(height: 22),
            if (_error != null) ...[
              ErrorNote(_error!),
              if (draft?.status == 'failed')
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : () => _generate(newAttempt: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('使用新的任务编号重新生成'),
                  ),
                ),
              if (draft?.status == 'generating' && !_busy)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _checkDraft,
                    icon: const Icon(Icons.refresh),
                    label: const Text('继续检查生成状态'),
                  ),
                ),
            ],
            if (draft == null || draft.status != 'ready') _form(draft),
            if (draft?.status == 'ready') _preview(draft!),
          ],
        ),
      ),
    );
  }

  Widget _form(StoryDraft? draft) => Paper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('先选词', style: Journal.hand(22)),
        const SizedBox(height: 7),
        const Text(
          '从你的收藏夹中选择 2～20 个单词。',
          style: TextStyle(color: Journal.muted),
        ),
        const SizedBox(height: 15),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickWords,
          icon: const Icon(Icons.checklist_rounded),
          label: Text('选择收藏单词（${_selectedWords.length}/20）'),
        ),
        if (_selectedWords.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final word in _selectedWords.values)
                InputChip(
                  label: Text(word.word),
                  onDeleted: _busy
                      ? null
                      : () => setState(() {
                          _selectedWords.remove(word.id);
                          _generationId = null;
                          _draft = null;
                        }),
                  backgroundColor: Journal.sage,
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _theme,
          enabled: !_busy,
          maxLength: 1000,
          onChanged: (_) => _generationInputsChanged(),
          decoration: const InputDecoration(
            labelText: '故事主题或风格',
            hintText: '例如：雨夜里的旧书店、轻松治愈的校园故事',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          enabled: !_busy,
          maxLength: 150,
          onChanged: (_) => _generationInputsChanged(),
          decoration: const InputDecoration(
            labelText: '自定义标题（可选）',
            hintText: '留空则由 AI 拟定标题',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        if (draft?.status == 'generating' || _busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 13),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        WaitButton(
          text: _busy ? '正在生成故事…' : '生成预览草稿 →',
          busy: _busy,
          onPressed: _busy ? null : () => _generate(),
        ),
        const SizedBox(height: 12),
        const Text(
          '生成内容会先作为草稿，不会自动进入文章库。预览确认后才会保存。',
          style: TextStyle(fontSize: 12, color: Journal.muted),
        ),
      ],
    ),
  );

  Widget _preview(StoryDraft draft) {
    final mobile = JournalLayout.of(context).mobile;
    final words = {
      for (final word in draft.targetWords)
        number(word['word_id']): word['word']?.toString() ?? '',
    };
    final missing = draft.missingWordIds
        .map((id) => words[id] ?? '$id')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Paper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('预览草稿', style: Journal.hand(23))),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _editing = !_editing),
                    icon: Icon(
                      _editing
                          ? Icons.visibility_outlined
                          : Icons.edit_outlined,
                      size: 17,
                    ),
                    label: Text(_editing ? '查看排版' : '编辑标题和正文'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_editing) ...[
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: '文章标题',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _contentSaved = false),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _content,
                  enabled: !_busy,
                  minLines: 12,
                  maxLines: 28,
                  maxLength: 50000,
                  decoration: const InputDecoration(
                    labelText: '正文与生词标记',
                    helperText:
                        '编辑时请保留系统生成的 <word id="数字">英文词</word> 标记；只能调整文字和已有标签。',
                    alignLabelWithHint: true,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _contentSaved = false),
                ),
              ] else ...[
                Text(_title.text, style: Journal.hand(mobile ? 25 : 30)),
                const SizedBox(height: 16),
                _renderContent(_content.text, words),
              ],
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 17),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Journal.yellow,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '草稿中暂未出现这些目标词：${missing.join('、')}。保存前请检查正文。',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 17),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text(
                    '${draft.wordIds.length} 个生词',
                    style: const TextStyle(color: Journal.muted, fontSize: 12),
                  ),
                  Text(
                    '${draft.embeddedOccurrences} 处标记',
                    style: const TextStyle(color: Journal.muted, fontSize: 12),
                  ),
                  Text(
                    '草稿版本 ${draft.version}',
                    style: const TextStyle(color: Journal.muted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : widget.onBack,
                      child: const Text('暂不保存'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WaitButton(
                      text: '保存到我的书库',
                      busy: _busy,
                      onPressed: _busy ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '单词标记会在阅读时显示释义。保存只创建文章，不会自动标记已读或加入复习。',
          style: TextStyle(fontSize: 12, color: Journal.muted),
        ),
      ],
    );
  }

  Widget _renderContent(String content, Map<int, String> words) {
    final document = StoryDocument(content);
    if (document.paragraphs.isEmpty) {
      return const Text('正文预览暂时为空。', style: TextStyle(color: Journal.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final paragraph in document.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: SelectableText.rich(
              TextSpan(
                children: [
                  for (final run in paragraph.runs)
                    TextSpan(
                      text: run.text,
                      style:
                          run.wordId == null || !words.containsKey(run.wordId)
                          ? null
                          : const TextStyle(
                              color: Journal.green,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.dotted,
                            ),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 15, height: 2),
            ),
          ),
      ],
    );
  }
}

class _FavoriteWordPicker extends StatefulWidget {
  const _FavoriteWordPicker({required this.repository, required this.initial});
  final StoryLexRepository repository;
  final Map<int, FavoriteWord> initial;
  @override
  State<_FavoriteWordPicker> createState() => _FavoriteWordPickerState();
}

class _FavoriteWordPickerState extends State<_FavoriteWordPicker> {
  final _search = TextEditingController();
  final _selected = <int, FavoriteWord>{};
  Timer? _debounce;
  FavoritePageData? _pageData;
  bool _loading = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initial);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _page = page;
    });
    try {
      final data = await widget.repository.favorites(
        keyword: _search.text.trim(),
        page: _page,
      );
      if (mounted) {
        setState(() {
          _pageData = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '收藏词暂时无法读取。';
          _loading = false;
        });
      }
    }
  }

  void _searchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(page: 1));
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Journal.cream,
    insetPadding: const EdgeInsets.all(18),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 650),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('选择收藏单词', style: Journal.hand(23))),
                Text(
                  '${_selected.length}/20',
                  style: const TextStyle(color: Journal.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (_) => _searchChanged(),
              onSubmitted: (_) => _load(page: 1),
              decoration: const InputDecoration(
                hintText: '按英文搜索收藏词',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _pageData!.words.isEmpty
                  ? const Center(child: Text('没有找到收藏词。先在背词或阅读中收藏一些单词。'))
                  : ListView.separated(
                      itemCount: _pageData!.words.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final word = _pageData!.words[index];
                        final selected = _selected.containsKey(word.id);
                        return CheckboxListTile(
                          value: selected,
                          dense: true,
                          title: Text(
                            word.word,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            word.meaning,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: !selected && _selected.length >= 20
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    _selected[word.id] = word;
                                  } else {
                                    _selected.remove(word.id);
                                  }
                                }),
                        );
                      },
                    ),
            ),
            if (_pageData != null && _pageData!.pages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _page <= 1 || _loading
                        ? null
                        : () => _load(page: _page - 1),
                    child: const Text('上一页'),
                  ),
                  Text(
                    '$_page/${_pageData!.pages}',
                    style: const TextStyle(color: Journal.muted),
                  ),
                  TextButton(
                    onPressed: _page >= _pageData!.pages || _loading
                        ? null
                        : () => _load(page: _page + 1),
                    child: const Text('下一页'),
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    Map<int, FavoriteWord>.of(_selected),
                  ),
                  child: Text('完成（${_selected.length}）'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
