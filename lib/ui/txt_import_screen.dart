import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/story_repository.dart';
import '../data/models.dart';
import '../data/story_models.dart';
import '../state/app_controller.dart';
import 'journal.dart';

class TxtImportScreen extends StatefulWidget {
  const TxtImportScreen({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onSaved,
  });
  final AppController controller;
  final VoidCallback onBack, onSaved;

  @override
  State<TxtImportScreen> createState() => _TxtImportScreenState();
}

class _TxtImportScreenState extends State<TxtImportScreen> {
  static const _maxFileBytes = 200 * 1024;
  final _title = TextEditingController();
  final _maxReplacements = TextEditingController(text: '20');
  final _minGap = TextEditingController(text: '30');
  Uint8List? _bytes;
  String? _filename;
  StoryDraft? _draft;
  String? _requestId, _saveId, _error;
  bool _busy = false, _editing = false, _contentSaved = false;
  final _content = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _maxReplacements.dispose();
    _minGap.dispose();
    _content.dispose();
    super.dispose();
  }

  void _inputsChanged() {
    if (_busy || _draft != null) return;
    _requestId = null;
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
      );
      if (!mounted || files.isEmpty) return;
      final file = files.single;
      if (!file.name.toLowerCase().endsWith('.txt')) {
        setState(() => _error = '请选择 .txt 文件。');
        return;
      }
      final size = await file.length();
      if (size != null && size > _maxFileBytes) {
        setState(() => _error = '文件不能超过 200KB，请拆分后再导入。');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxFileBytes) {
        setState(() => _error = '文件不能超过 200KB，请拆分后再导入。');
        return;
      }
      if (bytes.isEmpty) {
        setState(() => _error = '没有读取到文件内容，请重新选择。');
        return;
      }
      setState(() {
        _bytes = bytes;
        _filename = file.name;
        _draft = null;
        _requestId = null;
        _saveId = null;
        _error = null;
        _title.clear();
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? '文件读取失败，请重试。');
    } catch (_) {
      if (mounted) setState(() => _error = '文件读取失败，请重试。');
    }
  }

  Future<void> _createPreview() async {
    if (_busy) return;
    final bytes = _bytes;
    final filename = _filename;
    if (bytes == null || filename == null) {
      setState(() => _error = '请先选择一个 TXT 文件。');
      return;
    }
    final maxReplacements = int.tryParse(_maxReplacements.text.trim());
    final minGap = int.tryParse(_minGap.text.trim());
    if (maxReplacements == null ||
        maxReplacements < 1 ||
        maxReplacements > 100) {
      setState(() => _error = '替换次数请填写 1～100 的整数。');
      return;
    }
    if (minGap == null || minGap < 0 || minGap > 1000) {
      setState(() => _error = '替换间隔请填写 0～1000 的整数。');
      return;
    }
    final bookId = widget.controller.home?.catalog.currentId;
    if (bookId == null || bookId.isEmpty) {
      setState(() => _error = '当前没有可用词书，请先在首页设置主修词书。');
      return;
    }
    _requestId ??= newRequestId();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.controller.repository.importTxtDraft(
        bytes: bytes,
        filename: filename,
        targetBookId: bookId,
        requestId: _requestId!,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        maxReplacements: maxReplacements,
        minGap: minGap,
      );
      if (!mounted) return;
      _content.text = draft.content;
      setState(() {
        _draft = draft;
        _editing = false;
        _contentSaved = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : '导入预览失败，请重试。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || draft.status != 'ready' || _busy) return;
    final title = _title.text.trim().isEmpty ? draft.title : _title.text.trim();
    if (title.isEmpty || title.length > 150) {
      setState(() => _error = '标题需要填写，且不能超过 150 个字符。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var latest = draft;
      final changed = title != draft.title || _content.text != draft.content;
      if (changed && !_contentSaved) {
        latest = await widget.controller.repository.editStoryDraft(
          draft.id,
          version: draft.version,
          title: title,
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
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : '保存失败，请重试。');
      }
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
            TextButton.icon(
              onPressed: _busy ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('返回文章库'),
            ),
            const SizedBox(height: 8),
            Text('导入 TXT 文章', style: Journal.hand(32)),
            const SizedBox(height: 5),
            const Text(
              '用当前词书里的中文释义替换文章中的词语，先预览检查，再保存到我的书库。',
              style: TextStyle(color: Journal.muted),
            ),
            const SizedBox(height: 22),
            if (_error != null) ...[
              ErrorNote(_error!),
              const SizedBox(height: 12),
            ],
            if (draft == null)
              _form()
            else if (draft.status == 'ready')
              _previewPanel(draft)
            else
              Paper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('草稿状态：${draft.status}', style: Journal.hand(20)),
                    const SizedBox(height: 12),
                    WaitButton(
                      text: '重新读取预览',
                      busy: _busy,
                      onPressed: _busy ? null : _createPreview,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _form() => Paper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择文件和替换规则', style: Journal.hand(22)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickFile,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(_filename == null ? '选择 TXT 文件' : '更换 TXT 文件'),
        ),
        if (_filename != null) ...[
          const SizedBox(height: 9),
          Text(
            '$_filename · ${(_bytes?.length ?? 0) ~/ 1024} KB',
            style: const TextStyle(color: Journal.muted),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          enabled: !_busy,
          maxLength: 150,
          onChanged: (_) => _inputsChanged(),
          decoration: const InputDecoration(
            labelText: '文章标题（可选，默认使用文件名）',
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            final maxField = TextField(
              controller: _maxReplacements,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _inputsChanged(),
              decoration: const InputDecoration(
                labelText: '最多替换次数（1～100）',
                helperText: '默认 20 次',
              ),
            );
            final gapField = TextField(
              controller: _minGap,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _inputsChanged(),
              decoration: const InputDecoration(
                labelText: '两次替换至少间隔（0～1000字）',
                helperText: '默认 30 字，设为 0 表示不限制',
              ),
            );
            if (narrow) {
              return Column(
                children: [maxField, const SizedBox(height: 8), gapField],
              );
            }
            return Row(
              children: [
                Expanded(child: maxField),
                const SizedBox(width: 16),
                Expanded(child: gapField),
              ],
            );
          },
        ),
        const SizedBox(height: 15),
        Text(
          '目标词书：${_currentBookTitle()}',
          style: const TextStyle(
            color: Journal.green,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 17),
        WaitButton(
          text: _busy ? '正在上传并生成预览…' : '生成替换预览 →',
          busy: _busy,
          onPressed: _busy ? null : _createPreview,
        ),
        const SizedBox(height: 11),
        const Text(
          '只支持 200KB 以内的 .txt 文件。替换按词书释义字面匹配，不会调用 AI；请预览检查词义和句子是否合适。',
          style: TextStyle(fontSize: 12, height: 1.6, color: Journal.muted),
        ),
      ],
    ),
  );

  String _currentBookTitle() {
    final catalog = widget.controller.home?.catalog;
    if (catalog == null) return '未设置';
    for (final book in catalog.books) {
      if (book.id == catalog.currentId) return book.title;
    }
    return catalog.currentId;
  }

  Widget _previewPanel(StoryDraft draft) {
    final replacements = draft.importInfo['replacements'] is List
        ? draft.importInfo['replacements'] as List
        : const [];
    final words = {
      for (final word in draft.targetWords)
        number(word['word_id']): word['word']?.toString() ?? '',
    };
    final missing = draft.missingWordIds
        .map((id) => words[id] ?? '$id')
        .toList();
    final mobile = JournalLayout.of(context).mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Paper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('替换预览', style: Journal.hand(23))),
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
              const SizedBox(height: 9),
              Text(
                '自动替换 ${draft.embeddedOccurrences} 处，涉及 ${draft.wordIds.length} 个单词。',
                style: const TextStyle(color: Journal.muted),
              ),
              if (draft.importInfo['notice'] is String) ...[
                const SizedBox(height: 8),
                Text(
                  draft.importInfo['notice'] as String,
                  style: const TextStyle(fontSize: 12, color: Journal.muted),
                ),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 10),
                title: Text('查看原文（${draft.sourceContent.length} 字）'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      draft.sourceContent,
                      style: const TextStyle(height: 1.8),
                    ),
                  ),
                ],
              ),
              if (replacements.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('替换记录', style: Journal.hand(18)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: [
                    for (final item in replacements)
                      _replacementChip(object(item)),
                  ],
                ),
              ],
              const SizedBox(height: 17),
              if (_editing) ...[
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: '文章标题',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _content,
                  enabled: !_busy,
                  minLines: 12,
                  maxLines: 28,
                  maxLength: 50000,
                  decoration: const InputDecoration(
                    labelText: '替换后的正文与单词标记',
                    helperText:
                        '只能编辑文字和已有的 <word id="数字">英文词</word> 标记；至少保留一个标记。',
                    alignLabelWithHint: true,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _contentSaved = false),
                ),
              ] else ...[
                Text(draft.title, style: Journal.hand(mobile ? 25 : 30)),
                const SizedBox(height: 15),
                _renderContent(_content.text, words),
              ],
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 15),
                Text(
                  '已移除的目标词：${missing.join('、')}。',
                  style: const TextStyle(color: Journal.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
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
                      text: '确认保存到书库',
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
          '保存后会出现在“我的书库 → 导入”。不会自动标记已读、收藏或加入复习。',
          style: TextStyle(fontSize: 12, color: Journal.muted),
        ),
      ],
    );
  }

  Widget _replacementChip(Json item) {
    final alternatives = item['candidate_word_ids'] is List
        ? (item['candidate_word_ids'] as List).length
        : 1;
    final chip = Chip(
      backgroundColor: Journal.sage,
      label: Text('${item['chinese'] ?? ''} → ${item['word'] ?? ''}'),
    );
    return alternatives > 1
        ? Tooltip(message: '该中文释义对应多个单词，已按词书顺序选择其中一个。', child: chip)
        : chip;
  }

  Widget _renderContent(String content, Map<int, String> words) {
    final document = StoryDocument(content);
    if (document.paragraphs.isEmpty) {
      return const Text('预览内容为空。', style: TextStyle(color: Journal.muted));
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
