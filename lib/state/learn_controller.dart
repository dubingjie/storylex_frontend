import 'package:flutter/foundation.dart';

import '../core/api.dart';
import '../core/learn_repository.dart';
import '../core/learning_store.dart';
import '../data/learn_models.dart';
import '../data/models.dart';
import '../data/story_models.dart' show newRequestId;

class LearnController extends ChangeNotifier {
  LearnController(
    this.repository,
    this.store,
    this.owner,
    this.isSessionCurrent, {
    this.reviewMode = false,
  });
  final StoryLexRepository repository;
  final LearningStore store;
  final String owner;
  final bool Function() isSessionCurrent;
  final bool reviewMode;
  LearnGroup? group;
  LearnFeedback? feedback;
  LearnSummary? summary;
  PendingLearnAction? pending;
  String? error, notice, favoriteError;
  bool loading = false, busy = false, favoriteBusy = false, needsReload = false;
  bool _disposed = false, _screenOpen = true;
  int? _currentId;
  final _queue = <int>[];
  final _favorites = <int, bool>{};
  bool get alive => !_disposed && isSessionCurrent();
  bool get locked =>
      loading || busy || favoriteBusy || needsReload || pending != null;
  LearnWord? get current =>
      _currentId == null ? null : group?.word(_currentId!);
  LearnWord? get displayWord => feedback?.word ?? current;
  bool get allPassed => group?.allPassed == true;
  bool? get favorite =>
      displayWord == null ? null : _favorites[displayWord!.id];
  void changed() {
    if (alive) notifyListeners();
  }

  Future<void> _remember() async {
    if (!alive) return;
    try {
      await store.write({
        'owner': owner,
        'open': _screenOpen,
        'group_id': group?.id,
        'pending': pending?.toJson(),
      });
    } catch (_) {
      if (alive) notice = '当前设备无法保留恢复信息，刷新后将重新读取服务端题组。';
    }
  }

  Future<void> pauseScreen() async {
    _screenOpen = false;
    await _remember();
  }

  Future<void> load({bool discardPending = false}) async {
    if (loading || busy) return;
    loading = true;
    error = null;
    notice = null;
    needsReload = false;
    _screenOpen = true;
    changed();
    try {
      if (!discardPending) {
        Json? record;
        try {
          record = await store.read();
        } catch (_) {
          notice = '无法读取本地恢复信息，正在重新读取题组。';
        }
        if (!alive) return;
        if (record?['owner'] == owner && record?['pending'] != null) {
          try {
            pending = PendingLearnAction.fromJson(object(record!['pending']));
          } catch (_) {
            pending = null;
            notice = '本地恢复信息已失效，已重新读取题组。';
          }
        }
        if (pending != null) {
          await _send(recover: true);
          if (!alive) return;
          if (!needsReload || pending != null) return;
          notice = '上次题组状态已变化，已重新获取当前题组。';
          needsReload = false;
          error = null;
        }
      }
      final packet = await repository.learnGroup(review: reviewMode);
      if (!alive) return;
      _adopt(packet);
      pending = null;
      feedback = null;
      summary = null;
      if (packet.total == 0) _screenOpen = false;
      await _remember();
      _syncFavorite();
    } catch (e) {
      if (alive) error = _message(e);
    } finally {
      if (alive) {
        loading = false;
        changed();
      }
    }
  }

  void _adopt(LearnGroup packet) {
    group = packet;
    _queue
      ..clear()
      ..addAll(packet.words.where((w) => !w.passed).map((w) => w.id));
    _currentId = _queue.isEmpty ? null : _queue.first;
    _favorites.clear();
    favoriteError = null;
  }

  Future<void> answer(String? selectedKey) async {
    if (locked || feedback != null || current == null || current!.passed)
      return;
    final word = LearnWord.fromJson(current!.toJson());
    pending = PendingLearnAction(reviewMode ? 'review_answer' : 'answer', {
      'group_id': group!.id,
      'word_id': word.id,
      'question_id': word.questionId,
      'request_id': newRequestId(),
      'selected_key': selectedKey,
      'is_show_answer': selectedKey == null,
    }, word);
    await _send();
  }

  Future<void> master() async {
    if (locked || current == null || current!.passed) return;
    pending = PendingLearnAction('master', {
      'group_id': group!.id,
      'word_id': current!.id,
    }, LearnWord.fromJson(current!.toJson()));
    await _send();
  }

  Future<void> complete() async {
    if (locked || !allPassed) return;
    pending = PendingLearnAction(reviewMode ? 'review_complete' : 'complete', {
      'group_id': group!.id,
    }, null);
    await _send();
  }

  Future<void> retryPending() async {
    if (!busy && !loading && pending != null)
      await _send(recover: group == null);
  }

