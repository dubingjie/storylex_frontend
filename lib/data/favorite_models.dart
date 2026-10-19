import 'models.dart';

class FavoriteWord {
  FavoriteWord.fromJson(Json j)
    : id = number(j['word_id']),
      word = j['word'] as String,
      us = j['us_phone'] as String? ?? '',
      uk = j['uk_phone'] as String? ?? '',
      source = j['source_type'] as String? ?? '',
      translations = (j['translations'] as List? ?? const [])
          .map((item) {
            if (item is! Map) return item.toString();
            final value = object(item);
            final pos = (value['pos'] ?? '').toString();
            final text = (value['tranCn'] ?? value['tran'] ?? '').toString();
            return '${pos.isEmpty ? '' : '$pos '}$text'.trim();
          })
          .where((text) => text.isNotEmpty)
          .toList();
  final int id;
  final String word, us, uk, source;
  final List<String> translations;
  String get meaning => translations.isEmpty ? '释义待补充' : translations.join('；');
}

class FavoritePageData {
  FavoritePageData.fromJson(Json j)
    : total = number(j['total']),
      page = number(j['page']),
      pageSize = number(j['page_size']),
      words = (j['list'] as List)
          .map((item) => FavoriteWord.fromJson(object(item)))
          .toList();
  final int total, page, pageSize;
  final List<FavoriteWord> words;
  int get pages =>
      pageSize < 1 ? 1 : (total / pageSize).ceil().clamp(1, 1 << 30);
}

class FavoritePracticeQuestion {
  FavoritePracticeQuestion.fromJson(Json j)
    : id = j['question_id'] as String,
      wordId = number(j['word_id']),
      type = j['question_type'] as String,
      prompt = j['prompt'] as String,
      us = j['us_phone'] as String? ?? '',
      uk = j['uk_phone'] as String? ?? '',
      options = (j['options'] as List).map(object).toList();
  final String id, type, prompt, us, uk;
  final int wordId;
  final List<Json> options;
}

class FavoritePracticeSession {
  FavoritePracticeSession.fromJson(Json j)
    : id = j['session_id'] as String,
      status = j['status'] as String? ?? 'active',
      questions = (j['questions'] as List)
          .map((item) => FavoritePracticeQuestion.fromJson(object(item)))
          .toList(),
      result = j['result'] == null ? null : object(j['result']);
  final String id, status;
  final List<FavoritePracticeQuestion> questions;
  final Json? result;
}
