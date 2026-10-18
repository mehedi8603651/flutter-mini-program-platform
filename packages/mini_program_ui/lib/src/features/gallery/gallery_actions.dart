import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// User-initiated photo selection through a host-installed gallery provider.
final class MpGalleryActions {
  const MpGalleryActions();

  /// Selects photos for preview, sharing, and later upload by opaque reference.
  ///
  /// The host may reduce [maxImages]. Image bounds never enlarge a source.
  /// Cancelling preserves the previous [targetState] value.
  MpAction pickImages({
    int maxImages = 1,
    int maxWidth = 2048,
    int maxHeight = 2048,
    int quality = 90,
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    if (maxImages < 1 || maxImages > 30) {
      throw ArgumentError.value(
        maxImages,
        'maxImages',
        'Expected 1-30 images.',
      );
    }
    for (final bound in {
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
    }.entries) {
      if (bound.value < 64 || bound.value > 8192) {
        throw ArgumentError.value(
          bound.value,
          bound.key,
          'Expected 64-8192 pixels.',
        );
      }
    }
    if (quality < 1 || quality > 100) {
      throw ArgumentError.value(quality, 'quality', 'Expected 1-100.');
    }
    return MpAction(
      'gallery.pickImages',
      props: {
        'maxImages': maxImages,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
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

  /// Logically cancels this mini-program's active photo selection.
  /// Android's picker may still need to be dismissed by the user.
  MpAction cancel() => MpAction('gallery.cancel');
}
