import 'dart:async';

/// Internal origin propagation. Calling a UI callback programmatically never
/// manufactures a native user gesture. The zone also follows async callbacks.
final class MiniProgramInteractionExecution {
  MiniProgramInteractionExecution({required this.isAllowed});
  static final Object _key = Object();
  static MiniProgramInteractionExecution? get current =>
      Zone.current[_key] as MiniProgramInteractionExecution?;

  int pending = 0;
  bool active = true;
  Object? lastResult;
  bool failed = false;
  bool cancelled = false;
  bool waitingForPanel = false;
  final bool Function() isAllowed;

  T run<T>(T Function() body) => runZoned(body, zoneValues: {_key: this});

  /// Keeps a debounced UI operation pending until it runs or is cancelled.
  static Timer delay(Duration duration, FutureOr<void> Function() callback) {
    final execution = current;
    if (execution == null) return Timer(duration, callback);
    return _InteractionTimer(execution, duration, callback);
  }

  Future<T> track<T>(Future<T> future) {
    pending++;
    unawaited(
      future
          .then<void>(
            (value) {
              if (value != null) lastResult = value;
            },
            onError: (Object error, StackTrace stack) {
              failed = true;
            },
          )
          .whenComplete(() => pending--),
    );
    return future;
  }
}

final class _InteractionTimer implements Timer {
  _InteractionTimer(
    this.execution,
    Duration duration,
    FutureOr<void> Function() callback,
  ) {
    execution.pending++;
    timer = Timer(duration, () {
      if (!execution.cancelled && execution.isAllowed()) {
        // track installs an error listener, including for callbacks whose
        // owner disappeared before the debounce elapsed.
        execution.track(Future<void>.sync(callback));
      }
      _finish();
    });
  }
  final MiniProgramInteractionExecution execution;
  late final Timer timer;
  bool finished = false;
  void _finish() {
    if (finished) return;
    finished = true;
    execution.pending--;
  }

  @override
  void cancel() {
    timer.cancel();
    _finish();
  }

  @override
  bool get isActive => timer.isActive;
  @override
  int get tick => timer.tick;
}
