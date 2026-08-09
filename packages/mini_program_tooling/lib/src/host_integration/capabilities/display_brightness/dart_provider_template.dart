const String androidDisplayBrightnessProviderSource =
    r'''import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android adapter for temporary window brightness.
///
/// Tooling creates this file once and never overwrites host edits.
class AppAndroidDisplayBrightnessProvider
    implements MiniProgramDisplayBrightnessProvider {
  const AppAndroidDisplayBrightnessProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/display_brightness';

  final MethodChannel _channel;

  @override
  Future<void> setBrightness(double level) =>
      _invoke('setBrightness', <String, Object?>{'level': level});

  @override
  Future<void> restoreBrightness() => _invoke('restoreBrightness');

  Future<void> _invoke(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      throw _brightnessException(error);
    } on MissingPluginException {
      throw const MiniProgramDisplayBrightnessException(
        errorCode: MiniProgramErrorCodes.displayBrightnessUnavailable,
        message: 'Android display brightness support is unavailable.',
      );
    }
  }

  static MiniProgramDisplayBrightnessException _brightnessException(
    PlatformException error,
  ) {
    const stableCodes = <String>{
      MiniProgramErrorCodes.displayBrightnessUnavailable,
      MiniProgramErrorCodes.displayBrightnessInvalidLevel,
      MiniProgramErrorCodes.displayBrightnessOperationFailed,
    };
    return MiniProgramDisplayBrightnessException(
      errorCode: stableCodes.contains(error.code)
          ? error.code
          : MiniProgramErrorCodes.displayBrightnessOperationFailed,
      message: error.message ?? 'Android display brightness operation failed.',
      details: <String, Object?>{
        if (error.details != null) 'platformDetails': '${error.details}',
      },
    );
  }
}
''';
