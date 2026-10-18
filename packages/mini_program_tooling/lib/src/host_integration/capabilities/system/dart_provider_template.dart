String buildAndroidSystemProvider(String feature) {
  final title = '${feature[0].toUpperCase()}${feature.substring(1)}';
  final methods = switch (feature) {
    'clipboard' =>
      r'''
  @override
  Future<String?> readText({required String miniProgramId,
      required int maxTextLength}) => _invoke<String>('readText', {
        'miniProgramId': miniProgramId, 'maxTextLength': maxTextLength,
      });

  @override
  Future<void> writeText({required String miniProgramId, required String text,
      required bool sensitive}) async {
    await _invoke<void>('writeText', {'miniProgramId': miniProgramId,
      'text': text, 'sensitive': sensitive});
  }
''',
    'vibration' =>
      r'''
  @override
  Future<bool> trigger({required String miniProgramId,
      required MiniProgramVibrationEffect effect}) async {
    final result = await _invoke<bool>('trigger', {
      'miniProgramId': miniProgramId, 'effect': effect.name,
    });
    if (result == null) {
      throw const MiniProgramSystemException(
        errorCode: 'vibration_operation_failed',
        message: 'Android returned an invalid haptic result.');
    }
    return result;
  }
''',
    'phone' =>
      r'''
  @override
  Future<void> openDialer({required String miniProgramId,
      required String number}) async {
    await _invoke<void>('openDialer', {'miniProgramId': miniProgramId,
      'number': normalizeMiniProgramPhoneNumber(number)});
  }
''',
    _ => throw ArgumentError.value(feature),
  };
  return '''import 'package:flutter/services.dart';
${feature == 'clipboard' ? '' : "import 'package:mini_program_contracts/mini_program_contracts.dart';"}
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android adapter. Tooling preserves this file on subsequent runs.
class AppAndroid${title}Provider implements MiniProgram${title}Provider {
  const AppAndroid${title}Provider({
    MethodChannel channel = const MethodChannel('mini_program/$feature'),
  }) : _channel = channel;
  final MethodChannel _channel;
$methods
  Future<T?> _invoke<T>(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const MiniProgramSystemException(errorCode: '${feature}_unavailable',
          message: 'The Android $feature adapter is unavailable.');
    } on PlatformException catch (error) {
      const codes = {'${feature}_unavailable', '${feature}_foreground_required',
        '${feature}_invalid_request', '${feature}_operation_failed'};
      throw MiniProgramSystemException(
        errorCode: codes.contains(error.code) ? error.code : '${feature}_operation_failed',
        message: 'The Android $feature operation failed.');
    }
  }
}
''';
}
