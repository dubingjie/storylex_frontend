import 'dart:math';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import 'models.dart';

String newRequestId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${List.generate(12, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

String storySource(String source) => switch (source) {
  'builtin' => '系统推荐',
  'imported' => '导入文章',
  'ai_generated' => 'AI 生成',
  _ => '文章',
};

class StoryCardData {
  StoryCardData.fromJson(Json j)
    : id = number(j['story_id']),
      title = j['title'] as String,
      source = j['source_type'] as String,
      words = number(j['embedded_word_count'] ?? 0),
      length = number(j['word_count'] ?? 0),
      favorite = j['is_favorited'] == true,
      completed = j['is_completed'] == true;
  final int id, words, length;
  final String title, source;
  final bool completed;
  bool favorite;
}

class StoryPage {
  StoryPage.fromJson(Json j)
    : total = number(j['total']),
      page = number(j['page']),
      size = number(j['page_size']),
      stories = (j['list'] as List)
          .map((e) => StoryCardData.fromJson(object(e)))
          .toList();
  final int total, page, size;
  final List<StoryCardData> stories;
  int get pages => max(1, (total / size).ceil());
}

class StoryDraft {
  StoryDraft.fromJson(Json json)
    : id = json['draft_id'] as String,
      status = json['status'] as String? ?? 'failed',
      version = number(json['version'] ?? 0),
      targetBookId = json['target_book_id'] as String? ?? '',
      storyType = json['story_type'] as String? ?? '',
      title = json['title'] as String? ?? '',
      content = json['processed_content'] as String? ?? '',
      sourceType = json['source_type'] as String? ?? 'ai_generated',
      sourceContent = json['source_content'] as String? ?? '',
      originalContent = json['original_content'] as String? ?? '',
      error = json['error'] as String? ?? '',
      errorCode = json['error_code'] as String? ?? '',
      targetWords = (json['target_words'] as List? ?? const [])
          .map((word) => object(word))
          .toList(),
      wordIds = (json['word_ids'] as List? ?? const []).map(number).toList(),
      embeddedOccurrences = number(json['embedded_occurrences'] ?? 0),
      importInfo = json['import_info'] is Map
          ? object(json['import_info'])
          : <String, dynamic>{},
      missingWordIds = (json['missing_word_ids'] as List? ?? const [])
          .map(number)
          .toList();
  final String id, status, targetBookId, storyType, title, content;
  final String sourceType, sourceContent, originalContent;
  final String error, errorCode;
  final int version;
  final List<Json> targetWords;
  final List<int> wordIds, missingWordIds;
  final int embeddedOccurrences;
  final Json importInfo;
}

class StoryWord {
  StoryWord.fromJson(Json j)
    : id = number(j['word_id']),
      word = j['word'] as String,
      us = j['us_phone'] as String? ?? '',
      uk = j['uk_phone'] as String? ?? '',
      book = j['translation_book_title'] as String? ?? '',
      outOfBook = j['is_out_of_book'] == true,
      favorite = j['is_favorited'] == true,
      mastered = j['is_mastered'] == true,
      translations =
          (j['translations'] is List ? j['translations'] as List : const [])
              .map((t) {
                final m = object(t);
                return '${m['pos'] ?? ''} ${m['tranCn'] ?? m['tran'] ?? ''}'
                    .trim();
              })
              .where((t) => t.isNotEmpty)
              .join('；');
  final int id;
  final String word, us, uk, book, translations;
  final bool outOfBook;
  bool favorite, mastered;
  String get meaning => translations.isEmpty ? '释义待补充' : translations;
}

class StoryDetail {
  StoryDetail.fromJson(Json j)
    : id = number(j['story_id']),
      title = j['title'] as String,
      source = j['source_type'] as String,
      content = j['processed_content'] as String,
      favorite = j['is_favorited'] == true,
      completed = j['is_completed'] == true,
      words = (j['embedded_words'] as List)
          .map((e) => StoryWord.fromJson(object(e)))
          .toList();
  final int id;
  final String title, source, content;
  final List<StoryWord> words;
  bool favorite, completed;
}

class ReadingProgress {
  ReadingProgress.fromJson(Json j)
    : percent = (j['progress'] as num).toDouble(),
      position = number(j['position']),
      version = number(j['version']);
  final double percent;
  final int position, version;
}

class StoryRun {
  const StoryRun(this.text, [this.wordId]);
  final String text;
  final int? wordId;
}

class StoryParagraph {
  const StoryParagraph(this.runs, this.offset, this.length);
  final List<StoryRun> runs;
  final int offset, length;
}

/// Render only text and known word markers. HTML is never executed or embedded.
class StoryDocument {
  StoryDocument(String content) {
    final lines = <List<StoryRun>>[[]];
    void add(String text, [int? wordId]) {
      final chunks = text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n');
      for (var i = 0; i < chunks.length; i++) {
        if (i > 0) lines.add([]);
        if (chunks[i].isNotEmpty) lines.last.add(StoryRun(chunks[i], wordId));
      }
    }

    void walk(dom.Node node) {
      if (node is dom.Text) {
        add(node.data);
        return;
      }
      if (node is dom.Element) {
        if (['script', 'style', 'iframe', 'object'].contains(node.localName))
          return;
        if (node.localName == 'br') {
          add('\n');
          return;
        }
        if (node.localName == 'word') {
          add(node.text, int.tryParse(node.attributes['id'] ?? ''));
          return;
        }
        if (['p', 'div'].contains(node.localName) && lines.last.isNotEmpty)
          add('\n');
      }
      for (final child in node.nodes) {
        walk(child);
      }
      if (node is dom.Element &&
          ['p', 'div'].contains(node.localName) &&
          lines.last.isNotEmpty)
        add('\n');
    }

    walk(html.parseFragment(content));
    var offset = 0;
    for (final line in lines) {
      final length = line.fold<int>(0, (n, r) => n + r.text.runes.length);
      if (length > 0) paragraphs.add(StoryParagraph(line, offset, length));
      offset += length + 1;
    }
    length = max(0, offset - 1);
  }
  final paragraphs = <StoryParagraph>[];
  late final int length;
}

class ReadingQuestion {
  ReadingQuestion.fromJson(Json j)
    : id = j['question_id'] as String,
      wordId = number(j['word_id']),
      word = j['word'] as String,
      options = (j['options'] as List).map(object).toList();
  final String id, word;
  final int wordId;
  final List<Json> options;
}

class ReadingPractice {
  ReadingPractice.fromJson(Json j)
    : session = j['session_id'] as String?,
      questions = (j['questions'] as List)
          .map((e) => ReadingQuestion.fromJson(object(e)))
          .toList();
  final String? session;
  final List<ReadingQuestion> questions;
}
