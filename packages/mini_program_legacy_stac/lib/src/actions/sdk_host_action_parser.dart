import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:stac/stac.dart';

import 'sdk_host_action.dart';

/// Stac action parser that forwards approved host actions into the SDK bridge.
class SdkHostActionParser extends StacActionParser<SdkHostAction> {
  const SdkHostActionParser();

  @override
  String get actionType => SdkHostAction.stacActionType;

  @override
  SdkHostAction getModel(Map<String, dynamic> json) =>
      SdkHostAction.fromJson(json);

  @override
  FutureOr<dynamic> onCall(BuildContext context, SdkHostAction model) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return HostActionResult.failed(
        requestId: model.requestId,
        actionName: model.actionName,
        message:
            'Mini-program SDK scope is unavailable for host action dispatch.',
      );
    }

    final dispatcher = HostActionDispatcher(
      hostBridge: scope.hostBridge,
      logger: scope.logger,
    );

    try {
      return await dispatcher.dispatch(model.toRequest());
    } catch (error, stackTrace) {
      scope.logger.error(
        'Unhandled host action parser failure.',
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
        message: 'Unhandled host action parser failure.',
      );
    }
  }
}
