import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/models.dart';
import 'session_store.dart';

class DeviceSessionStore implements SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'storylex.session.v1';
  @override
  Future<Session?> read() async {
    final value = await _storage.read(key: _key);
    return value == null ? null : Session.fromJson(object(jsonDecode(value)));
  }

  @override
  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
