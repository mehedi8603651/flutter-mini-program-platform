part of '../mini_program_host.dart';

extension _MiniProgramHostNavigation on _MiniProgramHostState {
  Future<HostActionResult> _openMiniProgramScreen(
    OpenMiniProgramScreenActionPayload payload,
    String? requestId,
  ) async {
    final manifest = _manifest;
    if (manifest == null) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.openMiniProgramScreen,
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }

    final screen = await _loadNavigationScreen(
      manifest: manifest,
      screenId: payload.screenId,
    );
    if (!mounted) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.openMiniProgramScreen,
        message: 'Mini-program host was disposed before navigation completed.',
      );
    }

    _updateState(() {
      _screenStack = <_RenderedMiniProgramScreen>[..._screenStack, screen];
    });

    return screen.failure == null
        ? HostActionResult.success(
            requestId: requestId,
            actionName: ActionNames.openMiniProgramScreen,
            message: 'Opened mini-program screen "${payload.screenId}".',
            data: <String, dynamic>{'screenId': payload.screenId},
          )
        : HostActionResult.failed(
            requestId: requestId,
            actionName: ActionNames.openMiniProgramScreen,
            message: screen.failure!.message,
            errorCode: screen.failure!.errorCode,
            data: <String, dynamic>{
              'screenId': payload.screenId,
              ...screen.failure!.details,
            },
          );
  }

  Future<HostActionResult> _replaceMiniProgramScreen(
    ReplaceMiniProgramScreenActionPayload payload,
    String? requestId,
  ) async {
    final manifest = _manifest;
    if (manifest == null) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.replaceMiniProgramScreen,
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }

    final screen = await _loadNavigationScreen(
      manifest: manifest,
      screenId: payload.screenId,
    );
    if (!mounted) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.replaceMiniProgramScreen,
        message: 'Mini-program host was disposed before navigation completed.',
      );
    }

    _updateState(() {
      if (_screenStack.isEmpty) {
        _screenStack = <_RenderedMiniProgramScreen>[screen];
      } else {
        final updatedStack = List<_RenderedMiniProgramScreen>.from(_screenStack)
          ..removeLast()
          ..add(screen);
        _screenStack = updatedStack;
      }
    });

    return screen.failure == null
        ? HostActionResult.success(
            requestId: requestId,
            actionName: ActionNames.replaceMiniProgramScreen,
            message: 'Replaced with mini-program screen "${payload.screenId}".',
            data: <String, dynamic>{'screenId': payload.screenId},
          )
        : HostActionResult.failed(
            requestId: requestId,
            actionName: ActionNames.replaceMiniProgramScreen,
            message: screen.failure!.message,
            errorCode: screen.failure!.errorCode,
            data: <String, dynamic>{
              'screenId': payload.screenId,
              ...screen.failure!.details,
            },
          );
  }

  Future<HostActionResult> _resetMiniProgramStack(
    ResetMiniProgramStackActionPayload payload,
    String? requestId,
  ) async {
    final manifest = _manifest;
    if (manifest == null) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.resetMiniProgramStack,
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }

    final screen = await _loadNavigationScreen(
      manifest: manifest,
      screenId: payload.screenId,
    );
    if (!mounted) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.resetMiniProgramStack,
        message: 'Mini-program host was disposed before navigation completed.',
      );
    }

    _updateState(() {
      _screenStack = <_RenderedMiniProgramScreen>[screen];
    });

    return screen.failure == null
        ? HostActionResult.success(
            requestId: requestId,
            actionName: ActionNames.resetMiniProgramStack,
            message:
                'Reset mini-program stack to screen "${payload.screenId}".',
            data: <String, dynamic>{'screenId': payload.screenId},
          )
        : HostActionResult.failed(
            requestId: requestId,
            actionName: ActionNames.resetMiniProgramStack,
            message: screen.failure!.message,
            errorCode: screen.failure!.errorCode,
            data: <String, dynamic>{
              'screenId': payload.screenId,
              ...screen.failure!.details,
            },
          );
  }

  Future<HostActionResult> _popMiniProgramScreen(
    PopMiniProgramScreenActionPayload payload,
    String? requestId,
  ) async {
    if (_screenStack.length <= 1) {
      return HostActionResult.cancelled(
        requestId: requestId,
        actionName: ActionNames.popMiniProgramScreen,
        message: 'Mini-program is already showing the root screen.',
        data: payload.toJson(),
      );
    }

    _updateState(() {
      final updatedStack = List<_RenderedMiniProgramScreen>.from(_screenStack)
        ..removeLast();
      _screenStack = updatedStack;
    });

    return HostActionResult.success(
      requestId: requestId,
      actionName: ActionNames.popMiniProgramScreen,
      message: 'Returned to the previous mini-program screen.',
      data: payload.toJson(),
    );
  }

  Future<HostActionResult> _popToMiniProgramRoot(
    PopToMiniProgramRootActionPayload payload,
    String? requestId,
  ) async {
    if (_screenStack.isEmpty) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.popToMiniProgramRoot,
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }

    final rootScreen = _screenStack.first;
    final didPop = _screenStack.length > 1;
    if (didPop) {
      _updateState(() {
        _screenStack = <_RenderedMiniProgramScreen>[rootScreen];
      });
    }

    return HostActionResult.success(
      requestId: requestId,
      actionName: ActionNames.popToMiniProgramRoot,
      message: didPop
          ? 'Returned to the root mini-program screen.'
          : 'Mini-program is already showing the root screen.',
      data: <String, dynamic>{'screenId': rootScreen.screenId},
    );
  }

  Future<HostActionResult> _popToMiniProgramScreen(
    PopToMiniProgramScreenActionPayload payload,
    String? requestId,
  ) async {
    final targetIndex = _screenStack.lastIndexWhere(
      (screen) => screen.screenId == payload.screenId,
    );
    if (targetIndex < 0) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: ActionNames.popToMiniProgramScreen,
        message:
            'Screen "${payload.screenId}" is not present in the current mini-program stack.',
        errorCode: MiniProgramErrorCodes.screenNotInStack,
        data: <String, dynamic>{'screenId': payload.screenId},
      );
    }

    final didPop = targetIndex < _screenStack.length - 1;
    if (didPop) {
      _updateState(() {
        _screenStack = List<_RenderedMiniProgramScreen>.from(
          _screenStack.take(targetIndex + 1),
        );
      });
    }

    return HostActionResult.success(
      requestId: requestId,
      actionName: ActionNames.popToMiniProgramScreen,
      message: didPop
          ? 'Returned to mini-program screen "${payload.screenId}".'
          : 'Mini-program is already showing screen "${payload.screenId}".',
      data: <String, dynamic>{'screenId': payload.screenId},
    );
  }

  Future<HostActionResult> _mpRouterPush(
    String screenId,
    Map<String, dynamic> params,
    String? requestId,
  ) async {
    final manifest = _manifest;
    if (manifest == null) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.push',
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }
    final screen = await _loadNavigationScreen(
      manifest: manifest,
      screenId: screenId,
      routeParams: _normalizeRouteMap(params),
    );
    if (!mounted) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.push',
        message: 'Mini-program host was disposed before navigation completed.',
      );
    }
    _updateState(() {
      _screenStack = <_RenderedMiniProgramScreen>[..._screenStack, screen];
    });
    return _routerResult(
      requestId: requestId,
      actionName: 'router.push',
      screen: screen,
    );
  }

  Future<HostActionResult> _mpRouterReplace(
    String screenId,
    Map<String, dynamic> params,
    String? requestId,
  ) async {
    final manifest = _manifest;
    if (manifest == null) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.replace',
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }
    final screen = await _loadNavigationScreen(
      manifest: manifest,
      screenId: screenId,
      routeParams: _normalizeRouteMap(params),
    );
    if (!mounted) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.replace',
        message: 'Mini-program host was disposed before navigation completed.',
      );
    }
    _updateState(() {
      if (_screenStack.isEmpty) {
        _screenStack = <_RenderedMiniProgramScreen>[screen];
      } else {
        _screenStack = List<_RenderedMiniProgramScreen>.from(_screenStack)
          ..removeLast()
          ..add(screen);
      }
    });
    return _routerResult(
      requestId: requestId,
      actionName: 'router.replace',
      screen: screen,
    );
  }

  Future<HostActionResult> _mpRouterReset(
    String screenId,
    Map<String, dynamic> params,
    String? requestId,
  ) async {
    final manifest = _manifest;
    if (manifest == null) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.reset',
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }
    final screen = await _loadNavigationScreen(
      manifest: manifest,
      screenId: screenId,
      routeParams: _normalizeRouteMap(params),
    );
    if (!mounted) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.reset',
        message: 'Mini-program host was disposed before navigation completed.',
      );
    }
    _updateState(() {
      _screenStack = <_RenderedMiniProgramScreen>[screen];
    });
    return _routerResult(
      requestId: requestId,
      actionName: 'router.reset',
      screen: screen,
    );
  }

  Future<HostActionResult> _mpRouterPop(
    Map<String, dynamic> result,
    String? requestId,
  ) async {
    if (_screenStack.length <= 1) {
      return HostActionResult.cancelled(
        requestId: requestId,
        actionName: 'router.pop',
        message: 'Mini-program is already showing the root screen.',
      );
    }
    final routeResult = _normalizeRouteMap(result);
    _updateState(() {
      final updatedStack = List<_RenderedMiniProgramScreen>.from(_screenStack)
        ..removeLast();
      updatedStack[updatedStack.length - 1] = updatedStack.last.withRouteResult(
        routeResult,
      );
      _screenStack = updatedStack;
    });
    return HostActionResult.success(
      requestId: requestId,
      actionName: 'router.pop',
      message: 'Returned to the previous mini-program screen.',
      data: <String, dynamic>{'result': routeResult},
    );
  }

  Future<HostActionResult> _mpRouterPopToRoot(
    Map<String, dynamic> result,
    String? requestId,
  ) async {
    if (_screenStack.isEmpty) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.popToRoot',
        message: 'Mini-program runtime is not ready for screen navigation.',
      );
    }
    final routeResult = _normalizeRouteMap(result);
    final rootScreen = _screenStack.first.withRouteResult(routeResult);
    final didPop = _screenStack.length > 1;
    _updateState(() {
      _screenStack = <_RenderedMiniProgramScreen>[rootScreen];
    });
    return HostActionResult.success(
      requestId: requestId,
      actionName: 'router.popToRoot',
      message: didPop
          ? 'Returned to the root mini-program screen.'
          : 'Mini-program is already showing the root screen.',
      data: <String, dynamic>{
        'screenId': rootScreen.screenId,
        'result': routeResult,
      },
    );
  }

  Future<HostActionResult> _mpRouterPopToScreen(
    String screenId,
    Map<String, dynamic> result,
    String? requestId,
  ) async {
    final targetIndex = _screenStack.lastIndexWhere(
      (screen) => screen.screenId == screenId,
    );
    if (targetIndex < 0) {
      return HostActionResult.failed(
        requestId: requestId,
        actionName: 'router.popToScreen',
        message:
            'Screen "$screenId" is not present in the current mini-program stack.',
        errorCode: MiniProgramErrorCodes.screenNotInStack,
        data: <String, dynamic>{'screenId': screenId},
      );
    }
    final routeResult = _normalizeRouteMap(result);
    final didPop = targetIndex < _screenStack.length - 1;
    _updateState(() {
      final updatedStack = List<_RenderedMiniProgramScreen>.from(
        _screenStack.take(targetIndex + 1),
      );
      updatedStack[updatedStack.length - 1] = updatedStack.last.withRouteResult(
        routeResult,
      );
      _screenStack = updatedStack;
    });
    return HostActionResult.success(
      requestId: requestId,
      actionName: 'router.popToScreen',
      message: didPop
          ? 'Returned to mini-program screen "$screenId".'
          : 'Mini-program is already showing screen "$screenId".',
      data: <String, dynamic>{'screenId': screenId, 'result': routeResult},
    );
  }

  HostActionResult _routerResult({
    required String? requestId,
    required String actionName,
    required _RenderedMiniProgramScreen screen,
  }) {
    return screen.failure == null
        ? HostActionResult.success(
            requestId: requestId,
            actionName: actionName,
            message: 'Opened mini-program screen "${screen.screenId}".',
            data: <String, dynamic>{
              'screenId': screen.screenId,
              'params': screen.routeParams,
            },
          )
        : HostActionResult.failed(
            requestId: requestId,
            actionName: actionName,
            message: screen.failure!.message,
            errorCode: screen.failure!.errorCode,
            data: <String, dynamic>{
              'screenId': screen.screenId,
              ...screen.failure!.details,
            },
          );
  }

  Map<String, dynamic> _normalizeRouteMap(Map<String, dynamic> value) {
    return Map<String, dynamic>.from(value);
  }

  Future<_RenderedMiniProgramScreen> _loadNavigationScreen({
    required MiniProgramManifest manifest,
    required String screenId,
    Map<String, dynamic> routeParams = const <String, dynamic>{},
  }) async {
    try {
      final loadedScreen = await _manifestLoader.loadScreen(
        miniProgramId: manifest.id,
        manifest: manifest,
        screenId: screenId,
        source: widget.source,
        screenCache: widget.screenCache ?? InMemoryScreenCache.shared,
        logger: widget.logger,
      );
      final resolvedAssets = await _assetResolver.resolveScreenAssets(
        manifest: manifest,
        screenId: screenId,
        screenJson: loadedScreen.screenJson,
        assetCache: widget.assetCache ?? NoOpAssetCache.shared,
        logger: widget.logger,
      );

      return _RenderedMiniProgramScreen.content(
        screenId: screenId,
        screenJson: resolvedAssets.screenJson,
        routeParams: routeParams,
        usedStaleCache: loadedScreen.usedStaleCache,
        cachedAssetCount: resolvedAssets.cachedAssetCount,
        downloadedAssetCount: resolvedAssets.downloadedAssetCount,
        failedAssetCount: resolvedAssets.failedAssetCount,
      );
    } catch (error, stackTrace) {
      final failure = _toFailure(
        error,
        stackTrace,
        manifest: manifest,
        screenId: screenId,
      );

      return _RenderedMiniProgramScreen.failure(
        screenId: screenId,
        failure: failure,
        routeParams: routeParams,
      );
    }
  }
}
