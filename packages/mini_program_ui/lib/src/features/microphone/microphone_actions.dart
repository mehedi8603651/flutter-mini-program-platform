import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Foreground voice recording controlled by an optional trusted host provider.
final class MpMicrophoneActions {
  const MpMicrophoneActions();

  /// Records until [stop], cancellation, backgrounding, or a host limit.
  ///
  /// Must be invoked by a user gesture. This action completes when recording
  /// finishes; use a separate button for [stop]. The host may reduce the limit.
  MpAction record({
    int maxDurationSeconds = 60,
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    if (maxDurationSeconds < 1 || maxDurationSeconds > 600) {
      throw ArgumentError.value(
        maxDurationSeconds,
        'maxDurationSeconds',
        'Expected 1-600 seconds.',
      );
    }
    return MpAction(
      'microphone.record',
      props: {
        'maxDurationSeconds': maxDurationSeconds,
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

  /// Finalizes this mini-program's active recording into the original target.
  MpAction stop() => MpAction('microphone.stop');

  /// Discards this mini-program's active recording, preserving previous data.
  MpAction cancel() => MpAction('microphone.cancel');
}
