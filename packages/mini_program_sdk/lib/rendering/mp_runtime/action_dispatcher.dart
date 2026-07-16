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

class _MpActionCallContext {
  const _MpActionCallContext({this.stack = const <String>[]});

  static const int maxDepth = 16;

  final List<String> stack;

  _MpActionCallContext push(String name) => _MpActionCallContext(
    stack: List<String>.unmodifiable(<String>[...stack, name]),
  );
}

abstract final class _MpActionDispatcher {
  static Future<Object?> dispatch(
    BuildContext context,
    _MpAction action,
    _MpRenderBindings bindings, [
    _MpActionCallContext callContext = const _MpActionCallContext(),
  ]) async {
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
      final result = switch (action.type) {
        'auth.showEmailAuth' => _MpAuthBackendActionHandler._showEmailAuth(
          context,
          scope,
          props,
        ),
        'auth.signOut' => _MpAuthBackendActionHandler._signOut(scope),
        'auth.restore' => scope.authController?.restore(
          miniProgramId: scope.miniProgramId,
          connector: scope.backendConnector,
        ),
        'auth.refresh' => _MpAuthBackendActionHandler._refreshAuth(scope),
        'backend.call' => _MpAuthBackendActionHandler._callBackend(
          scope,
          props,
        ),
        'backend.query' => _MpAuthBackendActionHandler._queryBackend(
          scope,
          props,
        ),
        'backend.loadMore' => _MpAuthBackendActionHandler._loadMore(
          scope,
          props,
        ),
        'lazy.chunk.loadMore' =>
          _MpFeedbackFormLazyActionHandler._lazyChunkLoadMore(
            scope,
            props,
            bindings,
          ),
        'search.clear' => _MpBackendSearchActionHandler._searchClear(
          scope,
          props,
        ),
        'search.refresh' => _MpBackendSearchActionHandler._searchRefresh(
          scope,
          props,
        ),
        'search.loadMore' => _MpBackendSearchActionHandler._searchLoadMore(
          scope,
          props,
        ),
        'form.submit' => _MpFeedbackFormLazyActionHandler._submitForm(
          scope,
          props,
        ),
        'ui.toast' => _MpFeedbackFormLazyActionHandler._showToast(
          context,
          props,
        ),
        'ui.dialog' => _MpFeedbackFormLazyActionHandler._showDialog(
          context,
          props,
        ),
        'state.set' || 'state.put' => _MpStateActionHandler._setState(
          scope,
          action.type,
          props,
        ),
        'state.setDefault' => _MpStateActionHandler._setDefaultState(
          scope,
          props,
        ),
        'state.patch' => _MpStateActionHandler._patchState(scope, props),
        'state.increment' => _MpStateActionHandler._mutateNumberState(
          scope,
          props,
          subtract: false,
        ),
        'state.decrement' => _MpStateActionHandler._mutateNumberState(
          scope,
          props,
          subtract: true,
        ),
        'state.copy' => _MpStateActionHandler._copyState(scope, props),
        'state.toggle' => _MpStateActionHandler._toggleState(scope, props),
        'state.appendText' => _MpStateActionHandler._appendStateText(
          scope,
          props,
        ),
        'state.backspace' => _MpStateActionHandler._backspaceStateText(
          scope,
          props,
        ),
        'state.listAppend' => _MpStateActionHandler._addStateListValue(
          scope,
          props,
          prepend: false,
        ),
        'state.listPrepend' => _MpStateActionHandler._addStateListValue(
          scope,
          props,
          prepend: true,
        ),
        'state.listInsert' => _MpStateActionHandler._insertStateListValue(
          scope,
          props,
        ),
        'state.listRemoveAt' => _MpStateActionHandler._removeStateListAt(
          scope,
          props,
        ),
        'state.listRemoveValue' => _MpStateActionHandler._removeStateListValue(
          scope,
          props,
        ),
        'state.remove' => _MpStateActionHandler._removeState(scope, props),
        'state.clear' => _MpStateActionHandler._clearState(scope),
        'math.evaluate' => _MpMathActionHandler._evaluateMath(scope, props),
        'math.compare' => _MpMathActionHandler._compareMath(scope, props),
        'math.randomInt' => _MpMathActionHandler._randomMathInt(scope, props),
        'math.randomDouble' => _MpMathActionHandler._randomMathDouble(
          scope,
          props,
        ),
        'math.aggregate' => _MpMathActionHandler._aggregateMath(scope, props),
        'data.loadJsonAsset' => _MpDataActionHandler._loadJsonDataAsset(
          scope,
          props,
        ),
        'data.search' => _MpDataActionHandler._searchJsonData(scope, props),
        'location.getCurrent' => _MpLocationActionHandler._getCurrentLocation(
          scope,
          props,
        ),
        'cache.set' => _MpCacheActionHandler._cacheSet(scope, props),
        'cache.get' => _MpCacheActionHandler._cacheGet(scope, props),
        'cache.has' => _MpCacheActionHandler._cacheHas(scope, props),
        'cache.remove' => _MpCacheActionHandler._cacheRemove(scope, props),
        'cache.clear' => _MpCacheActionHandler._cacheClear(scope, props),
        'cache.info' => _MpCacheActionHandler._cacheInfo(scope, props),
        'sequence' => _MpCompositionActionHandler._runSequence(
          context,
          props,
          bindings,
          callContext,
        ),
        'action.ifElse' => _MpCompositionActionHandler._runIfElse(
          context,
          props,
          bindings,
          callContext,
        ),
        'action.call' => _MpCompositionActionHandler._runNamedAction(
          context,
          props,
          bindings,
          callContext,
        ),
        'router.push' => _MpNavigationActionHandler._routerPush(scope, props),
        'router.replace' => _MpNavigationActionHandler._routerReplace(
          scope,
          props,
        ),
        'router.reset' => _MpNavigationActionHandler._routerReset(scope, props),
        'router.pop' => _MpNavigationActionHandler._routerPop(scope, props),
        'router.popToRoot' => _MpNavigationActionHandler._routerPopToRoot(
          scope,
          props,
        ),
        'router.popToScreen' => _MpNavigationActionHandler._routerPopToScreen(
          scope,
          props,
        ),
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
      return result is Future<Object?> ? await result : result;
    } on MiniProgramStateLimitException catch (error) {
      return HostActionResult.failed(
        requestId: _optionalStringProp(props, 'requestId'),
        actionName: action.type,
        message: error.toString(),
        errorCode: MiniProgramErrorCodes.stateLimitExceeded,
        data: error.details,
      );
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
}
