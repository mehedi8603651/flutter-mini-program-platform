import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';

/// Lifecycle-owned timer node builders.
final class MpTimer {
  /// Creates timer node helpers.
  const MpTimer();

  /// Maximum supported countdown duration.
  static const Duration maxDuration = Duration(days: 7);

  /// Runs a deadline-based countdown while [running] resolves to true.
  ///
  /// [remainingState] receives the remaining whole seconds, rounded up.
  /// Changing [restartToken] resets the countdown to [duration].
  MpNode countdown({
    required Duration duration,
    required MpNode child,
    Object running = true,
    Object? restartToken,
    String? remainingState,
    MpAction? onComplete,
  }) {
    final durationMs = duration.inMilliseconds;
    if (durationMs <= 0 || duration > maxDuration) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Countdown duration must be from 1 millisecond to 7 days.',
      );
    }
    if (remainingState == null && onComplete == null) {
      throw ArgumentError(
        'Mp.timer.countdown requires remainingState or onComplete.',
      );
    }
    final normalizedRunning = _booleanOrBinding(running, 'running');
    return MpNode(
      'countdown',
      props: <String, Object?>{
        'durationMs': durationMs,
        if (normalizedRunning != true) 'running': normalizedRunning,
        if (restartToken != null)
          'restartToken': _countdownRestartToken(restartToken),
        if (remainingState != null)
          'remainingState': requiredStateKey(remainingState, 'remainingState'),
        if (onComplete != null) 'onComplete': onComplete,
      },
      children: <MpNode>[child],
    );
  }
}

Object _booleanOrBinding(Object value, String name) {
  if (value is bool || isFullBinding(value)) {
    return value;
  }
  throw ArgumentError.value(
    value,
    name,
    'Value must be a boolean or full binding.',
  );
}

Object _countdownRestartToken(Object value) {
  if (value is bool || value is num && value.isFinite) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw ArgumentError.value(
    value,
    'restartToken',
    'Value must be a non-empty string, finite number, or boolean.',
  );
}
