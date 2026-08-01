import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Host-controlled foreground flashlight actions.
final class MpFlashlightActions {
  const MpFlashlightActions();

  MpAction turnOn({
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _operation(
    'flashlight.turnOn',
    targetState: targetState,
    statusState: statusState,
    errorState: errorState,
    requestId: requestId,
  );

  MpAction turnOff({
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _operation(
    'flashlight.turnOff',
    targetState: targetState,
    statusState: statusState,
    errorState: errorState,
    requestId: requestId,
  );

  MpAction toggle({
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _operation(
    'flashlight.toggle',
    targetState: targetState,
    statusState: statusState,
    errorState: errorState,
    requestId: requestId,
  );

  MpAction getStatus({
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _operation(
    'flashlight.getStatus',
    targetState: targetState,
    statusState: statusState,
    errorState: errorState,
    requestId: requestId,
  );
}

MpAction _operation(
  String type, {
  String? targetState,
  String? statusState,
  String? errorState,
  String? requestId,
}) => MpAction(
  type,
  props: <String, Object?>{
    if (targetState != null)
      'targetState': requiredStateKey(targetState, 'targetState'),
    if (statusState != null)
      'statusState': requiredStateKey(statusState, 'statusState'),
    if (errorState != null)
      'errorState': requiredStateKey(errorState, 'errorState'),
    if (requestId != null)
      'requestId': stableAuthoringString(requestId, 'requestId'),
  },
);
