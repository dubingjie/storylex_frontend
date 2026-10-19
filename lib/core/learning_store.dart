import '../data/models.dart';
export 'learning_store_native.dart'
    if (dart.library.js_interop) 'learning_store_web.dart';

abstract interface class LearningStore {
  Future<Json?> read();
  Future<void> write(Json value);
  Future<void> clear();
}

class MemoryLearningStore implements LearningStore {
  Json? value;
  @override
  Future<Json?> read() async => value;
  @override
  Future<void> write(Json value) async {
    this.value = Map.from(value);
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

/// A logout clear cannot be overtaken by an earlier checkpoint write.
class SerialLearningStore implements LearningStore {
  SerialLearningStore(this.inner);
  final LearningStore inner;
  Future<void> _tail = Future.value();
  Future<T> _run<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<Json?> read() => _run(inner.read);
  @override
  Future<void> write(Json value) => _run(() => inner.write(value));
  @override
  Future<void> clear() => _run(inner.clear);
}
