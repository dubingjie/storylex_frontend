import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/story_repository.dart';
import '../data/story_models.dart';
import '../state/app_controller.dart';
import 'journal.dart';
import 'journal_art.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.openStory,
    this.revision = 0,
  });
  final AppController controller;
  final ValueChanged<int> openStory;
  final int revision;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _favoritesBusy = <int>{};
  late final String? _token = widget.controller.session?.token;
  Timer? _debounce;
  String _category = 'all', _keyword = '';
  int _minePage = 1, _recommendedPage = 1, _generation = 0;
  bool _busy = true;
  String? _error;
  StoryPage? _mine, _recommended;
  bool get _alive => mounted && widget.controller.session?.token == _token;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool clear = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      if (clear) {
        _mine = null;
        _recommended = null;
      }
    });
    try {
      final pages = await Future.wait([
        widget.controller.repository.stories(
          scope: 'mine',
          category: _category,
          keyword: _keyword,
          page: _minePage,
        ),
        widget.controller.repository.stories(
          scope: 'recommended',
          keyword: _keyword,
          page: _recommendedPage,
        ),
      ]);
      if (!_alive || generation != _generation) return;
      if (_minePage > pages[0].pages || _recommendedPage > pages[1].pages) {
        _minePage = math.min(_minePage, pages[0].pages);
        _recommendedPage = math.min(_recommendedPage, pages[1].pages);
        await _load(clear: true);
        return;
      }
      setState(() {
        _mine = pages[0];
        _recommended = pages[1];
      });
    } catch (e) {
      if (_alive && generation == _generation)
        setState(
          () => _error = e is ApiException ? e.message : '文章暂时没能加载，请重试。',
        );
    } finally {
      if (_alive && generation == _generation) setState(() => _busy = false);
    }
  }

  void _searchChanged(String text, {bool immediately = false}) {
    _debounce?.cancel();
    void apply() {
      if (!_alive) return;
      _keyword = text.trim();
      _minePage = 1;
      _recommendedPage = 1;
      _load(clear: true);
    }

    if (immediately) {
      apply();
    } else {
      _debounce = Timer(const Duration(milliseconds: 350), apply);
    }
  }

  Future<void> _favorite(StoryCardData story) async {
    if (_favoritesBusy.contains(story.id)) return;
    setState(() => _favoritesBusy.add(story.id));
    try {
      final value = await widget.controller.repository.favoriteStory(
        story.id,
        !story.favorite,
      );
      if (!_alive) return;
      setState(() => story.favorite = value);
      await _load();
    } catch (e) {
      if (_alive)
        showNote(context, e is ApiException ? e.message : '收藏未能保存，请重试。');
    } finally {
      if (_alive) setState(() => _favoritesBusy.remove(story.id));
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('library-scroll'),
    controller: _scroll,
    child: PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '文章库',
            style: Journal.hand(JournalLayout.of(context).mobile ? 28 : 33),
          ),
          const SizedBox(height: 7),
          const Text(
            '喜欢的故事，留在这里慢慢读。',
            style: TextStyle(fontSize: 12, color: Journal.muted),
          ),
          const SizedBox(height: 27),
          Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: TextField(
                    controller: _search,
                    maxLength: 150,
                    decoration: InputDecoration(
                      hintText: '搜索文章标题',
                      counterText: '',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除搜索',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _search.clear();
                                _searchChanged('', immediately: true);
                                setState(() {});
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Journal.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFFC7AE74),
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _searchChanged(value);
                    },
                    onSubmitted: (value) =>
                        _searchChanged(value, immediately: true),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _busy ? null : () => _load(),
                tooltip: '刷新文章库',
                icon: const Icon(Icons.refresh, color: Journal.green),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (_error != null) ...[
            ErrorNote(_error!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _load(),
                child: const Text('重新加载文章'),
              ),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 22),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          _heading('我的书库', _mine),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in const {
                'all': '全部',
                'imported': '导入',
                'ai_generated': 'AI 生成',
                'favorites': '收藏',
              }.entries)
                ChoiceChip(
                  label: Text(item.value),
                  showCheckmark: false,
                  shape: const StadiumBorder(),
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  labelStyle: const TextStyle(fontSize: 12, color: Journal.ink),
                  selected: _category == item.key,
                  selectedColor: Journal.yellow,
                  backgroundColor: Journal.paper,
                  side: const BorderSide(color: Journal.line),
                  onSelected: (_) {
                    if (_category == item.key) return;
                    setState(() => _category = item.key);
                    _minePage = 1;
                    _load(clear: true);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_mine != null) ...[_cards(_mine!), _pagination(_mine!, false)],
          const SizedBox(height: 35),
          _heading('系统推荐文章', _recommended),
          const SizedBox(height: 20),
          if (_recommended != null) ...[
            _cards(_recommended!, recommended: true),
            _pagination(_recommended!, true),
          ],
          const SizedBox(height: 25),
        ],
      ),
    ),
  );
  Widget _heading(String title, StoryPage? page) => Row(
    children: [
      Expanded(child: Text(title, style: Journal.hand(24))),
      Text(
        page == null ? '—' : '${page.total} 篇',
        style: const TextStyle(fontSize: 12, color: Journal.muted),
      ),
    ],
  );
  Widget _cards(StoryPage page, {bool recommended = false}) {
    if (page.stories.isEmpty)
      return Paper(
        tape: false,
        child: Column(
          children: [
            const Icon(
              Icons.auto_stories_outlined,
              color: Journal.muted,
              size: 34,
            ),
            const SizedBox(height: 13),
            Text(
              _keyword.isNotEmpty ? '没有找到这篇故事' : '这里还没有故事',
              style: Journal.hand(22),
            ),
            const SizedBox(height: 8),
            Text(
              _keyword.isNotEmpty
                  ? '试试其他标题，或清除筛选。'
                  : recommended
                  ? '系统还没有推荐文章。'
                  : '你导入、生成或收藏的文章会放在这里。',
              style: const TextStyle(fontSize: 12, color: Journal.muted),
            ),
            if (_keyword.isNotEmpty || (!recommended && _category != 'all'))
              TextButton(
                onPressed: () {
                  _search.clear();
                  setState(() => _category = 'all');
                  _searchChanged('', immediately: true);
                },
                child: const Text('清除筛选'),
              ),
          ],
        ),
      );
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth > 900 && recommended
            ? 3
            : box.maxWidth > 700
            ? 2
            : 1;
        final width = (box.maxWidth - 18 * (columns - 1)) / columns;
        return Wrap(
          spacing: 18,
          runSpacing: 20,
          children: [
            for (final story in page.stories)
              SizedBox(width: width, child: _card(story, recommended)),
          ],
        );
      },
    );
  }

  Widget _card(StoryCardData story, bool recommended) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Journal.paper,
      border: Border.all(color: Journal.line),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(color: Color(0x60E3DEC7), offset: Offset(0, 3)),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 14),
          child: Transform.rotate(
            angle: recommended ? -.045 : .035,
            child: SizedBox(
              width: JournalLayout.of(context).mobile ? 48 : 57,
              height: JournalLayout.of(context).mobile ? 72 : 86,
              child: const JournalBookArt(cover: true),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      storySource(story.source),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Journal.muted,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy || _favoritesBusy.contains(story.id)
                        ? null
                        : () => _favorite(story),
                    tooltip:
                        '${story.favorite ? '取消收藏' : '收藏'}文章《${story.title}》',
                    icon: Icon(
                      story.favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: const Color(0xFFBB9299),
                    ),
                  ),
                ],
              ),
              Text(story.title, style: Journal.hand(21)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 5,
                children: [
                  Text(
                    '${story.words} 个生词',
                    style: const TextStyle(fontSize: 11, color: Journal.muted),
                  ),
                  Text(
                    '${story.length} 字',
                    style: const TextStyle(fontSize: 11, color: Journal.muted),
                  ),
                  Text(
                    story.completed ? '已阅读' : '未读完',
                    style: const TextStyle(fontSize: 11, color: Journal.green),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => widget.openStory(story.id),
                child: Text('${story.completed ? '再读一遍' : '开始阅读'}  →'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _pagination(StoryPage page, bool recommended) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        TextButton(
          onPressed: _busy || page.page <= 1
              ? null
              : () {
                  if (recommended) {
                    _recommendedPage--;
                  } else {
                    _minePage--;
                  }
                  _load();
                },
          child: Text(recommended ? '推荐上一页' : '上一页'),
        ),
        Text(
          '${page.page} / ${page.pages}',
          style: const TextStyle(fontSize: 12, color: Journal.muted),
        ),
        TextButton(
          onPressed: _busy || page.page >= page.pages
              ? null
              : () {
                  if (recommended) {
                    _recommendedPage++;
                  } else {
                    _minePage++;
                  }
                  _load();
                },
          child: Text(recommended ? '推荐下一页' : '下一页'),
        ),
      ],
    ),
  );
}
