const androidNfcProviderSource = r'''
import 'package:flutter/services.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned optional NFC adapter. Generated once; customize this file if needed.
class AppAndroidNfcProvider implements MiniProgramNfcProvider {
  const AppAndroidNfcProvider();
  static const _channel = MethodChannel('mini_program/nfc');

  @override
  Future<Map<String, dynamic>> invoke({required String miniProgramId,
    required String sessionId, required String action, required Map<String, dynamic> arguments}) async {
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(action, {
        ...arguments, 'appId': miniProgramId, 'sessionId': sessionId,
      });
      if (data == null) {
        throw const MiniProgramNfcException(errorCode: 'nfc_invalid_result', message: 'Android returned no NFC result.');
      }
      return data;
    } on MissingPluginException {
      throw const MiniProgramNfcException(errorCode: 'nfc_unavailable', message: 'The Android NFC adapter is not installed.');
    } on PlatformException catch (error) {
      const codes = {'nfc_unavailable', 'nfc_disabled', 'nfc_permission_denied',
        'nfc_foreground_required', 'nfc_invalid_request', 'nfc_in_use',
        'nfc_request_in_progress', 'nfc_request_cancelled', 'nfc_timeout',
        'nfc_unsupported_tag', 'nfc_unsupported_record', 'nfc_invalid_data',
        'nfc_tag_lost', 'nfc_limit_exceeded', 'nfc_operation_failed'};
      final code = codes.contains(error.code) ? error.code : 'nfc_operation_failed';
      throw MiniProgramNfcException(errorCode: code, message: 'Android NFC operation did not complete ($code).');
    }
  }

  @override
  Future<void> release({required String miniProgramId, required String sessionId}) async {
    try { await _channel.invokeMethod<void>('release', {'appId': miniProgramId, 'sessionId': sessionId}); }
    on MissingPluginException { /* Optional provider is not installed. */ }
    on PlatformException { /* Native lifecycle independently releases its exact session. */ }
  }
}
''';