  Future<void> _send({bool recover = false}) async {
    final action = pending;
    if (action == null || busy || !alive) return;
    busy = true;
    error = null;
    changed();
    try {
      await _remember();
      if (!alive) return;
      final result = await repository.sendLearningAction(action);
      if (!alive) return;
      if (action.kind == 'complete' || action.kind == 'review_complete') {
        summary = LearnSummary.fromJson(result);
        feedback = null;
        group = null;
        _queue.clear();
        _currentId = null;
        _screenOpen = false;
      } else {
        if (recover) {
          final fresh = await repository.learnGroup(review: reviewMode);
          if (!alive) return;
          _adopt(fresh);
        }
        if (group?.id != action.body['group_id']) {
          feedback = null;
          notice = '原题组已处理，已载入当前可学题组。';
        } else if (recover && action.kind == 'review_answer') {
          feedback = null;
          notice = '上次复习答案已记录，已恢复到下一道未完成的题。';
        } else {
          final id = number(action.body['word_id']);
          final index = group!.words.indexWhere((w) => w.id == id);
          if (index < 0) throw const FormatException('word no longer in group');
          var showFeedback = true;
          if (!recover) {
            if (action.kind == 'master') {
              group!.words[index].passed = true;
              group!.words[index].mastered = true;
            } else if (action.kind == 'review_answer' ||
                result['is_correct'] == true) {
              group!.words[index].passed = true;
            } else {
              group!.words[index] = LearnWord.fromJson(
                object(result['retry_question']),
              );
            }
            group!.passedCount = number(result['passed_count']);
          } else if (action.kind == 'answer' && result['is_correct'] != true) {
            final retry = object(result['retry_question']);
            showFeedback =
                !group!.words[index].passed &&
                group!.words[index].questionId == retry['question_id'];
          }
          if (showFeedback) {
            _currentId = id;
            feedback = LearnFeedback(
              word: action.word ?? group!.words[index],
              kind: action.kind == 'master'
                  ? 'mastered'
                  : result['is_correct'] == true
                  ? 'correct'
                  : 'wrong',
              selectedKey: action.body['selected_key'] as String?,
              correctKey: result['correct_key'] as String?,
              detail: action.kind == 'answer' || action.kind == 'review_answer'
                  ? object(result['word_detail'])
                  : feedback?.detail,
            );
          } else {
            feedback = null;
            notice = '该词状态已更新，继续当前题组即可。';
          }
        }
      }
      pending = null;
      await _remember();
      if (recover) _syncFavorite();
    } catch (e) {
      if (alive) {
        error = _message(e);
        if (e is ApiException && e.code == 400) {
          pending = null;
          needsReload = true;
          await _remember();
        }
      }
    } finally {
      if (alive) {
        busy = false;
        changed();
      }
    }
  }

  Future<void> advance() async {
    if (locked || feedback == null) return;
    if (allPassed) {
      await complete();
      return;
    }
    final id = _currentId!;
    _queue.remove(id);
    if (!reviewMode && group!.word(id).passed == false) _queue.add(id);
    _queue.removeWhere((id) => group!.word(id).passed);
    _currentId = _queue.isEmpty ? null : _queue.first;
    feedback = null;
    favoriteError = null;
    changed();
    _syncFavorite();
  }

  Future<void> nextGroup() async {
    if (locked) return;
    await load(discardPending: true);
  }

  Future<void> _syncFavorite() async {
    final word = displayWord;
    if (word == null || !alive || _favorites.containsKey(word.id)) return;
    favoriteBusy = true;
    favoriteError = null;
    changed();
    try {
      final value = await repository.learnFavoriteStatus(word);
      if (alive) _favorites[word.id] = value;
    } catch (e) {
      if (alive) favoriteError = _message(e);
    } finally {
      if (alive) {
        favoriteBusy = false;
        changed();
      }
    }
  }

  Future<void> favoriteAction() async {
    if (loading || busy || favoriteBusy || displayWord == null) return;
    final word = displayWord!;
    if (!_favorites.containsKey(word.id)) {
      await _syncFavorite();
      return;
    }
    favoriteBusy = true;
    favoriteError = null;
    changed();
    try {
      final value = await repository.toggleLearnFavorite(word.id);
      if (alive) _favorites[word.id] = value;
    } catch (e) {
      if (alive) {
        _favorites.remove(word.id);
        favoriteError = '收藏结果未能确认，请先重新核对收藏状态。';
      }
    } finally {
      if (alive) {
        favoriteBusy = false;
        changed();
      }
    }
  }

  String _message(Object e) => e is ApiException ? e.message : '暂时无法完成操作，请重试。';
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
