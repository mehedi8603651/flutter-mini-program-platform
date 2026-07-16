import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

MpAction buildToastAction({required String message, int durationMs = 2400}) {
  return MpAction(
    'ui.toast',
    props: <String, Object?>{
      'message': requiredAuthoringString(message, 'message'),
      'durationMs': positiveInt(durationMs, 'durationMs'),
    },
  );
}

MpAction buildDialogAction({
  String? title,
  required String message,
  String confirmLabel = 'OK',
}) {
  return MpAction(
    'ui.dialog',
    props: <String, Object?>{
      if (title != null) 'title': requiredAuthoringString(title, 'title'),
      'message': requiredAuthoringString(message, 'message'),
      'confirmLabel': requiredAuthoringString(confirmLabel, 'confirmLabel'),
    },
  );
}
