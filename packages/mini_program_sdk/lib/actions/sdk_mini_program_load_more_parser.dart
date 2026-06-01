import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stac/stac.dart';

import '../network/mini_program_backend_connector.dart';
import '../network/mini_program_backend_store.dart';
import '../sdk_context.dart';
import 'sdk_mini_program_load_more_action.dart';

class SdkMiniProgramLoadMoreParser
    extends StacActionParser<SdkMiniProgramLoadMoreAction> {
  const SdkMiniProgramLoadMoreParser();

  @override
  String get actionType => SdkMiniProgramLoadMoreAction.stacActionType;

  @override
  SdkMiniProgramLoadMoreAction getModel(Map<String, dynamic> json) =>
      SdkMiniProgramLoadMoreAction.fromJson(json);

  @override
  FutureOr<dynamic> onCall(
    BuildContext context,
    SdkMiniProgramLoadMoreAction model,
  ) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return MiniProgramPagedBackendSnapshot.fromResult(
        MiniProgramBackendResult.failed(
          requestId: model.requestId,
          endpoint: model.endpoint,
          method: 'GET',
          message:
              'Mini-program SDK scope is unavailable for paged backend dispatch.',
          errorCode: 'mini_program_scope_unavailable',
        ),
        requestId: model.requestId,
        query:
            model.toQuery() ??
            MiniProgramPagedBackendQuery(
              requestId: model.requestId,
              endpoint: 'missing',
            ),
        append: true,
      ).toJson();
    }

    try {
      final query = model.toQuery();
      final interceptor = scope.authController == null
          ? null
          : (request) => scope.authController!.authorizeRequest(
              request: request,
              connector: scope.backendConnector,
            );
      final snapshot = query == null
          ? await scope.backendStore.loadMoreByRequestId(
              connector: scope.backendConnector,
              miniProgramId: scope.miniProgramId,
              requestId: model.requestId,
              requestInterceptor: interceptor,
            )
          : await scope.backendStore.loadMore(
              connector: scope.backendConnector,
              miniProgramId: scope.miniProgramId,
              query: query,
              requestInterceptor: interceptor,
            );
      return snapshot.toJson();
    } catch (error, stackTrace) {
      scope.logger.error(
        'Unhandled mini-program paged backend load-more failure.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'endpoint': model.endpoint,
          'requestId': model.requestId,
        },
      );

      return MiniProgramPagedBackendSnapshot.fromResult(
        MiniProgramBackendResult.failed(
          requestId: model.requestId,
          endpoint: model.endpoint,
          method: 'GET',
          message: 'Unhandled mini-program paged backend load-more failure.',
          errorCode: 'publisher_backend_load_more_failed',
        ),
        requestId: model.requestId,
        query:
            model.toQuery() ??
            MiniProgramPagedBackendQuery(
              requestId: model.requestId,
              endpoint: 'missing',
            ),
        append: true,
      ).toJson();
    }
  }
}
