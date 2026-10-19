import 'package:flutter/foundation.dart';

import '../core/api.dart';
import '../core/session_store.dart';
import '../core/learning_store.dart';

import 'dart:convert';

import '../data/models.dart';

class AppController extends ChangeNotifier {
  AppController(
    this.repository,
    SessionStore store, {
    LearningStore? learningStore,
  }) : store = SerialSessionStore(store),
       learningStore = SerialLearningStore(
         learningStore ?? MemoryLearningStore(),
       ) {
    repository.api.onUnauthorized = _expired;
  }
  final StoryLexRepository repository;
  final SessionStore store;
  final LearningStore learningStore;
  String get learningOwner => jsonEncode([
    repository.api.baseUrl,
    session?.username,
    home?.dashboard.bookId,
  ]);
  Session? session;
  HomeData? home;
  BookCatalog? catalog;
  bool booting = true, busy = false;
  String? error, notice;
  int _epoch = 0;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> bootstrap() async {
    booting = true;
    error = null;
    notifyListeners();
    try {
      final loadEpoch = _epoch;
      final saved = session ?? await store.read();
      if (loadEpoch != _epoch) return;
      session = saved;
      if (session != null) {
        repository.api.token = session!.token;
        final epoch = _epoch;
        await repository.me();
        if (epoch != _epoch) return;
        if (session!.needsBook) {
          final result = await repository.books();
          if (epoch == _epoch) catalog = result;
        } else {
          final result = await repository.home();
          if (epoch == _epoch) {
            home = result;
            catalog = result.catalog;
          }
        }
      }
    } catch (e) {
      error = _message(e);
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> authenticate(
    String username,
    String password, {
    required bool register,
  }) async {
    if (busy) return;
    final epoch = _epoch;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      final signedIn = await repository.authenticate(
        username,
        password,
        register: register,
      );
      if (epoch != _epoch) return;
      session = signedIn;
      repository.api.token = signedIn.token;
      await _persist();
      if (epoch != _epoch) return;
      if (register) {
        final result = await repository.books();
        if (epoch == _epoch) catalog = result;
      } else {
        final result = await repository.home();
        if (epoch == _epoch) {
          home = result;
          catalog = result.catalog;
        }
      }
    } catch (e) {
      if (epoch == _epoch) error = _message(e);
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshHome() async {
    if (busy || session == null) return;
    final epoch = _epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.home();
      if (epoch == _epoch) {
        home = result;
        catalog = result.catalog;
      }
    } catch (e) {
      if (epoch == _epoch) error = _message(e);
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadBooks() async {
    if (busy || session == null) return false;
    final epoch = _epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.books();
      if (epoch != _epoch) return false;
      catalog = result;
      return true;
    } catch (e) {
      if (epoch == _epoch) error = _message(e);
      return false;
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> chooseBook(String id) async {
    if (busy || session == null) return false;
    final epoch = _epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.switchBook(id);
      if (epoch != _epoch) return false;
      session = session!.confirmedBook();
      if (catalog != null) catalog = BookCatalog(id, catalog!.books);
      home = null; // Never show the previous book's figures after a successful switch.
      await _persist();
      final result = await repository.home();
      if (epoch != _epoch) return false;
      home = result;
      catalog = result.catalog;
      return true;
    } catch (e) {
      if (epoch == _epoch) error = _message(e);
      return false;
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateTarget(String type, int count) async {
    if (count < 1 || count > 200 || !['new', 'review'].contains(type)) {
      error = '每日目标请输入 1～200 之间的整数。';
      notifyListeners();
      return false;
    }
    if (busy || session == null) return false;
    final epoch = _epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.updateTarget(type, count);
      final result = await repository.home();
      if (epoch != _epoch) return false;
      home = result;
      catalog = result.catalog;
      return true;
    } catch (e) {
      if (epoch == _epoch) error = _message(e);
      return false;
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _persist() async {
    try {
      await store.write(session!);
    } catch (_) {
      notice = '当前设备无法保留登录状态，关闭页面后需要重新登录。';
    }
  }

  Future<void> logout() async {
    _epoch++;
    session = null;
    home = null;
    catalog = null;
    repository.api.token = null;
    busy = false;
    error = null;
    notice = null;
    notifyListeners();
    try {
      await learningStore.clear();
    } catch (_) {}
    try {
      await store.clear();
    } catch (_) {
      notice = '请关闭当前页面以清除浏览器会话。';
      notifyListeners();
    }
  }

  void _expired() {
    logout();
    notice = '登录已过期，请重新登录。';
    notifyListeners();
  }

  String _message(Object e) => e is ApiException ? e.message : '加载未完成，请稍后重试。';
  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    repository.api.onUnauthorized = null;
    repository.api.close();
    super.dispose();
  }
}
