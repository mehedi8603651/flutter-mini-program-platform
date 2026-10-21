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
