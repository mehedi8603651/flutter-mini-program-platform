import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../../core/authoring_validation.dart';
import '../../core/binding_validation.dart';
import '../../core/mp_action.dart';

/// Predefined, short system haptic effects.
typedef MpVibrationEffect = MiniProgramVibrationEffect;

/// Explicit, host-approved plain-text clipboard operations.
final class MpClipboardActions {
  const MpClipboardActions();

  /// Copies plain text. Empty text is valid. Sensitive previews are hidden by
  /// default on supporting Android versions; clipboard history is system-owned.
  MpAction writeText({
    required String text,
    bool sensitive = true,
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    if (text.length > miniProgramClipboardMaxTextLength) {
      throw ArgumentError.value(
        text.length,
        'text',
        'Clipboard text is too long.',
      );
    }
    return _systemAction(
      ActionNames.clipboardWriteText,
      {'text': text, 'sensitive': sensitive},
      targetState,
      statusState,
      errorState,
      requestId,
    );
  }

  /// Reads plain text only after a user gesture. Requires separate host read
  /// permission. The result is `{hasText, text}`; non-text content yields null.
  MpAction readText({
    required String targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _systemAction(
    ActionNames.clipboardReadText,
    {},
    targetState,
    statusState,
    errorState,
    requestId,
  );
}

/// Short haptic feedback that honors system preferences.
final class MpVibrationActions {
  const MpVibrationActions();

  /// Requests one system haptic effect. `performed` reports system acceptance,
  /// not a guarantee of physical vibration on every device.
  MpAction trigger({
    MpVibrationEffect effect = MpVibrationEffect.light,
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) => _systemAction(
    ActionNames.vibrationTrigger,
    {'effect': effect.name},
    targetState,
    statusState,
    errorState,
    requestId,
  );
}

/// User-controlled phone dialer actions; never places a call directly.
final class MpPhoneActions {
  const MpPhoneActions();

  MpAction openDialer({
    required String number,
    String? targetState,
    String? statusState,
    String? errorState,
    String? requestId,
  }) {
    final normalized = isFullBinding(number)
        ? number
        : normalizeMiniProgramPhoneNumber(number);
    return _systemAction(
      ActionNames.phoneOpenDialer,
      {'number': normalized},
      targetState,
      statusState,
      errorState,
      requestId,
    );
  }
}

MpAction _systemAction(
  String type,
  Map<String, Object?> values,
  String? targetState,
  String? statusState,
  String? errorState,
  String? requestId,
) => MpAction(
  type,
  props: {
    ...values,
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
