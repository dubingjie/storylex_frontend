import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../state/app_controller.dart';
import 'journal.dart';
import 'journal_art.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.openBooks,
    required this.openFeature,
  });
  final AppController controller;
  final VoidCallback openBooks;
  final void Function(String) openFeature;
  @override
  Widget build(BuildContext context) {
    final data = controller.home!;
    final layout = JournalLayout.of(context);
    return RefreshIndicator(
      onRefresh: controller.refreshHome,
      color: Journal.green,
      backgroundColor: Journal.paper,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: PageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.error != null) ErrorNote(controller.error!),
              if (controller.notice != null) ErrorNote(controller.notice!),
              Paper(
                padding: layout.sheetPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _JournalHeader(),
                    _DailyProgress(
                      learn: data.dashboard.learn,
                      review: data.dashboard.review,
                    ),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, box) {
                        final compact = box.maxWidth < 480;
                        return Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: -4,
                                      bottom: 1,
                                      child: Transform.rotate(
                                        angle: -.017,
                                        child: Container(
                                          height: 7,
                                          color: const Color(0xFFF8EDC8),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '今天的小计划',
                                      style:
                                          Journal.hand(
                                            layout.tiny
                                                ? 19
                                                : (layout.tablet ? 21 : 23),
                                          ).copyWith(
                                            color: const Color(0xFF78664B),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: compact ? 112 : 260,
                              ),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF847254),
                                  backgroundColor: const Color(0xFFFBF9F0),
                                  minimumSize: const Size(44, 44),
                                  visualDensity: VisualDensity.standard,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: controller.busy ? null : openBooks,
                                icon: Icon(
                                  Icons.menu_book_outlined,
                                  size: layout.tablet ? 11 : 13,
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '当前词书',
                                      style: TextStyle(
                                        fontSize: layout.tablet ? 8 : 10,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        data.dashboard.bookTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: layout.tablet ? 8 : 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.expand_more_rounded,
                                      size: layout.tablet ? 10 : 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 21),
                    LayoutBuilder(
                      builder: (context, box) {
                        final compact = box.maxWidth < 480;
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _task(
                                  context,
                                  data.dashboard.learn,
                                  false,
                                  compact: compact,
                                ),
                              ),
                              SizedBox(
                                width: layout.mobile
                                    ? 12
                                    : (layout.tablet ? 16 : 23),
                              ),
                              Expanded(
                                child: _task(
                                  context,
                                  data.dashboard.review,
                                  true,
                                  compact: compact,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Transform.rotate(
                              angle: -.035,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 21,
                                  vertical: 5,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF4DCE1),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(13),
                                    topRight: Radius.circular(7),
                                    bottomLeft: Radius.circular(3),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  '继续上次的故事',
                                  style: Journal.hand(layout.tablet ? 17 : 18)
                                      .copyWith(color: const Color(0xFFB38E92)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => openFeature('文章库'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF847254),
                            textStyle: const TextStyle(
                              fontFamily: 'JournalSans',
                              fontSize: 9,
                            ),
                          ),
                          child: const Text('去文章库 →'),
                        ),
                      ],
                    ),
                    _reading(data.dashboard.lastStory),
                    const SizedBox(height: 28),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.mobile ? 9 : 17,
                        vertical: layout.mobile ? 15 : 17,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF1E4),
                        border: Border.all(color: const Color(0xFFDCE3CC)),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: LayoutBuilder(
                        builder: (context, box) => Row(
                          children: [
                            _stat(
                              '累计学习',
                              data.stats.days,
                              '天',
                              const Color(0xFFFFFAF0),
                              (box.maxWidth - 30) / 3,
                              layout,
                            ),
                            const SizedBox(width: 15),
                            _stat(
                              '已学单词',
                              data.stats.learned,
                              '词',
                              const Color(0xFFFFF6ED),
                              (box.maxWidth - 30) / 3,
                              layout,
                            ),
                            const SizedBox(width: 15),
                            _stat(
                              '已读文章',
                              data.stats.read,
                              '篇',
                              Journal.pink,
                              (box.maxWidth - 30) / 3,
                              layout,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        '一页一页，慢慢积累。',
                        style: TextStyle(fontSize: 12, color: Journal.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: controller.busy ? null : controller.refreshHome,
                    icon: controller.busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 17),
                    label: const Text('刷新数据'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _task(
    BuildContext context,
    DailyTask task,
    bool review, {
    bool compact = false,
  }) {
    final layout = JournalLayout.of(context);
    final headingColor = review
        ? const Color(0xFF617148)
        : const Color(0xFF77613E);
    final captionColor = review
        ? const Color(0xFF617148)
        : const Color(0xFF826D49);
    final captionSize = layout.mobile
        ? (layout.tiny ? 7.0 : 8.0)
        : (layout.tablet ? 8.0 : 9.0);
    final headingSize = layout.mobile
        ? (layout.tiny ? 9.0 : 11.0)
        : (layout.tablet ? 11.0 : (layout.large ? 14.0 : 13.0));
    final countSize = layout.tiny
        ? 34.0
        : (layout.mobile ? 38.0 : (layout.tablet ? 41.0 : 46.0));
    final label = review ? '今日复习' : '新学单词';
    final button = task.canStart
        ? (review ? '开始复习' : '开始学习')
        : task.completed
        ? '今日目标已完成'
        : review
        ? '暂无到期单词'
        : '当前词书已学完';
    return Paper(
      color: review ? Journal.sage : Journal.yellow,
      padding: layout.mobile
          ? EdgeInsets.fromLTRB(
              layout.tiny ? 10 : 12,
              18,
              layout.tiny ? 10 : 12,
              15,
            )
          : layout.large
          ? const EdgeInsets.symmetric(horizontal: 28, vertical: 24)
          : layout.tablet
          ? const EdgeInsets.fromLTRB(16, 21, 16, 17)
          : layout.medium
          ? const EdgeInsets.all(20)
          : const EdgeInsets.fromLTRB(23, 22, 23, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: headingSize * 1.6,
            child: Row(
              children: [
                if (!layout.tiny) ...[
                  Icon(
                    review ? Icons.schedule_outlined : Icons.menu_book_outlined,
                    size: layout.mobile ? 13 : 18,
                    color: review
                        ? const Color(0xFFA0B58B)
                        : const Color(0xFFBCA077),
                  ),
                  SizedBox(width: layout.mobile ? 4 : 7),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: headingSize,
                      color: headingColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (review)
                  Text(
                    '温故知新',
                    style: Journal.hand(
                      layout.mobile ? (layout.tiny ? 7 : 9) : 11,
                    ).copyWith(color: const Color(0xFFB4C29D)),
                  )
                else
                  SizedBox(
                    width: layout.mobile ? (layout.tiny ? 43 : 48) : 55,
                    child: OverflowBox(
                      maxHeight: 44,
                      minHeight: 44,
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF847254),
                        ),
                        onPressed: controller.busy
                            ? null
                            : () => editTarget(context, controller, review),
                        child: Text(
                          '修改目标',
                          style: TextStyle(
                            fontSize: layout.mobile ? (layout.tiny ? 7 : 8) : 9,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: layout.mobile ? 18 : 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${review ? task.available : task.target}',
                            style: Journal.hand(countSize).copyWith(
                              height: 1.1,
                              letterSpacing: -1,
                              color: review
                                  ? const Color(0xFF84906A)
                                  : const Color(0xFF89734D),
                            ),
                          ),
                          TextSpan(
                            text: ' 词',
                            style: TextStyle(
                              fontSize: layout.mobile ? 8 : 11,
                              color: review
                                  ? const Color(0xFFA6B092)
                                  : const Color(0xFFB3A283),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      review ? '当前待复习' : '今日新学目标',
                      style: TextStyle(
                        fontSize: captionSize,
                        color: captionColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!layout.tiny)
                Transform.rotate(
                  angle: review ? -.14 : .157,
                  child: Container(
                    width: layout.mobile ? 26 : 38,
                    height: layout.mobile ? 26 : 38,
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x73FFFDF0),
                      border: Border.all(
                        color: review
                            ? const Color(0xFFC7D7B7)
                            : const Color(0xFFE5D49C),
                      ),
                    ),
                    child: Icon(
                      review ? Icons.eco_outlined : Icons.star_border_rounded,
                      size: layout.mobile ? 17 : 23,
                      color: review
                          ? const Color(0xFFA6BB90)
                          : const Color(0xFFD6BC74),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '已完成 ${task.finished} / ${task.target}',
                    style: TextStyle(
                      fontSize: captionSize,
                      color: captionColor,
                    ),
                  ),
                ),
              ),
              Text(
                '剩余 ${task.remaining} 词',
                style: TextStyle(fontSize: captionSize, color: captionColor),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: layout.mobile ? 5 : 6,
              color: review ? const Color(0xFFB0C591) : const Color(0xFFDBC483),
              backgroundColor: review
                  ? const Color(0xFFDCE7CE)
                  : const Color(0xFFEFE5C1),
              semanticsLabel: '$label进度',
              semanticsValue: '${(task.progress * 100).round()}',
            ),
          ),
          SizedBox(height: layout.mobile ? 15 : 17),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.symmetric(
                  horizontal: layout.mobile ? 5 : 10,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: review
                    ? const Color(0xFFDCE8CA)
                    : const Color(0xFFF4DFA2),
                foregroundColor: review
                    ? const Color(0xFF55693A)
                    : const Color(0xFF7A5C2D),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: review
                      ? const Color(0xFFC0D2A8)
                      : const Color(0xFFDFC385),
                ),
                textStyle: TextStyle(
                  fontFamily: 'JournalSans',
                  fontSize: layout.tiny ? 10 : (layout.tablet ? 11 : 12),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: !task.canStart || controller.busy
                  ? null
                  : () => openFeature(review ? '单词复习' : '单词学习'),
              child: Text(task.canStart ? '$button    →' : button),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reading(LastStory? story) => LayoutBuilder(
    builder: (context, box) {
      final l = JournalLayout.of(context);
      final compact = l.tablet;
      final title = Text(
        story?.title ?? '给今天留一页故事',
        style: Journal.hand(
          l.mobile
              ? (l.tiny ? 16 : 18)
              : l.large
              ? 24
              : l.medium
              ? 20
              : 22,
        ).copyWith(color: const Color(0xFF7D6B57)),
      );
      final button = FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 17),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: const Color(0xFFF4E2AC),
          foregroundColor: const Color(0xFF7A5C2D),
          side: const BorderSide(color: Color(0xFFE6CA8B)),
          textStyle: TextStyle(
            fontFamily: 'JournalSans',
            fontSize: l.mobile ? 10 : 11,
            fontWeight: FontWeight.w400,
          ),
        ),
        onPressed: () => openFeature(story == null ? '文章库' : '文章阅读'),
        child: Text(story == null ? '去文章库    →' : '继续阅读    →'),
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            story == null ? '下一页，新的故事' : '短篇故事 · 阅读中',
            style: TextStyle(
              fontSize: l.mobile ? 7 : 8,
              color: const Color(0xFF847254),
            ),
          ),
          const SizedBox(height: 4),
          title,
          const SizedBox(height: 7),
          Text(
            story == null ? '还没有未读完的文章。去文章库寻找下一篇喜欢的故事吧。' : '继续上次的阅读，从故事里积累单词。',
            style: TextStyle(
              fontSize: l.mobile ? 9 : 10,
              height: 1.8,
              color: const Color(0xFF847254),
            ),
          ),
          if (story != null) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: l.mobile ? 7 : 13,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${story.words} 个生词',
                  style: TextStyle(
                    fontSize: l.mobile ? 8 : 9,
                    color: const Color(0xFF847254),
                  ),
                ),
                SizedBox(
                  width: l.mobile ? 26 : 41,
                  child: LinearProgressIndicator(
                    value: (story.progress / 100).clamp(0, 1),
                    minHeight: 3,
                    color: const Color(0xFFB4C497),
                    backgroundColor: const Color(0xFFE5EADB),
                  ),
                ),
                Text(
                  '已读 ${story.progress.round()}%',
                  style: TextStyle(
                    fontSize: l.mobile ? 8 : 9,
                    color: const Color(0xFF66774B),
                  ),
                ),
              ],
            ),
          ],
          if (compact) ...[const SizedBox(height: 12), button],
        ],
      );
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: l.mobile ? 0 : 158),
        padding: EdgeInsets.all(l.mobile ? 13 : 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF6),
          border: Border.all(color: const Color(0xFFEADFBC)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0xFFFCF7DF), spreadRadius: 3),
            BoxShadow(
              color: Color(0x35E1D7BC),
              offset: Offset(0, 3),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: -.07,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                padding: const EdgeInsets.all(4),
                color: Journal.paper,
                child: SizedBox(
                  width: l.mobile ? 45 : 64,
                  height: l.mobile ? 69 : 88,
                  child: const JournalBookArt(cover: true),
                ),
              ),
            ),
            SizedBox(width: l.mobile ? 11 : 19),
            Expanded(child: details),
            if (!compact) ...[const SizedBox(width: 19), button],
          ],
        ),
      );
    },
  );

  Widget _stat(
    String title,
    int value,
    String unit,
    Color color,
    double width,
    JournalLayout l,
  ) => Container(
    width: width,
    padding: EdgeInsets.symmetric(horizontal: 3, vertical: l.mobile ? 10 : 12),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: const Color(0xFFEEE6D3)),
      borderRadius: BorderRadius.circular(11),
      boxShadow: const [
        BoxShadow(color: Color(0x4DDDDCC6), offset: Offset(0, 2)),
      ],
    ),
    child: l.tablet
        ? Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Journal.hand(l.mobile ? (l.tiny ? 9 : 10) : 10)
                    .copyWith(color: const Color(0xFF847254)),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value $unit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B713C),
                  ),
                ),
              ),
            ],
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Journal.hand(l.large ? 16 : 14)
                      .copyWith(color: const Color(0xFF847254)),
                ),
                const SizedBox(width: 5),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B713C),
                  ),
                ),
                Text(
                  ' $unit',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF847254),
                  ),
                ),
              ],
            ),
          ),
  );
}

