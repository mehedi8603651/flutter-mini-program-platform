import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:stac/stac.dart';

import '../sdk_context.dart';
import 'sdk_mini_program_navigation_action.dart';

/// Stac action parser for internal mini-program page-to-page navigation.
class SdkMiniProgramNavigationParser
    extends StacActionParser<SdkMiniProgramNavigationAction> {
  const SdkMiniProgramNavigationParser();

  @override
  String get actionType => SdkMiniProgramNavigationAction.stacActionType;

  @override
  SdkMiniProgramNavigationAction getModel(Map<String, dynamic> json) =>
      SdkMiniProgramNavigationAction.fromJson(json);

  @override
  FutureOr<dynamic> onCall(
    BuildContext context,
    SdkMiniProgramNavigationAction model,
  ) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return HostActionResult.failed(
        requestId: model.requestId,
        actionName: model.actionName,
        message:
            'Mini-program SDK scope is unavailable for mini-program navigation.',
      );
    }

    try {
      switch (model.actionName) {
        case ActionNames.openMiniProgramScreen:
          final payload = OpenMiniProgramScreenActionPayload.fromJson(
            model.payload,
          );
          return await scope.openMiniProgramScreen(payload, model.requestId);
        case ActionNames.resetMiniProgramStack:
          final payload = ResetMiniProgramStackActionPayload.fromJson(
            model.payload,
          );
          return await scope.resetMiniProgramStack(payload, model.requestId);
        case ActionNames.replaceMiniProgramScreen:
          final payload = ReplaceMiniProgramScreenActionPayload.fromJson(
            model.payload,
          );
          return await scope.replaceMiniProgramScreen(payload, model.requestId);
        case ActionNames.popMiniProgramScreen:
          final payload = PopMiniProgramScreenActionPayload.fromJson(
            model.payload,
          );
          return await scope.popMiniProgramScreen(payload, model.requestId);
        case ActionNames.popToMiniProgramRoot:
          final payload = PopToMiniProgramRootActionPayload.fromJson(
            model.payload,
          );
          return await scope.popToMiniProgramRoot(payload, model.requestId);
        case ActionNames.popToMiniProgramScreen:
          final payload = PopToMiniProgramScreenActionPayload.fromJson(
            model.payload,
          );
          return await scope.popToMiniProgramScreen(payload, model.requestId);
        default:
          scope.logger.warn(
            'Unsupported mini-program navigation action requested.',
            context: <String, Object?>{
              'miniProgramId': scope.miniProgramId,
              'actionName': model.actionName,
              'requestId': model.requestId,
            },
          );
          return HostActionResult.failed(
            requestId: model.requestId,
            actionName: model.actionName,
            message:
                'Unsupported mini-program navigation action "${model.actionName}".',
            errorCode: MiniProgramErrorCodes.unknownAction,
          );
      }
    } on FormatException catch (error, stackTrace) {
      scope.logger.error(
        'Mini-program navigation payload validation failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'actionName': model.actionName,
          'requestId': model.requestId,
        },
      );
      return HostActionResult.failed(
        requestId: model.requestId,
        actionName: model.actionName,
        message:
            'Invalid payload for mini-program navigation "${model.actionName}".',
        errorCode: MiniProgramErrorCodes.invalidResultPayload,
      );
    } catch (error, stackTrace) {
      scope.logger.error(
        'Unhandled mini-program navigation parser failure.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'actionName': model.actionName,
          'requestId': model.requestId,
        },
      );

      return HostActionResult.failed(
        requestId: model.requestId,
        actionName: model.actionName,
        message:
            'Unhandled mini-program navigation parser failure for "${model.actionName}".',
      );
    }
  }
}
