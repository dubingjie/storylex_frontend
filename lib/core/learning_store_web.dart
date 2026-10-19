import 'dart:convert';

import 'package:web/web.dart' as web;

import '../data/models.dart';
import 'learning_store.dart';

class DeviceLearningStore implements LearningStore {
  static const _key = 'storylex.learn.v1';
  @override
  Future<Json?> read() async {
    final value = web.window.sessionStorage.getItem(_key);
    return value == null ? null : object(jsonDecode(value));
  }

  @override
  Future<void> write(Json value) async =>
      web.window.sessionStorage.setItem(_key, jsonEncode(value));
  @override
  Future<void> clear() async => web.window.sessionStorage.removeItem(_key);
}
