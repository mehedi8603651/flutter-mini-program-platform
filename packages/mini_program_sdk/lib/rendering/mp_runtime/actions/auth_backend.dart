part of '../../mp_screen_renderer.dart';

abstract final class _MpAuthBackendActionHandler {
  static Future<MiniProgramAuthResult?> _showEmailAuth(
    BuildContext context,
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final controller = scope.authController;
    final connector = scope.backendConnector;
    if (controller == null || connector == null) {
      scope.logger.warn(
        'Mp auth action ignored because auth or backend is not configured.',
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'actionType': 'auth.showEmailAuth',
        },
      );
      return Future<MiniProgramAuthResult?>.value();
    }
    final mode = _optionalStringProp(props, 'mode');
    return showMiniProgramEmailAuthSheet(
      context: context,
      controller: controller,
      connector: connector,
      miniProgramId: scope.miniProgramId,
      initialMode: mode == 'signUp'
          ? MiniProgramEmailAuthMode.signUp
          : MiniProgramEmailAuthMode.signIn,
    );
  }

  static Future<MiniProgramAuthResult?> _refreshAuth(
    MiniProgramSdkScope scope,
  ) {
    final controller = scope.authController;
    final connector = scope.backendConnector;
    if (controller == null || connector == null) {
      return Future<MiniProgramAuthResult?>.value();
    }
    return controller.refresh(
      miniProgramId: scope.miniProgramId,
      connector: connector,
    );
  }

  static Future<MiniProgramAuthResult?> _signOut(
    MiniProgramSdkScope scope,
  ) async {
    final result = await scope.authController?.signOut(
      miniProgramId: scope.miniProgramId,
      connector: scope.backendConnector,
    );
    await scope.cacheManager.clearOnLogout(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    return result;
  }

  static Future<MiniProgramBackendResult> _callBackend(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final connector = scope.backendConnector;
    if (connector == null) {
      return MiniProgramBackendResult.failed(
        requestId: _optionalStringProp(props, 'requestId'),
        endpoint: _stringProp(props, 'endpoint'),
        method: _optionalStringProp(props, 'method') ?? 'GET',
        message:
            'Publisher API is not configured for mini-program "${scope.miniProgramId}".',
        errorCode: 'publisher_backend_not_configured',
      );
    }
    var request = MiniProgramBackendRequest(
      miniProgramId: scope.miniProgramId,
      requestId: _optionalStringProp(props, 'requestId'),
      endpoint: _stringProp(props, 'endpoint'),
      method: _optionalStringProp(props, 'method') ?? 'GET',
      body: _mapProp(props, 'body'),
      cachePolicy: _cachePolicy(props),
    );
    request = await _authorize(scope, request);
    return connector.call(request);
  }

  static Future<Map<String, dynamic>> _queryBackend(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final snapshot = await scope.backendStore.runQuery(
      connector: scope.backendConnector,
      miniProgramId: scope.miniProgramId,
      query: MiniProgramBackendQuery(
        requestId: _stringProp(props, 'requestId'),
        endpoint: _stringProp(props, 'endpoint'),
        method: _optionalStringProp(props, 'method') ?? 'GET',
        body: _mapProp(props, 'body'),
        cacheTtl: _cacheTtl(props),
        forceRefresh: _boolProp(props, 'forceRefresh'),
      ),
      requestInterceptor: scope.authController == null
          ? null
          : (request) => _authorize(scope, request),
    );
    return snapshot.toJson();
  }

  static Future<Map<String, dynamic>> _loadMore(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final endpoint = _optionalStringProp(props, 'endpoint');
    final interceptor = scope.authController == null
        ? null
        : (request) => _authorize(scope, request);
    final snapshot = endpoint == null
        ? await scope.backendStore.loadMoreByRequestId(
            connector: scope.backendConnector,
            miniProgramId: scope.miniProgramId,
            requestId: _stringProp(props, 'requestId'),
            requestInterceptor: interceptor,
          )
        : await scope.backendStore.loadMore(
            connector: scope.backendConnector,
            miniProgramId: scope.miniProgramId,
            query: _MpBackendSearchActionHandler._pagedQueryFromProps(props),
            requestInterceptor: interceptor,
          );
    return snapshot.toJson();
  }
}
