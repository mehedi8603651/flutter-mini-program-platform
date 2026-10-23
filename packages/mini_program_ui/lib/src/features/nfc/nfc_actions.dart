import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Optional host-approved foreground NDEF reading. Tag contents remain data.
final class MpNfcActions {
  const MpNfcActions();

  MpAction getState({
    String? targetState,
    String? statusState,
    String? errorState,
  }) => _action('nfc.getState', {}, targetState, statusState, errorState);

  /// Reads one NDEF message containing supported text and HTTPS URI records.
  /// Requires an explicit user action. Hiding the mini-program cancels reading.
  MpAction read({
    int timeoutMs = 15000,
    required String targetState,
    String? statusState,
    String? errorState,
  }) => _action(
    'nfc.read',
    {'timeoutMs': timeoutMs},
    targetState,
    statusState,
    errorState,
  );

  MpAction cancel() => _action('nfc.cancel', {}, null, null, null);

  MpAction _action(
    String type,
    Map<String, dynamic> args,
    String? target,
    String? status,
    String? error,
  ) {
    final keys = [target, status, error].whereType<String>().toList();
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        if (keys[i] == keys[j] ||
            keys[i].startsWith('${keys[j]}.') ||
            keys[j].startsWith('${keys[i]}.')) {
          throw ArgumentError('NFC result state paths must not overlap.');
        }
      }
    }
    return MpAction(
      type,
      props: {
        ...MiniProgramNfc.arguments(type, args),
        if (target != null)
          'targetState': requiredStateKey(target, 'targetState'),
        if (status != null)
          'statusState': requiredStateKey(status, 'statusState'),
        if (error != null) 'errorState': requiredStateKey(error, 'errorState'),
      },
    );
  }
}
