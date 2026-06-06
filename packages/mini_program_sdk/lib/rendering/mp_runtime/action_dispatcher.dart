part of '../mp_screen_renderer.dart';

/// Runs validated Mp JSON actions against the active SDK scope.
class MpActionRunner {
  /// Creates an Mp action runner.
  const MpActionRunner();

  /// Parses and runs a single action JSON object.
  Future<Object?> run(
    BuildContext context,
    Map<String, dynamic> actionJson, {
    Map<String, dynamic>? item,
    Map<String, dynamic>? form,
  }) {
    final action = const MpScreenValidator()._parseAction(
      actionJson,
      path: r'$.action',
    );
    return _MpActionDispatcher.dispatch(
      context,
      action,
      _MpRenderBindings(
        scope: MiniProgramSdkScope.maybeOf(context),
        item: item,
        form: form,
      ),
    );
  }
}

abstract final class _MpActionDispatcher {
  static Future<Object?> dispatch(
    BuildContext context,
    _MpAction action,
    _MpRenderBindings bindings,
  ) async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return HostActionResult.failed(
        actionName: action.type,
        message: 'Mini-program SDK scope is unavailable for Mp action.',
        errorCode: MiniProgramErrorCodes.unknownAction,
      );
    }

    final props = bindings.resolveMap(action.props);
    try {
      return switch (action.type) {
        'auth.showEmailAuth' => _showEmailAuth(context, scope, props),
        'auth.signOut' => _signOut(scope),
        'auth.restore' => scope.authController?.restore(
          miniProgramId: scope.miniProgramId,
          connector: scope.backendConnector,
        ),
        'auth.refresh' => _refreshAuth(scope),
        'backend.call' => _callBackend(scope, props),
        'backend.query' => _queryBackend(scope, props),
        'backend.loadMore' => _loadMore(scope, props),
        'form.submit' => _submitForm(scope, props),
        'ui.toast' => _showToast(context, props),
        'ui.dialog' => _showDialog(context, props),
        'state.set' || 'state.put' => _setState(scope, action.type, props),
        'state.increment' => _incrementState(scope, props),
        'state.remove' => _removeState(scope, props),
        'state.clear' => _clearState(scope),
        'sequence' => _runSequence(context, props, bindings),
        'router.push' => _routerPush(scope, props),
        'router.replace' => _routerReplace(scope, props),
        'router.reset' => _routerReset(scope, props),
        'router.pop' => _routerPop(scope, props),
        'router.popToRoot' => _routerPopToRoot(scope, props),
        'router.popToScreen' => _routerPopToScreen(scope, props),
        'navigation.openScreen' => scope.openMiniProgramScreen(
          OpenMiniProgramScreenActionPayload(
            screenId: _stringProp(props, 'screenId'),
          ),
          _optionalStringProp(props, 'requestId'),
        ),
        'navigation.replaceScreen' => scope.replaceMiniProgramScreen(
          ReplaceMiniProgramScreenActionPayload(
            screenId: _stringProp(props, 'screenId'),
          ),
          _optionalStringProp(props, 'requestId'),
        ),
        'navigation.resetStack' => scope.resetMiniProgramStack(
          ResetMiniProgramStackActionPayload(
            screenId: _stringProp(props, 'screenId'),
          ),
          _optionalStringProp(props, 'requestId'),
        ),
        'navigation.popScreen' => scope.popMiniProgramScreen(
          const PopMiniProgramScreenActionPayload(),
          _optionalStringProp(props, 'requestId'),
        ),
        'navigation.popToRoot' => scope.popToMiniProgramRoot(
          const PopToMiniProgramRootActionPayload(),
          _optionalStringProp(props, 'requestId'),
        ),
        'navigation.popToScreen' => scope.popToMiniProgramScreen(
          PopToMiniProgramScreenActionPayload(
            screenId: _stringProp(props, 'screenId'),
          ),
          _optionalStringProp(props, 'requestId'),
        ),
        _ => HostActionResult.failed(
          requestId: _optionalStringProp(props, 'requestId'),
          actionName: action.type,
          message: 'Unsupported Mp action "${action.type}".',
          errorCode: MiniProgramErrorCodes.unknownAction,
        ),
      };
    } catch (error, stackTrace) {
      scope.logger.error(
        'Unhandled Mp action failure.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'actionType': action.type,
        },
      );
      return HostActionResult.failed(
        requestId: _optionalStringProp(props, 'requestId'),
        actionName: action.type,
        message: 'Unhandled Mp action failure.',
      );
    }
  }

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
            'Publisher backend is not configured for mini-program "${scope.miniProgramId}".',
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
            query: _pagedQueryFromProps(props),
            requestInterceptor: interceptor,
          );
    return snapshot.toJson();
  }

  static Future<MiniProgramBackendResult> _submitForm(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    return _callBackend(scope, props);
  }

  static Future<HostActionResult> _showToast(
    BuildContext context,
    Map<String, dynamic> props,
  ) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return HostActionResult.failed(
        actionName: 'ui.toast',
        message: 'Overlay is unavailable for Mp toast.',
      );
    }
    final message = _stringProp(props, 'message');
    final durationMs = _intProp(props, 'durationMs', fallback: 2400);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 20,
        right: 20,
        bottom: 28,
        child: _MpToastView(message: message),
      ),
    );
    overlay.insert(entry);
    await Future<void>.delayed(Duration(milliseconds: durationMs));
    entry.remove();
    return HostActionResult.success(actionName: 'ui.toast');
  }

  static Future<HostActionResult> _showDialog(
    BuildContext context,
    Map<String, dynamic> props,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color(0x66000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) => _MpDialogView(
        title: _optionalStringProp(props, 'title'),
        message: _stringProp(props, 'message'),
        confirmLabel: _optionalStringProp(props, 'confirmLabel') ?? 'OK',
      ),
    );
    return HostActionResult.success(actionName: 'ui.dialog');
  }

  static Future<HostActionResult> _setState(
    MiniProgramSdkScope scope,
    String actionName,
    Map<String, dynamic> props,
  ) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable(actionName);
    }
    state.set(_stringProp(props, 'key'), props['value']);
    return HostActionResult.success(actionName: actionName);
  }

  static Future<HostActionResult> _incrementState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable('state.increment');
    }
    final key = _stringProp(props, 'key');
    final current = state.get<Object?>(key);
    if (current != null && current is! num) {
      return HostActionResult.failed(
        actionName: 'state.increment',
        message: 'Mp state.increment requires a numeric current value.',
        errorCode: 'state_invalid_value',
      );
    }
    final by = _numProp(props, 'by', fallback: 1);
    final next = (current as num? ?? 0) + by;
    state.set(key, next);
    return HostActionResult.success(actionName: 'state.increment');
  }

  static Future<HostActionResult> _removeState(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable('state.remove');
    }
    state.remove(_stringProp(props, 'key'));
    return HostActionResult.success(actionName: 'state.remove');
  }

  static Future<HostActionResult> _clearState(MiniProgramSdkScope scope) async {
    final state = scope.stateManager;
    if (state == null) {
      return _stateUnavailable('state.clear');
    }
    state.clear();
    return HostActionResult.success(actionName: 'state.clear');
  }

  static Future<HostActionResult> _runSequence(
    BuildContext context,
    Map<String, dynamic> props,
    _MpRenderBindings bindings,
  ) async {
    final steps = props['steps'];
    if (steps is! List || steps.any((step) => step is! _MpAction)) {
      return HostActionResult.failed(
        actionName: 'sequence',
        message: 'Mp sequence requires parsed action steps.',
        errorCode: MiniProgramErrorCodes.unknownAction,
      );
    }
    Object? lastResult;
    for (final step in steps) {
      lastResult = await dispatch(context, step as _MpAction, bindings);
      if (lastResult is HostActionResult && !lastResult.isSuccess) {
        return lastResult;
      }
    }
    return HostActionResult.success(
      actionName: 'sequence',
      data: <String, dynamic>{
        if (lastResult is HostActionResult) 'lastResult': lastResult.toJson(),
      },
    );
  }

  static Future<HostActionResult> _routerPush(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(_routerUnavailable('router.push'));
    }
    return router.push(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'params'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerReplace(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(
        _routerUnavailable('router.replace'),
      );
    }
    return router.replace(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'params'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerReset(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(_routerUnavailable('router.reset'));
    }
    return router.reset(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'params'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerPop(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(_routerUnavailable('router.pop'));
    }
    return router.pop(
      _mapProp(props, 'result'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerPopToRoot(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(
        _routerUnavailable('router.popToRoot'),
      );
    }
    return router.popToRoot(
      _mapProp(props, 'result'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static Future<HostActionResult> _routerPopToScreen(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) {
    final router = scope.router;
    if (router == null) {
      return Future<HostActionResult>.value(
        _routerUnavailable('router.popToScreen'),
      );
    }
    return router.popToScreen(
      _stringProp(props, 'screenId'),
      _mapProp(props, 'result'),
      _optionalStringProp(props, 'requestId'),
    );
  }

  static HostActionResult _stateUnavailable(String actionName) {
    return HostActionResult.failed(
      actionName: actionName,
      message: 'Mp state manager is unavailable.',
      errorCode: 'state_unavailable',
    );
  }

  static HostActionResult _routerUnavailable(String actionName) {
    return HostActionResult.failed(
      actionName: actionName,
      message: 'Mp router is unavailable.',
      errorCode: 'router_unavailable',
    );
  }

  static Future<MiniProgramBackendRequest> _authorize(
    MiniProgramSdkScope scope,
    MiniProgramBackendRequest request,
  ) {
    final controller = scope.authController;
    if (controller == null) {
      return Future<MiniProgramBackendRequest>.value(request);
    }
    return controller.authorizeRequest(
      request: request,
      connector: scope.backendConnector,
    );
  }

  static MiniProgramPagedBackendQuery _pagedQueryFromProps(
    Map<String, dynamic> props,
  ) {
    return MiniProgramPagedBackendQuery(
      requestId: _stringProp(props, 'requestId'),
      endpoint: _stringProp(props, 'endpoint'),
      limit: _intProp(props, 'limit', fallback: 20),
      initialCursor: _optionalStringProp(props, 'initialCursor'),
      cursorParam: _optionalStringProp(props, 'cursorParam') ?? 'cursor',
      limitParam: _optionalStringProp(props, 'limitParam') ?? 'limit',
      itemsPath: _optionalStringProp(props, 'itemsPath') ?? 'items',
      nextCursorPath:
          _optionalStringProp(props, 'nextCursorPath') ?? 'nextCursor',
      hasMorePath: _optionalStringProp(props, 'hasMorePath') ?? 'hasMore',
      cacheTtl: _cacheTtl(props),
    );
  }

  static MiniProgramBackendCachePolicy _cachePolicy(
    Map<String, dynamic> props,
  ) {
    final ttl = _cacheTtl(props);
    return ttl == null
        ? const MiniProgramBackendCachePolicy.noCache()
        : MiniProgramBackendCachePolicy(ttl: ttl);
  }

  static Duration? _cacheTtl(Map<String, dynamic> props) {
    final value = props['cacheTtlSeconds'];
    return value is int ? Duration(seconds: value) : null;
  }

  static String _stringProp(Map<String, dynamic> props, String key) {
    final value = props[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw FormatException('Mp action requires a non-empty "$key" string.');
  }

  static String? _optionalStringProp(Map<String, dynamic> props, String key) {
    final value = props[key];
    if (value == null) {
      return null;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw FormatException('Mp action "$key" must be a non-empty string.');
  }

  static Map<String, dynamic> _mapProp(Map<String, dynamic> props, String key) {
    final value = props[key];
    if (value == null) {
      return const <String, dynamic>{};
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw FormatException('Mp action "$key" must be an object.');
  }

  static bool _boolProp(Map<String, dynamic> props, String key) {
    final value = props[key];
    return value is bool && value;
  }

  static int _intProp(
    Map<String, dynamic> props,
    String key, {
    required int fallback,
  }) {
    final value = props[key];
    if (value == null) {
      return fallback;
    }
    if (value is int) {
      return value;
    }
    throw FormatException('Mp action "$key" must be an integer.');
  }

  static num _numProp(
    Map<String, dynamic> props,
    String key, {
    required num fallback,
  }) {
    final value = props[key];
    if (value == null) {
      return fallback;
    }
    if (value is num) {
      return value;
    }
    throw FormatException('Mp action "$key" must be numeric.');
  }
}
