const androidBluetoothProviderSource = r'''
import 'package:flutter/services.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned optional BLE adapter. Generated once; customize this file if needed.
class AppAndroidBluetoothProvider implements MiniProgramBluetoothProvider {
  const AppAndroidBluetoothProvider();
  static const _channel = MethodChannel('mini_program/bluetooth');
  static const _events = EventChannel('mini_program/bluetooth/events');
  static final _stream = _events.receiveBroadcastStream().where((value) => value is Map).map((value) {
    final data = Map<String, dynamic>.from(value as Map);
    return MiniProgramBluetoothEvent(
      miniProgramId: data['appId'] as String, sessionId: data['sessionId'] as String,
      type: data['type'] as String, data: Map<String, dynamic>.from(data['data'] as Map));
  }).asBroadcastStream();

  @override
  Stream<MiniProgramBluetoothEvent> get events => _stream;

  @override
  Future<Map<String, dynamic>> invoke({required String miniProgramId,
    required String sessionId, required String action, required Map<String, dynamic> arguments}) async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(action, {
        'appId': miniProgramId, 'sessionId': sessionId, ...arguments,
      });
      if (data == null) {
        throw const MiniProgramBluetoothException(
          errorCode: 'bluetooth_invalid_result', message: 'Android returned no BLE result.');
      }
      return data;
    } on MissingPluginException {
      throw const MiniProgramBluetoothException(errorCode: 'bluetooth_unavailable',
        message: 'The Android BLE adapter is not installed.');
    } on PlatformException catch (error) {
      const codes = {'bluetooth_unavailable', 'bluetooth_disabled', 'bluetooth_permission_denied',
        'bluetooth_foreground_required', 'bluetooth_invalid_request', 'bluetooth_in_use',
        'bluetooth_request_in_progress', 'bluetooth_request_cancelled', 'bluetooth_timeout',
        'bluetooth_device_not_found', 'bluetooth_not_connected',
        'bluetooth_characteristic_unsupported', 'bluetooth_limit_exceeded', 'bluetooth_operation_failed'};
      throw MiniProgramBluetoothException(errorCode: codes.contains(error.code) ? error.code : 'bluetooth_operation_failed',
        message: 'Android BLE operation did not complete (${codes.contains(error.code) ? error.code : 'bluetooth_operation_failed'}).');
    }
  }

  @override
  Future<void> release({required String miniProgramId, required String sessionId}) async {
    try { await _channel.invokeMethod<void>('release', {'appId': miniProgramId, 'sessionId': sessionId}); }
    on MissingPluginException { /* Optional provider is not installed. */ }
    on PlatformException { /* Native lifecycle also releases its exact session. */ }
  }
}
''';
