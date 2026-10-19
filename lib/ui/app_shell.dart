import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'books_screen.dart';
import 'home_screen.dart';
import 'journal.dart';
import 'journal_nav.dart';
import 'journal_art.dart';
import 'library_screen.dart';
import 'reading_screen.dart';
import 'learn_screen.dart';
import 'review_screen.dart';
import 'favorites_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _page = '首页';
  int _navigationRevision = 0;
  final _learnKey = GlobalKey<LearnScreenState>();
  final _reviewKey = GlobalKey<LearnScreenState>();
  @override
  void initState() {
    super.initState();
    _restoreLearning();
  }

  Future<void> _restoreLearning() async {
    final token = widget.controller.session?.token,
        revision = _navigationRevision;
    try {
      final checkpoint = await widget.controller.learningStore.read();
      if (!mounted ||
          widget.controller.session?.token != token ||
          revision != _navigationRevision)
        return;
      final owner = checkpoint?['owner'];
      if (checkpoint?['open'] == true && _page == '首页') {
        if (owner == widget.controller.learningOwner) {
          setState(() => _page = '单词学习');
        } else if (owner == '${widget.controller.learningOwner}:review') {
          setState(() => _page = '复习练习');
        }
      }
    } catch (_) {}
  }

  bool _books = false, _leavingReader = false, _resumeReader = false;
  int? _storyId;
  int _libraryRevision = 0;
  String _readerReturn = '文章库';
  final _readerKey = GlobalKey<ReadingScreenState>();
  static const _labels = ['首页', '文章库', '复习', '个人中心'];
  static const _icons = [
    Icons.cottage_outlined,
    Icons.menu_book_outlined,
    Icons.history,
    Icons.person_outline,
  ];
  Future<void> _openBooks() async {
    _navigationRevision++;
    if (_storyId != null) await _leaveReader(destination: '文章库');
    if (!mounted) return;
    if (await widget.controller.loadBooks() && mounted) {
      setState(() => _books = true);
    }
  }

  void _openStory(int id, {bool fromHome = false}) => setState(() {
    _navigationRevision++;
    _readerReturn = fromHome ? '首页' : '文章库';
    _resumeReader = fromHome;
    _storyId = id;
    _page = '文章库';
    _books = false;
  });
  Future<void> _leaveReader({String? destination}) async {
    if (_leavingReader) return;
    _leavingReader = true;
    try {
      await _readerKey.currentState?.flushBeforeLeaving();
      if (!mounted) return;
      setState(() {
        _storyId = null;
        _page = destination ?? _readerReturn;
        _libraryRevision++;
      });
      widget.controller.refreshHome();
    } finally {
      _leavingReader = false;
    }
  }

  Future<void> _open(String label) async {
    final revision = ++_navigationRevision;
    final leavingStudy = (_page == '单词学习' || _page == '复习练习') && label != _page;
    if (leavingStudy) {
      if (_page == '复习练习') {
        await _reviewKey.currentState?.pauseBeforeLeaving();
      } else {
        await _learnKey.currentState?.pauseBeforeLeaving();
      }
      if (!mounted || revision != _navigationRevision) return;
    }
    if (label == '单词复习') {
      setState(() => _page = '复习练习');
      return;
    }
    if (label == '文章阅读') {
      final story = widget.controller.home?.dashboard.lastStory;
      if (story != null) _openStory(story.id, fromHome: true);
      return;
    }
    if (_storyId != null) {
      _leaveReader(destination: label);
      return;
    }
    setState(() {
      _page = label;
      _books = false;
    });
    if (leavingStudy) widget.controller.refreshHome();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller,
        wide = !JournalLayout.of(context).mobile;
    final studying = (_page == '单词学习' || _page == '复习练习') && !_books;
    final selected = _page == '复习练习' ? 2 : _labels.indexOf(_page);
    Widget body;
    if (_books) {
      body = BooksScreen(
        controller: controller,
        onCancel: () => setState(() => _books = false),
        onDone: () => setState(() {
          _books = false;
          _page = '首页';
        }),
      );
    } else if (controller.home == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('手帐暂时没能打开', style: Journal.hand(28)),
                const SizedBox(height: 18),
                if (controller.error != null) ErrorNote(controller.error!),
                WaitButton(
                  text: '重新加载',
                  busy: controller.busy,
                  onPressed: controller.refreshHome,
                ),
                TextButton(
                  onPressed: controller.logout,
                  child: const Text('退出当前账号'),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_page == '首页') {
      body = HomeScreen(
        controller: controller,
        openBooks: _openBooks,
        openFeature: _open,
      );
    } else if (_page == '单词学习') {
      body = Align(
        alignment: Alignment.topCenter,
        child: LearnScreen(
          key: _learnKey,
          controller: controller,
          onBack: () => _open('首页'),
        ),
      );
    } else if (_page == '复习') {
      body = ReviewScreen(
        controller: controller,
        start: () => setState(() => _page = '复习练习'),
      );
    } else if (_page == '复习练习') {
      body = Align(
        alignment: Alignment.topCenter,
        child: LearnScreen(
          key: _reviewKey,
          controller: controller,
          reviewMode: true,
          onBack: () => _open('复习'),
        ),
      );
    } else if (_page == '文章库') {
      body = Stack(
        children: [
          Offstage(
            offstage: _storyId != null,
            child: LibraryScreen(
              key: const ValueKey('library'),
              controller: controller,
              revision: _libraryRevision,
              openStory: (id) => _openStory(id),
            ),
          ),
          if (_storyId != null)
            ReadingScreen(
              key: _readerKey,
              controller: controller,
              storyId: _storyId!,
              resumePosition: _resumeReader,
              onBack: () => _leaveReader(),
              backLabel: '返回$_readerReturn',
            ),
        ],
      );
    } else if (_page == '我的收藏') {
      body = FavoritesScreen(controller: controller);
    } else if (_page == '个人中心') {
      body = _profile();
    } else {
      body = SingleChildScrollView(
        child: PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => _open('首页'),
                icon: const Icon(Icons.arrow_back, size: 17),
                label: const Text('返回首页'),
              ),
              const SizedBox(height: 14),
              Text(_page, style: Journal.hand(32)),
              const SizedBox(height: 28),
              const Paper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 36,
                      color: Journal.muted,
                    ),
                    SizedBox(height: 16),
                    Text('这一页，还在准备中。', style: TextStyle(fontSize: 19)),
                    SizedBox(height: 10),
                    Text(
                      '页面接通后，你就可以在这里继续学习。',
                      style: TextStyle(color: Journal.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: _storyId == null && !studying,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _storyId != null) _leaveReader();
        if (!didPop && studying) _open(_page == '复习练习' ? '复习' : '首页');
      },
      child: Scaffold(
        appBar: wide || studying
            ? null
            : AppBar(
                toolbarHeight: 52,
                backgroundColor: Journal.cream,
                surfaceTintColor: Colors.transparent,
                title: const Text(
                  'StoryLex',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
                ),
                actions: [
                  IconButton(
                    onPressed: () => _open('个人中心'),
                    tooltip: '个人中心',
                    icon: const Icon(Icons.person_outline),
                  ),
                ],
              ),
        body: SafeArea(
          top: !wide,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1620),
              child: Row(
                children: [
                  if (wide) _sidebar(),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: wide || studying
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Journal.paper,
                  border: Border(top: BorderSide(color: Journal.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      for (var i = 0; i < _labels.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: JournalNav(
                              label: i == 3 ? '我的' : _labels[i],
                              icon: _icons[i],
                              compact: true,
                              selected:
                                  selected == i || (selected < 0 && i == 3),
                              onTap: () => _open(_labels[i]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _sidebar() => Container(
    width: JournalLayout.of(context).sidebar,
    padding: EdgeInsets.symmetric(
      horizontal: JournalLayout.of(context).sidebarX,
      vertical: JournalLayout.of(context).sidebarY,
    ),
    decoration: const BoxDecoration(
      color: Color(0xFFFCFAF6),
      border: Border(right: BorderSide(color: Color(0xFFEAE3D4))),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 680;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _open('首页'),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: const Color(0xFFAE9C82),
                    size: JournalLayout.of(context).tablet ? 22 : 25,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'StoryLex',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: JournalLayout.of(context).tablet
                            ? 21
                            : (JournalLayout.of(context).medium ? 23 : 25),
                        height: 1.6,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: compact ? (constraints.maxHeight < 500 ? 16 : 24) : 52,
            ),
            for (var i = 0; i < _labels.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: compact
                      ? 8
                      : (JournalLayout.of(context).tablet ? 16 : 18),
                ),
                child: _nav(_labels[i], _icons[i]),
              ),
            SizedBox(
              height: compact ? 16 : 32,
              child: const Center(child: Divider(height: 1)),
            ),
            _nav('我的收藏', Icons.star_border_rounded),
            const Spacer(),
            if (constraints.maxHeight >= 560) ...[
              Center(
                child: SizedBox(
                  width: compact ? 60 : 95,
                  height: compact ? 48 : 76,
                  child: const JournalBookArt(),
                ),
              ),
              SizedBox(height: compact ? 8 : 20),
            ],
            if (constraints.maxHeight >= 500)
              Text(
                '一页一页，慢慢积累。',
                textAlign: TextAlign.center,
                style: Journal.hand(JournalLayout.of(context).tablet ? 12 : 14)
                    .copyWith(color: const Color(0xFFB5A88E)),
              ),
            SizedBox(height: compact ? 12 : 26),
            const Divider(),
            SizedBox(height: compact ? 8 : 15),
            Text(
              widget.controller.session!.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            const Text(
              '我的学习手帐',
              style: TextStyle(fontSize: 10, color: Journal.muted),
            ),
          ],
        );
      },
    ),
  );
  Widget _nav(String label, IconData icon) => JournalNav(
    label: label,
    icon: icon,
    selected: (_page == label || (_page == '单词学习' && label == '首页')) && !_books,
    onTap: () => _open(label),
  );

  Widget _profile() {
    final data = widget.controller.home!,
        stats = data.stats,
        book = data.currentBook;
    return SingleChildScrollView(
      child: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('个人中心', style: Journal.hand(32)),
            const SizedBox(height: 25),
            Paper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Journal.sage,
                    foregroundColor: Journal.green,
                    child: Icon(Icons.person_outline),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.controller.session!.username,
                    style: Journal.hand(27),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 30,
                    runSpacing: 18,
                    children: [
                      _number('${stats.days}', '累计学习天数'),
                      _number('${stats.learned}', '全局已学单词'),
                      _number('${stats.mastered}', '全局已掌握单词'),
                      _number('${stats.read}', '已读文章'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Paper(
              tape: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前主修词书', style: Journal.hand(23)),
                  const SizedBox(height: 10),
                  Text(
                    data.dashboard.bookTitle,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  if (book != null)
                    Text(
                      '本词书已学 ${book.learned} / ${book.total} 词',
                      style: const TextStyle(color: Journal.muted),
                    ),
                  const SizedBox(height: 15),
                  OutlinedButton(
                    onPressed: widget.controller.busy ? null : _openBooks,
                    child: const Text('切换主修词书 →'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 15,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _open('我的收藏'),
                  icon: const Icon(Icons.star_border),
                  label: const Text('我的收藏'),
                ),
                OutlinedButton(
                  onPressed: widget.controller.busy
                      ? null
                      : () => editTarget(context, widget.controller, false),
                  child: const Text('每日新学目标'),
                ),
                OutlinedButton(
                  onPressed: widget.controller.busy
                      ? null
                      : () => editTarget(context, widget.controller, true),
                  child: const Text('每日复习目标'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: widget.controller.logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _number(String value, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: Journal.hand(31)),
      Text(title, style: const TextStyle(fontSize: 12, color: Journal.muted)),
    ],
  );
}
