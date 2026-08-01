import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Host-controlled still-photo capture actions.
final class MpCameraActions {
  const MpCameraActions();

  /// Opens the host's trusted camera UI and captures one photo.
  ///
  /// [maxWidth] and [maxHeight] are optional output bounds. They never request
  /// a fixed sensor or preview resolution.
  MpAction capturePhoto({
    int? maxWidth,
    int? maxHeight,
    int quality = 95,
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    _optionalImageBound(maxWidth, 'maxWidth');
    _optionalImageBound(maxHeight, 'maxHeight');
    if (quality < 1 || quality > 100) {
      throw ArgumentError.value(
        quality,
        'quality',
        'Camera quality must be from 1 to 100.',
      );
    }
    return MpAction(
      'camera.capturePhoto',
      props: <String, Object?>{
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (maxHeight != null) 'maxHeight': maxHeight,
        'quality': quality,
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

  /// Cancels the active capture owned by this mini-program, when possible.
  MpAction cancel({
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => MpAction(
    'camera.cancel',
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
}

void _optionalImageBound(int? value, String name) {
  if (value != null && (value < 64 || value > 8192)) {
    throw ArgumentError.value(
      value,
      name,
      'Camera image bounds must be from 64 to 8192 pixels.',
    );
  }
}
