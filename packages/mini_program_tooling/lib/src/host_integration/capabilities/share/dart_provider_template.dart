const String androidShareProviderSource =
    r'''import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

/// Host-owned Android adapter for the platform share chooser.
///
/// Tooling creates this file once and never overwrites host edits.
class AppAndroidShareProvider implements MiniProgramShareProvider {
  const AppAndroidShareProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const String channelName = 'mini_program/share';

  final MethodChannel _channel;

  @override
  Future<MiniProgramShareResult> open(MiniProgramShareRequest request) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'open',
        <String, Object?>{
          'miniProgramId': request.miniProgramId,
          if (request.title != null) 'title': request.title,
          if (request.text != null) 'text': request.text,
          if (request.url != null) 'url': request.url.toString(),
          if (request.mediaRefs.isNotEmpty) 'mediaRefs': request.mediaRefs,
        },
      );
      if (response == null) {
        throw const MiniProgramShareException(
          errorCode: MiniProgramErrorCodes.shareOperationFailed,
          message: 'Android returned an empty share result.',
        );
      }
      try {
        return MiniProgramShareResult.fromJson(response);
      } on FormatException catch (error) {
        throw MiniProgramShareException(
          errorCode: MiniProgramErrorCodes.shareOperationFailed,
          message: error.message.toString(),
        );
      }
    } on PlatformException catch (error) {
      throw _shareException(error);
    } on MissingPluginException {
      throw const MiniProgramShareException(
        errorCode: MiniProgramErrorCodes.shareUnavailable,
        message: 'Android system sharing is unavailable.',
      );
    }
  }

  static MiniProgramShareException _shareException(PlatformException error) {
    const stableCodes = <String>{
      MiniProgramErrorCodes.shareUnavailable,
      MiniProgramErrorCodes.shareInvalidContent,
      MiniProgramErrorCodes.shareMediaNotOwned,
      MiniProgramErrorCodes.shareTooManyItems,
      MiniProgramErrorCodes.shareRequestInProgress,
      MiniProgramErrorCodes.shareOperationFailed,
    };
    return MiniProgramShareException(
      errorCode: stableCodes.contains(error.code)
          ? error.code
          : MiniProgramErrorCodes.shareOperationFailed,
      message: error.message ?? 'Android system sharing failed.',
      details: <String, Object?>{
        if (error.details != null) 'platformDetails': '${error.details}',
      },
    );
  }
}
''';
