import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/models.dart';
import 'learning_store.dart';

class DeviceLearningStore implements LearningStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'storylex.learn.v1';
  @override
  Future<Json?> read() async {
    final value = await _storage.read(key: _key);
    return value == null ? null : object(jsonDecode(value));
  }

  @override
  Future<void> write(Json value) =>
      _storage.write(key: _key, value: jsonEncode(value));
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
