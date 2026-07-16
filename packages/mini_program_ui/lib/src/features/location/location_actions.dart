import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

/// Host-controlled one-time location action builders.
final class MpLocationActions {
  /// Creates current-location action helpers.
  const MpLocationActions();

  /// Requests an approximate foreground location from the host.
  MpAction getCurrent({
    String accuracy = 'approximate',
    required Duration timeout,
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    final timeoutMs = timeout.inMilliseconds;
    if (timeoutMs < 1000 || timeoutMs > 60000) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Location timeout must be from 1 to 60 seconds.',
      );
    }
    return MpAction(
      'location.getCurrent',
      props: <String, Object?>{
        'accuracy': allowedValue(accuracy, 'accuracy', const <String>{
          'approximate',
        }),
        'timeoutMs': timeoutMs,
        'targetState': requiredStateKey(targetState, 'targetState'),
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
        if (requestId != null)
          'requestId': stableAuthoringString(requestId, 'requestId'),
      },
    );
  }
}
