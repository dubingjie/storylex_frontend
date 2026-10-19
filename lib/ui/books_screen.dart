import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_controller.dart';
import 'journal.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({
    super.key,
    required this.controller,
    required this.onDone,
    this.onCancel,
  });
  final AppController controller;
  final VoidCallback onDone;
  final VoidCallback? onCancel;
  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  String? _selected;
  Future<void> _save() async {
    final id = _selected ?? widget.controller.catalog?.currentId;
    if (id == null) return;
    if (await widget.controller.chooseBook(id) && mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller, catalog = controller.catalog;
    final selected = _selected ?? catalog?.currentId;
    return SingleChildScrollView(
      child: PageFrame(
        width: 1020,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.onCancel != null)
              TextButton.icon(
                onPressed: controller.busy ? null : widget.onCancel,
                icon: const Icon(Icons.arrow_back, size: 17),
                label: const Text('返回'),
              ),
            Text('选一本，开始慢慢积累。', style: Journal.hand(32)),
            const SizedBox(height: 10),
            const Text(
              '先确定这段时间想学的词书，以后也可以切换。',
              style: TextStyle(color: Journal.muted),
            ),
            const SizedBox(height: 28),
            if (controller.error != null) ErrorNote(controller.error!),
            if (catalog == null)
              Center(
                child: Column(
                  children: [
                    const Text('词书暂未加载完成'),
                    TextButton(
                      onPressed: controller.busy ? null : controller.loadBooks,
                      child: const Text('重新加载'),
                    ),
                  ],
                ),
              )
            else if (catalog.books.isEmpty)
              const Paper(child: Text('暂时没有可选择的词书，请稍后重试。'))
            else
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth > 650 ? 2 : 1;
                  final width = (box.maxWidth - 22 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 22,
                    runSpacing: 22,
                    children: [
                      for (var i = 0; i < catalog.books.length; i++)
                        SizedBox(
                          width: width,
                          child: _book(catalog.books[i], selected, i),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EDDF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '切换词书会保留学习记录。全局已学、已掌握数量不会清零。',
                style: TextStyle(fontSize: 12, color: Journal.muted),
              ),
            ),
            const SizedBox(height: 22),
            WaitButton(
              text: '选好了，进入首页 →',
              busy: controller.busy,
              onPressed:
                  catalog == null ||
                      !catalog.books.any((b) => b.id == selected && b.total > 0)
                  ? null
                  : _save,
            ),
            const SizedBox(height: 24),
            if (widget.onCancel == null)
              TextButton(
                onPressed: controller.busy ? null : controller.logout,
                child: const Text('退出当前账号'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _book(Book book, String? selected, int index) {
    final chosen = selected == book.id,
        enabled = book.total > 0 && !widget.controller.busy;
    return Semantics(
      button: true,
      selected: chosen,
      label: '${book.title}，${book.total}词',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => setState(() => _selected = book.id) : null,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Journal.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: chosen ? const Color(0xFFA7B987) : Journal.line,
              width: chosen ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 126,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? const Color(0xFFE9DDB7)
                          : const Color(0xFFD6DFC5),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(9),
                      ),
                      border: const Border(
                        left: BorderSide(color: Color(0xFFB9AD87), width: 5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const FittedBox(
                          child: Text(
                            'STORYLEX',
                            style: TextStyle(fontSize: 9, letterSpacing: 1),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                book.id.startsWith('CET')
                                    ? book.id.split('luan').first
                                    : '词\n书',
                                style: Journal.hand(25),
                              ),
                            ),
                          ),
                        ),
                        const FittedBox(
                          child: Text(
                            'WORD JOURNAL',
                            style: TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    chosen
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: enabled || chosen ? Journal.green : Journal.muted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                book.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (book.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    book.description,
                    style: const TextStyle(fontSize: 12, color: Journal.muted),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                book.total == 0
                    ? '词书暂无单词'
                    : '共 ${book.total} 词 · 已学 ${book.learned} 词',
                style: const TextStyle(fontSize: 12, color: Journal.muted),
              ),
              if (book.id == widget.controller.catalog?.currentId)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '当前主修',
                    style: TextStyle(fontSize: 11, color: Journal.green),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
