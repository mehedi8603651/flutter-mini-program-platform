import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';

/// Actions for app-owned opaque temporary media references.
final class MpMediaActions {
  const MpMediaActions();

  /// Releases temporary host media owned by the active mini-program.
  MpAction release({
    required String mediaRef,
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    final reference = requiredAuthoringString(mediaRef, 'mediaRef');
    if (reference.contains('{{') && !isFullBinding(reference)) {
      throw ArgumentError.value(
        mediaRef,
        'mediaRef',
        'Media references must be literals or full binding expressions.',
      );
    }
    return MpAction(
      'media.release',
      props: <String, Object?>{
        'mediaRef': reference,
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
}
