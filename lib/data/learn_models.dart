import 'models.dart';

class LearnWord {
  LearnWord.fromJson(Json j)
    : id = number(j['word_id']),
      word = j['word'] as String,
      questionId = j['question_id'] as String,
      uk = j['uk_phone'] as String? ?? '',
      us = j['us_phone'] as String? ?? '',
      options = (j['options'] as List)
          .map(object)
          .map((o) => Map<String, dynamic>.from(o))
          .toList(),
      passed = j['passed'] == true,
      mastered = j['is_mastered'] == true,
      favorite = j['is_favorited'] == true;
  final int id;
  final String word, questionId, uk, us;
  final List<Json> options;
  bool passed, mastered, favorite;
  Json toJson() => {
    'word_id': id,
    'word': word,
    'question_id': questionId,
    'uk_phone': uk,
    'us_phone': us,
    'options': options,
    'passed': passed,
    'is_mastered': mastered,
    'is_favorited': favorite,
  };
}

class LearnGroup {
  LearnGroup.fromJson(Json j)
    : id = j['group_id'] as String?,
      total = number(j['total']),
      passedCount = number(j['passed_count']),
      words = (j['words'] as List)
          .map((e) => LearnWord.fromJson(object(e)))
          .toList();
  final String? id;
  final int total;
  int passedCount;
  final List<LearnWord> words;
  bool get allPassed =>
      total > 0 && passedCount == total && words.every((w) => w.passed);
  LearnWord word(int id) => words.firstWhere((w) => w.id == id);
}

class LearnFeedback {
  LearnFeedback({
    required this.word,
    required this.kind,
    this.selectedKey,
    this.correctKey,
    this.detail,
  });
  final LearnWord word;
  final String kind;
  final String? selectedKey, correctKey;
  final Json? detail;
}

class LearnSummary {
  LearnSummary.fromJson(Json j)
    : groupId = j['group_id'] as String,
      words = (j['summary_list'] as List? ?? const []).map(object).toList(),
      completedCount = number(
        j['reviewed_count'] ?? (j['summary_list'] as List?)?.length ?? 0,
      ),
      totalCount = number(
        j['total'] ?? (j['summary_list'] as List?)?.length ?? 0,
      );
  LearnSummary({
    required this.groupId,
    required this.words,
    required this.completedCount,
    required this.totalCount,
  });
  final String groupId;
  final List<Json> words;
  final int completedCount, totalCount;
}

class PendingLearnAction {
  PendingLearnAction(this.kind, this.body, this.word);
  factory PendingLearnAction.fromJson(Json j) {
    final kind = j['kind'] as String;
    if (![
      'answer',
      'review_answer',
      'master',
      'complete',
      'review_complete',
    ].contains(kind))
      throw const FormatException('unknown learning action');
    final body = object(j['body']);
    if (body['group_id'] is! String)
      throw const FormatException('missing group');
    return PendingLearnAction(
      kind,
      body,
      j['word'] == null ? null : LearnWord.fromJson(object(j['word'])),
    );
  }
  final String kind;
  final Json body;
  final LearnWord? word;
  Json toJson() => {'kind': kind, 'body': body, 'word': word?.toJson()};
}

String learnTranslation(Object? raw) {
  if (raw is! List) return '';
  return raw
      .map((item) {
        if (item is! Map) return item.toString();
        final pos = (item['pos'] ?? '').toString(),
            text = (item['tranCn'] ?? '').toString();
        return '${pos.isEmpty
                ? ''
                : pos.endsWith('.')
                ? '$pos '
                : '$pos. '}$text'
            .trim();
      })
      .where((s) => s.isNotEmpty)
      .join('；');
}
