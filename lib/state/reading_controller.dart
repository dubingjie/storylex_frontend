import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api.dart';
import '../core/story_repository.dart';
import '../data/story_models.dart';

class ReadingController extends ChangeNotifier {
  ReadingController(this.repository, this.storyId, this.isSessionCurrent);
  final StoryLexRepository repository;
  final int storyId;
  final bool Function() isSessionCurrent;
  StoryDetail? detail;
  StoryDocument? document;
  ReadingProgress? saved;
  String? error, saveError;
  bool loading = true,
      saving = false,
      favoriteBusy = false,
      completeBusy = false,
      conflict = false;
  double percent = 0;
  int position = 0, _generation = 0;
  bool _disposed = false, _dirty = false;
  Timer? _timer;
  Future<bool>? _saveFuture;
  bool get alive => !_disposed && isSessionCurrent();
  bool get dirty => _dirty;
  void changed() {
    if (alive) notifyListeners();
  }

  Future<void> load({bool resume = true}) async {
    final generation = ++_generation;
    _timer?.cancel();
    loading = true;
    error = null;
    changed();
    try {
      final values = await Future.wait<Object>([
        repository.story(storyId),
        repository.readingProgress(storyId),
      ]);
      if (!alive || generation != _generation) return;
      detail = values[0] as StoryDetail;
      document = StoryDocument(detail!.content);
      saved = values[1] as ReadingProgress;
      position = resume ? saved!.position.clamp(0, document!.length) : 0;
      percent = resume ? saved!.percent : 0;
      _dirty = false;
      conflict = false;
      saveError = null;
    } catch (e) {
      if (alive && generation == _generation) error = _message(e);
    } finally {
      if (alive && generation == _generation) {
        loading = false;
        changed();
      }
    }
  }

  void updatePosition(int offset, double value) {
    if (!alive || loading || document == null) return;
    final next = offset.clamp(0, document!.length),
        fraction = value.clamp(0.0, 100.0);
    if (next == position && (fraction - percent).abs() < .1) return;
    position = next;
    percent = fraction;
    _dirty = true;
    changed();
    _timer?.cancel();
    if (!conflict)
      _timer = Timer(const Duration(milliseconds: 1000), () => flush());
  }

  Future<bool> flush() {
    _timer?.cancel();
    if (!alive || saved == null || conflict) return Future.value(false);
    if (_saveFuture != null) return _saveFuture!;
    if (!_dirty) return Future.value(true);
    return _saveFuture = _drain().whenComplete(() => _saveFuture = null);
  }

  Future<bool> _drain() async {
    final generation = _generation;
    saving = true;
    saveError = null;
    changed();
    try {
      while (_dirty && alive && generation == _generation) {
        final offset = position, value = percent;
        _dirty = false;
        try {
          final result = await repository.saveReading(
            storyId,
            value,
            offset,
            saved!.version,
          );
          if (!alive || generation != _generation) return false;
          saved = result;
        } catch (e) {
          if (!alive || generation != _generation) return false;
          _dirty = true;
          conflict = e is ApiException && e.code == 400;
          saveError = conflict ? '阅读位置已在其他页面更新，请重新载入后继续。' : _message(e);
          return false;
        }
      }
      return alive && generation == _generation;
    } finally {
      if (!_disposed) {
        saving = false;
        changed();
      }
    }
  }

  Future<bool> favorite() async {
    if (favoriteBusy || detail == null || !alive) return false;
    favoriteBusy = true;
    error = null;
    changed();
    try {
      final value = await repository.favoriteStory(storyId, !detail!.favorite);
      if (!alive) return false;
      detail!.favorite = value;
      return true;
    } catch (e) {
      if (alive) error = _message(e);
      return false;
    } finally {
      if (alive) {
        favoriteBusy = false;
        changed();
      }
    }
  }

  Future<bool> complete() async {
    if (completeBusy || detail == null || detail!.completed || !alive)
      return false;
    completeBusy = true;
    error = null;
    changed();
    try {
      await repository.completeReading(storyId);
      if (!alive) return false;
      detail!.completed = true;
      updatePosition(document!.length, 100);
      await flush();
      return alive;
    } catch (e) {
      if (alive) error = _message(e);
      return false;
    } finally {
      if (alive) {
        completeBusy = false;
        changed();
      }
    }
  }

  String _message(Object e) => e is ApiException ? e.message : '暂时无法完成操作，请重试。';
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