class _DailyProgress extends StatelessWidget {
  const _DailyProgress({required this.learn, required this.review});
  final DailyTask learn, review;
  @override
  Widget build(BuildContext context) {
    final layout = JournalLayout.of(context);
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_box_outlined,
          size: layout.mobile ? 15 : 17,
          color: const Color(0xFFC3A58D),
        ),
        const SizedBox(width: 7),
        Text(
          '今日进度',
          style: Journal.hand(layout.tiny ? 12 : 16)
              .copyWith(color: const Color(0xFF847254)),
        ),
      ],
    );
    final counts = [
      _count(layout, '新学', Icons.menu_book_outlined, learn),
      _count(layout, '复习', Icons.schedule_outlined, review),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: layout.tiny ? 14 : 17,
            horizontal: layout.tiny ? 9 : (layout.mobile ? 13 : 19),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            border: Border.all(color: Journal.line),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(10),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x75E7E0D5), offset: Offset(0, 3)),
            ],
          ),
          child: layout.mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: layout.tiny ? 9 : 13,
                      runSpacing: 6,
                      children: counts,
                    ),
                  ],
                )
              : Wrap(
                  spacing: layout.tablet ? 13 : 23,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [title, ...counts],
                ),
        ),
        Positioned(
          top: layout.mobile ? -8 : -10,
          left: layout.mobile ? 17 : 25,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -.087,
              child: Container(
                width: layout.mobile ? 39 : 46,
                height: layout.mobile ? 13 : 14,
                color: const Color(0x88EFE0AF),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _count(
    JournalLayout layout,
    String label,
    IconData icon,
    DailyTask task,
  ) {
    final size = layout.tiny
        ? 7.0
        : layout.mobile
        ? 8.0
        : layout.tablet
        ? 9.0
        : 11.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: layout.tiny
              ? 9
              : layout.mobile
              ? 11
              : 14,
          color: const Color(0xFF9BA880),
        ),
        SizedBox(width: layout.mobile ? 4 : 6),
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: size, color: const Color(0xFF847254)),
            children: [
              TextSpan(text: '$label  '),
              TextSpan(
                text: '${task.finished} / ${task.target}',
                style: const TextStyle(
                  color: Color(0xFF66774B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '  词'),
            ],
          ),
        ),
      ],
    );
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader();
  @override
  Widget build(BuildContext context) {
    final l = JournalLayout.of(context);
    final titleSize = l.mobile
        ? (l.tiny ? 24.0 : 27.0)
        : l.large
        ? 44.0
        : l.tablet
        ? 30.0
        : l.medium
        ? 34.0
        : 39.0;
    final subtitleSize = l.mobile
        ? (l.tiny ? 13.0 : 14.0)
        : l.large
        ? 20.0
        : l.tablet
        ? 16.0
        : 18.0;
    final imageWidth = l.mobile
        ? (l.tiny ? 102.0 : 116.0)
        : l.large
        ? 280.0
        : l.tablet
        ? 185.0
        : l.medium
        ? 210.0
        : 245.0;
    final imageHeight = l.mobile
        ? (l.tiny ? 81.0 : 91.0)
        : l.large
        ? 192.0
        : l.tablet
        ? 140.0
        : l.medium
        ? 156.0
        : 174.0;
    final titleTop = l.mobile ? 7.0 : 6.0;
    final subtitleTop = titleTop + titleSize * 1.5 + (l.mobile ? 7 : 8);
    return SizedBox(
      height: l.mobile
          ? (l.tiny ? 116 : 122)
          : l.large
          ? 186
          : l.medium
          ? 165
          : 167,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: l.mobile
                ? -5
                : l.tablet
                ? -14
                : l.medium
                ? -10
                : -3,
            bottom: l.mobile
                ? -1
                : l.tablet
                ? -6
                : -3,
            child: Image.asset(
              'assets/images/journal-elephant.png',
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: 0,
            top: titleTop,
            right: 0,
            child: Text(
              '我的英语学习手帐',
              style: Journal.hand(titleSize).copyWith(
                color: const Color(0xFF58443D),
                letterSpacing: l.mobile
                    ? .2
                    : l.tablet
                    ? 0
                    : 1,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: subtitleTop,
            child: Transform.rotate(
              angle: -.017,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: l.mobile ? 7 : 10,
                  vertical: 2,
                ),
                color: const Color(0xFFFCF4D6),
                child: Text(
                  '今天也在慢慢变好',
                  style: Journal.hand(subtitleSize)
                      .copyWith(color: const Color(0xFF8E7756)),
                ),
              ),
            ),
          ),
          if (!l.mobile)
            Positioned(
              left: 11,
              top: subtitleTop + subtitleSize * 1.5 + 17,
              child: Text(
                '给单词一点时间，也给故事留一页空白。',
                style: TextStyle(
                  fontSize: l.large
                      ? 11
                      : l.tablet
                      ? 8
                      : l.medium
                      ? 9
                      : 10,
                  color: const Color(0xFFB1A186),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> editTarget(
  BuildContext context,
  AppController controller,
  bool review,
) async {
  final task = review
      ? controller.home!.dashboard.review
      : controller.home!.dashboard.learn;
  final value = await showDialog<int>(
    context: context,
    builder: (_) => _GoalDialog(target: task.target, review: review),
  );
  if (!context.mounted || value == null) return;
  final saved = await controller.updateTarget(review ? 'review' : 'new', value);
  if (context.mounted && controller.session != null) {
    showNote(context, saved ? '每日目标已保存。' : controller.error ?? '保存未完成，请重试。');
  }
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.target, required this.review});
  final int target;
  final bool review;
  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _form = GlobalKey<FormState>();
  late final _input = TextEditingController(text: '${widget.target}');
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Journal.paper,
    title: Text(
      widget.review ? '调整每日复习目标' : '调整每日新学目标',
      style: Journal.hand(24),
    ),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _input,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: '每日词数（1～200）'),
        validator: (v) {
          final n = int.tryParse(v ?? '');
          return n == null || n < 1 || n > 200 ? '请输入 1～200 之间的整数' : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, int.parse(_input.text));
          }
        },
        child: const Text('保存目标'),
      ),
    ],
  );
}
