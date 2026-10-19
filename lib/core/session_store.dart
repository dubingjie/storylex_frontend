import '../data/models.dart';
export 'session_store_native.dart'
    if (dart.library.js_interop) 'session_store_web.dart';

abstract interface class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

/// Serialize writes and clears so a slow platform write cannot restore a logged-out token.
class SerialSessionStore implements SessionStore {
  SerialSessionStore(this.inner);
  final SessionStore inner;
  Future<void> _tail = Future.value();
  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<Session?> read() => _run(inner.read);
  @override
  Future<void> write(Session session) => _run(() => inner.write(session));
  @override
  Future<void> clear() => _run(inner.clear);
}
