import 'package:json_annotation/json_annotation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../host_bridge.dart';
import '../observability/sdk_logger.dart';

/// Maps approved contract action names to explicit host bridge methods.
class HostActionDispatcher {
  const HostActionDispatcher({required this.hostBridge, required this.logger});

  final HostBridge hostBridge;
  final SdkLogger logger;

  Future<HostActionResult> dispatch(HostActionRequest request) async {
    try {
      switch (request.actionName) {
        case ActionNames.openNativeScreen:
          final payload = OpenNativeScreenActionPayload.fromJson(
            request.payload,
          );
          final result = await hostBridge.openNativeScreen(payload);
          return _correlate(result, request);
        case ActionNames.callSecureApi:
          final payload = CallSecureApiActionPayload.fromJson(request.payload);
          final result = await hostBridge.callSecureApi(payload);
          return _correlate(result, request);
        case ActionNames.trackEvent:
          final payload = TrackEventActionPayload.fromJson(request.payload);
          final result = await hostBridge.trackEvent(payload);
          return _correlate(result, request);
        default:
          logger.warn(
            'Unsupported host action requested.',
            context: <String, Object?>{
              'actionName': request.actionName,
              'requestId': request.requestId,
            },
          );
          return HostActionResult.failed(
            requestId: request.requestId,
            actionName: request.actionName,
            message: 'Unsupported host action "${request.actionName}".',
            errorCode: MiniProgramErrorCodes.unknownAction,
          );
      }
    } on CheckedFromJsonException catch (error, stackTrace) {
      logger.error(
        'Host action payload validation failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'actionName': request.actionName,
          'requestId': request.requestId,
        },
      );
      return HostActionResult.failed(
        requestId: request.requestId,
        actionName: request.actionName,
        message: 'Invalid payload for host action "${request.actionName}".',
        errorCode: MiniProgramErrorCodes.invalidResultPayload,
      );
    } catch (error, stackTrace) {
      logger.error(
        'Host bridge action dispatch threw an exception.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'actionName': request.actionName,
          'requestId': request.requestId,
        },
      );
      return HostActionResult.failed(
        requestId: request.requestId,
        actionName: request.actionName,
        message: 'Host action dispatch failed for "${request.actionName}".',
      );
    }
  }

  HostActionResult _correlate(
    HostActionResult result,
    HostActionRequest request,
  ) {
    return result.copyWith(
      requestId: result.requestId ?? request.requestId,
      actionName: result.actionName ?? request.actionName,
    );
  }
}
