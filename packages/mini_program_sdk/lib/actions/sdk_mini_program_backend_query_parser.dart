import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stac/stac.dart';

import '../network/mini_program_backend_connector.dart';
import '../network/mini_program_backend_store.dart';
import '../sdk_context.dart';
import 'sdk_mini_program_backend_query_action.dart';

class SdkMiniProgramBackendQueryParser
    extends StacActionParser<SdkMiniProgramBackendQueryAction> {
  const SdkMiniProgramBackendQueryParser();

  @override
  String get actionType => SdkMiniProgramBackendQueryAction.stacActionType;

  @override
  SdkMiniProgramBackendQueryAction getModel(Map<String, dynamic> json) =>
      SdkMiniProgramBackendQueryAction.fromJson(json);

  @override
  FutureOr<dynamic> onCall(
    BuildContext context,
    SdkMiniProgramBackendQueryAction model,
  ) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return MiniProgramBackendSnapshot.fromResult(
        MiniProgramBackendResult.failed(
          requestId: model.requestId,
          endpoint: model.endpoint,
          method: model.method,
          message:
              'Mini-program SDK scope is unavailable for backend query dispatch.',
          errorCode: 'mini_program_scope_unavailable',
        ),
        requestId: model.requestId,
      ).toJson();
    }

    try {
      final snapshot = await scope.backendStore.runQuery(
        connector: scope.backendConnector,
        miniProgramId: scope.miniProgramId,
        query: model.toQuery(),
      );
      return snapshot.toJson();
    } catch (error, stackTrace) {
      scope.logger.error(
        'Unhandled mini-program backend query failure.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'endpoint': model.endpoint,
          'requestId': model.requestId,
        },
      );

      return MiniProgramBackendSnapshot.fromResult(
        MiniProgramBackendResult.failed(
          requestId: model.requestId,
          endpoint: model.endpoint,
          method: model.method,
          message: 'Unhandled mini-program backend query failure.',
          errorCode: 'publisher_backend_query_failed',
        ),
        requestId: model.requestId,
      ).toJson();
    }
  }
}
