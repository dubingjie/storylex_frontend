import '../data/models.dart';
import '../data/learn_models.dart';
import 'api.dart';

extension LearnRepository on StoryLexRepository {
  Future<LearnGroup> learnGroup({bool review = false}) async =>
      LearnGroup.fromJson(
        await api.request(
          'GET',
          review ? '/api/words/review/queue' : '/api/words/learn/group',
        ),
      );
  Future<Json> sendLearningAction(PendingLearnAction action) =>
      api.request('POST', switch (action.kind) {
        'answer' => '/api/words/learn/answer',
        'review_answer' => '/api/words/review/answer',
        'master' => '/api/words/master',
        'review_complete' => '/api/words/review/complete',
        _ => '/api/words/learn/group/complete',
      }, body: action.body);
  Future<bool> toggleLearnFavorite(int id) async =>
      (await api.request(
        'POST',
        '/api/words/favorite/toggle',
        body: {'word_id': id, 'source_type': 'flashcard'},
      ))['is_favorited'] ==
      true;
  Future<bool> learnFavoriteStatus(LearnWord word) async {
    for (var page = 1; ; page++) {
      final q = Uri(
        queryParameters: {
          'keyword': word.word,
          'page': '$page',
          'page_size': '200',
        },
      ).query;
      final result = await api.request('GET', '/api/words/favorite/list?$q');
      if ((result['list'] as List).any(
        (row) => object(row)['word_id'] == word.id,
      ))
        return true;
      if (page * number(result['page_size']) >= number(result['total']))
        return false;
    }
  }
}
