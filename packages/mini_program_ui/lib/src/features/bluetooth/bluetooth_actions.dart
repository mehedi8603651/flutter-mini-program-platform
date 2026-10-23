import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';

/// Optional foreground BLE central operations provided by the host.
final class MpBluetoothActions {
  const MpBluetoothActions();

  MpAction getState({
    String? targetState,
    String? statusState,
    String? errorState,
  }) => _action('bluetooth.getState', {}, targetState, statusState, errorState);

  /// Completes with a bounded device list after [timeoutMs] or [stopScan].
  MpAction scan({
    List<String> serviceUuids = const [],
    int timeoutMs = 5000,
    int maxDevices = 20,
    required String targetState,
    String? statusState,
    String? errorState,
  }) => _action(
    'bluetooth.scan',
    {
      'serviceUuids': serviceUuids,
      'timeoutMs': timeoutMs,
      'maxDevices': maxDevices,
    },
    targetState,
    statusState,
    errorState,
  );

  MpAction stopScan() => _action('bluetooth.stopScan', {}, null, null, null);

  /// [deviceId] must come from this mini-program's current scan result.
  MpAction connect({
    required String deviceId,
    int timeoutMs = 10000,
    String? targetState,
    String? statusState,
    String? errorState,
  }) => _action(
    'bluetooth.connect',
    {'deviceId': deviceId, 'timeoutMs': timeoutMs},
    targetState,
    statusState,
    errorState,
  );

  MpAction disconnect() =>
      _action('bluetooth.disconnect', {}, null, null, null);

  MpAction discoverServices({
    required String targetState,
    String? statusState,
    String? errorState,
  }) => _action(
    'bluetooth.discoverServices',
    {},
    targetState,
    statusState,
    errorState,
  );

  MpAction read({
    required String serviceUuid,
    required String characteristicUuid,
    required String targetState,
    String? statusState,
    String? errorState,
  }) => _action(
    'bluetooth.read',
    {'serviceUuid': serviceUuid, 'characteristicUuid': characteristicUuid},
    targetState,
    statusState,
    errorState,
  );

  /// Writes up to 20 bytes as even-length hexadecimal. Larger application
  /// messages require device-specific framing; this API never splits them.
  MpAction write({
    required String serviceUuid,
    required String characteristicUuid,
    required String valueHex,
    bool withoutResponse = false,
    String? targetState,
    String? statusState,
    String? errorState,
  }) => _action(
    'bluetooth.write',
    {
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'valueHex': valueHex,
      'withoutResponse': withoutResponse,
    },
    targetState,
    statusState,
    errorState,
  );

  /// Overwrites [targetState] with the latest bounded notification; no history
  /// is buffered. Ends on disconnect, hiding, disposal, or unsubscribe.
  MpAction subscribe({
    required String serviceUuid,
    required String characteristicUuid,
    required String targetState,
    String? statusState,
    String? errorState,
  }) => _action(
    'bluetooth.subscribe',
    {'serviceUuid': serviceUuid, 'characteristicUuid': characteristicUuid},
    targetState,
    statusState,
    errorState,
  );

  MpAction unsubscribe({
    required String serviceUuid,
    required String characteristicUuid,
  }) => _action(
    'bluetooth.unsubscribe',
    {'serviceUuid': serviceUuid, 'characteristicUuid': characteristicUuid},
    null,
    null,
    null,
  );

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
          throw ArgumentError('BLE result state paths must not overlap.');
        }
      }
    }
    return MpAction(
      type,
      props: {
        ...MiniProgramBluetooth.arguments(type, args, allowBindings: true),
        if (target != null)
          'targetState': requiredStateKey(target, 'targetState'),
        if (status != null)
          'statusState': requiredStateKey(status, 'statusState'),
        if (error != null) 'errorState': requiredStateKey(error, 'errorState'),
      },
    );
  }
}
