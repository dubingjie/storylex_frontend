import 'dart:typed_data';

import '../data/models.dart';
import '../data/story_models.dart';
import 'api.dart';

extension StoryRepository on StoryLexRepository {
  Future<StoryDraft> importTxtDraft({
    required Uint8List bytes,
    required String filename,
    required String targetBookId,
    required String requestId,
    String? title,
    int maxReplacements = 20,
    int minGap = 30,
  }) async => StoryDraft.fromJson(
    await api.uploadFile(
      '/api/ai/import-txt',
      bytes: bytes,
      filename: filename,
      fields: {
        'target_book_id': targetBookId,
        'request_id': requestId,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'max_replacements': maxReplacements,
        'min_gap': minGap,
      },
    ),
  );

  Future<StoryDraft> generateAiDraft({
    required String requestId,
    required List<int> wordIds,
    required String storyType,
    String? title,
  }) async => StoryDraft.fromJson(
    await api.request(
      'POST',
      '/api/ai/generate-story',
      body: {
        'request_id': requestId,
        'word_ids': wordIds,
        'story_type': storyType,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
      requestTimeout: const Duration(seconds: 75),
    ),
  );

  Future<StoryDraft> storyDraft(String draftId) async =>
      StoryDraft.fromJson(await api.request('GET', '/api/ai/drafts/$draftId'));

  Future<StoryDraft> editStoryDraft(
    String draftId, {
    required int version,
    required String title,
    required String content,
  }) async => StoryDraft.fromJson(
    await api.request(
      'PUT',
      '/api/ai/drafts/$draftId',
      body: {'version': version, 'title': title, 'processed_content': content},
    ),
  );

  Future<Json> saveStoryDraft(
    String draftId, {
    required String requestId,
    required int version,
  }) => api.request(
    'POST',
    '/api/ai/drafts/$draftId/save',
    body: {'request_id': requestId, 'version': version},
  );

  Future<StoryPage> stories({
    required String scope,
    String category = 'all',
    String keyword = '',
    int page = 1,
  }) async {
    final query = Uri(
      queryParameters: {
        'scope': scope,
        'category': category,
        'keyword': keyword,
        'page': '$page',
        'page_size': '6',
      },
    ).query;
    return StoryPage.fromJson(
      await api.request('GET', '/api/stories/list?$query'),
    );
  }

  Future<StoryDetail> story(int id) async =>
      StoryDetail.fromJson(await api.request('GET', '/api/stories/detail/$id'));
  Future<ReadingProgress> readingProgress(int id) async =>
      ReadingProgress.fromJson(
        await api.request('GET', '/api/stories/$id/progress'),
      );
  Future<ReadingProgress> saveReading(
    int id,
    double percent,
    int position,
    int version,
  ) async => ReadingProgress.fromJson(
    await api.request(
      'PUT',
      '/api/stories/$id/progress',
      body: {'progress': percent, 'position': position, 'version': version},
    ),
  );
  Future<bool> favoriteStory(int id, bool value) async =>
      (await api.request(
        'PUT',
        '/api/stories/$id/favorite',
        body: {'is_favorited': value},
      ))['is_favorited'] ==
      true;
  Future<void> completeReading(int id) async {
    await api.request('POST', '/api/stories/complete', body: {'story_id': id});
  }

  Future<bool> favoriteReadingWord(int id) async =>
      (await api.request(
        'POST',
        '/api/words/favorite/toggle',
        body: {'word_id': id, 'source_type': 'story'},
      ))['is_favorited'] ==
      true;
  Future<void> masterReadingWord(int id) async {
    await api.request('POST', '/api/words/master', body: {'word_id': id});
  }

  Future<ReadingPractice> readingPractice(int id) async =>
      ReadingPractice.fromJson(
        await api.request('GET', '/api/stories/$id/practice'),
      );
  Future<Json> submitReadingPractice(
    int id,
    String session,
    String requestId,
    List<Json> answers,
  ) => api.request(
    'POST',
    '/api/stories/$id/practice/submit',
    body: {'session_id': session, 'request_id': requestId, 'answers': answers},
  );
}
