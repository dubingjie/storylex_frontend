import '../data/favorite_models.dart';
import '../data/models.dart';
import '../data/story_models.dart' show newRequestId;
import 'api.dart';

extension FavoriteRepository on StoryLexRepository {
  Future<FavoritePageData> favorites({
    String keyword = '',
    int page = 1,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'page_size': '50',
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
    ).query;
    return FavoritePageData.fromJson(
      await api.request('GET', '/api/user/favorites?$query'),
    );
  }

  Future<int> removeFavorites(List<int> wordIds) async => number(
    (await api.request(
      'POST',
      '/api/user/favorites/batch-delete',
      body: {'word_ids': wordIds},
    ))['deleted_count'],
  );

  Future<FavoritePracticeSession> createFavoritePractice(
    List<int> wordIds,
    String requestId,
  ) async => FavoritePracticeSession.fromJson(
    await api.request(
      'POST',
      '/api/user/favorites/practice',
      body: {'word_ids': wordIds, 'request_id': requestId, 'mode': 'mixed'},
    ),
  );

  Future<FavoritePracticeSession> favoritePracticeSession(
    String sessionId,
  ) async => FavoritePracticeSession.fromJson(
    await api.request('GET', '/api/words/practice/$sessionId'),
  );

  Future<Json> answerFavoritePractice(
    String sessionId,
    String requestId,
    Json answer,
  ) => api.request(
    'POST',
    '/api/words/practice/$sessionId/answer',
    body: {'request_id': requestId, 'answer': answer},
  );

  Future<Json> submitFavoritePractice(
    String sessionId,
    String requestId,
    List<Json> answers,
  ) => api.request(
    'POST',
    '/api/words/practice/$sessionId/submit',
    body: {'request_id': requestId, 'answers': answers},
  );

  String newFavoritePracticeRequestId() => newRequestId();
}
