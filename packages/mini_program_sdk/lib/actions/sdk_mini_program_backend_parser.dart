import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stac/stac.dart';

import '../network/mini_program_backend_connector.dart';
import '../sdk_context.dart';
import 'sdk_mini_program_backend_action.dart';

/// Stac action parser for publisher-owned mini-program backend calls.
class SdkMiniProgramBackendParser
    extends StacActionParser<SdkMiniProgramBackendAction> {
  const SdkMiniProgramBackendParser();

  @override
  String get actionType => SdkMiniProgramBackendAction.stacActionType;

  @override
  SdkMiniProgramBackendAction getModel(Map<String, dynamic> json) =>
      SdkMiniProgramBackendAction.fromJson(json);

  @override
  FutureOr<dynamic> onCall(
    BuildContext context,
    SdkMiniProgramBackendAction model,
  ) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return MiniProgramBackendResult.failed(
        requestId: model.requestId,
        endpoint: model.endpoint,
        method: model.method,
        message:
            'Mini-program SDK scope is unavailable for backend action dispatch.',
        errorCode: 'mini_program_scope_unavailable',
      );
    }

    final connector = scope.backendConnector;
    if (connector == null) {
      return MiniProgramBackendResult.failed(
        requestId: model.requestId,
        endpoint: model.endpoint,
        method: model.method,
        message:
            'Publisher backend is not configured for mini-program "${scope.miniProgramId}".',
        errorCode: 'publisher_backend_not_configured',
      );
    }

    try {
      var request = model.toRequest(miniProgramId: scope.miniProgramId);
      final authController = scope.authController;
      if (authController != null) {
        request = await authController.authorizeRequest(
          request: request,
          connector: connector,
        );
      }
      return await connector.call(request);
    } catch (error, stackTrace) {
      scope.logger.error(
        'Unhandled mini-program backend parser failure.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'endpoint': model.endpoint,
          'requestId': model.requestId,
        },
      );

      return MiniProgramBackendResult.failed(
        requestId: model.requestId,
        endpoint: model.endpoint,
        method: model.method,
        message: 'Unhandled mini-program backend parser failure.',
        errorCode: 'publisher_backend_action_failed',
      );
    }
  }
}
