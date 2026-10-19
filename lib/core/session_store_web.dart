import 'dart:convert';

import 'package:web/web.dart' as web;

import '../data/models.dart';
import 'session_store.dart';

// Tab-scoped storage also works on the LAN HTTP development preview.
// Do not store passwords or backend/model credentials here.
class DeviceSessionStore implements SessionStore {
  static const _key = 'storylex.session.v1';
  @override
  Future<Session?> read() async {
    final value = web.window.sessionStorage.getItem(_key);
    return value == null ? null : Session.fromJson(object(jsonDecode(value)));
  }

  @override
  Future<void> write(Session session) async {
    web.window.sessionStorage.setItem(_key, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async => web.window.sessionStorage.removeItem(_key);
}
