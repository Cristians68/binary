import 'dart:async';

/// Cancels account listeners before changing Firebase credentials. Navigator
/// disposal happens after the route animation and cannot provide this ordering.
class UserStreams {
  final _listeners = <_UserListener<dynamic>>{};
  bool _transitioning = false;
  int _generation = 0;

  Stream<T> bind<T>(Stream<T> source) => _transitioning
      ? const Stream.empty()
      : _UserListener<T>(this, source, _generation).stream;

  Future<T> transition<T>(Future<T> Function() changeCredentials) async {
    if (_transitioning) {
      throw StateError('An account change is already running.');
    }
    _transitioning = true;
    _generation++;
    try {
      await Future.wait(_listeners.toList().map((listener) => listener.stop()));
      return await changeCredentials();
    } finally {
      _transitioning = false;
    }
  }
}

class _UserListener<T> {
  _UserListener(this.owner, this.source, this.generation) {
    _controller = StreamController<T>(
      onListen: _listen,
      onCancel: _cancel,
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
    );
  }

  final UserStreams owner;
  final Stream<T> source;
  final int generation;
  late final StreamController<T> _controller;
  StreamSubscription<T>? _subscription;
  Future<void>? _cancellation;
  bool _stopped = false;

  Stream<T> get stream => _controller.stream;

  void _listen() {
    if (owner._transitioning || generation != owner._generation) {
      unawaited(_controller.close());
      return;
    }
    owner._listeners.add(this);
    _subscription = source.listen(
      (value) {
        if (!_stopped) _controller.add(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!_stopped) _controller.addError(error, stack);
      },
      onDone: () => unawaited(_controller.close()),
    );
  }

  Future<void> _cancel() {
    _stopped = true;
    return _cancellation ??= _cancelSource();
  }

  Future<void> _cancelSource() async {
    try {
      await _subscription?.cancel();
    } finally {
      owner._listeners.remove(this);
    }
  }

  Future<void> stop() async {
    await _cancel();
    // A paused widget subscription must not hold up sign-out. Its Firestore
    // subscription is already cancelled; closing the consumer can finish later.
    unawaited(_controller.close());
  }
}
