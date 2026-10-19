import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'journal.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    super.key,
    required this.controller,
    required this.start,
  });
  final AppController controller;
  final VoidCallback start;

  @override
  Widget build(BuildContext context) {
    final task = controller.home!.dashboard.review;
    final mobile = JournalLayout.of(context).mobile;
    return SingleChildScrollView(
      child: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('温习，是再见一面。', style: Journal.hand(mobile ? 27 : 34)),
            const SizedBox(height: 5),
            const Text('把学过的单词，再慢慢记牢。', style: TextStyle(color: Journal.muted)),
            SizedBox(height: mobile ? 20 : 28),
            Paper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _stat('${task.available}', '当前待复习'),
                      _stat('${task.finished}', '今日已复习'),
                      _stat('${task.target}', '每日目标'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '今天的小目标',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${task.finished} / ${task.target}',
                        style: const TextStyle(color: Journal.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value: task.progress,
                      color: const Color(0xFFB7C99B),
                      backgroundColor: const Color(0xFFE8E7D5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    task.available > 0
                        ? '这次温习 ${task.available} 个词，答完每个词后会看到解析。'
                        : task.completed
                        ? '今天的复习目标已经完成。'
                        : '现在没有到期待复习的单词。',
                    style: const TextStyle(color: Journal.muted, height: 1.8),
                  ),
                  const SizedBox(height: 17),
                  Align(
                    alignment: mobile ? Alignment.center : Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: task.canStart ? start : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(task.canStart ? '开始复习' : '暂时没有可复习单词'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Paper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('这一轮，怎么复习？', style: Journal.hand(21)),
                  const SizedBox(height: 12),
                  const Text(
                    '每个单词只答一次，答完后会显示正确答案和释义。',
                    style: TextStyle(height: 1.8),
                  ),
                  const Text(
                    '答错或查看答案也会记录本次复习，之后按复习安排再次出现。',
                    style: TextStyle(height: 1.8),
                  ),
                  const Text(
                    '收藏单词可在收藏页自主练习，不会进入复习队列。',
                    style: TextStyle(height: 1.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: Journal.hand(27).copyWith(color: Journal.green)),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Journal.muted),
        ),
      ],
    ),
  );
}
