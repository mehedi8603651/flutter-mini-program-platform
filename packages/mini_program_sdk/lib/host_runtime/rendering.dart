part of '../mini_program_host.dart';

extension _MiniProgramHostRendering on _MiniProgramHostState {
  Future<bool> _handleWillPop() async {
    if (_screenStack.length <= 1) {
      return true;
    }

    await _popMiniProgramScreen(
      const PopMiniProgramScreenActionPayload(),
      null,
    );
    return false;
  }

  Widget _buildHost(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ?? const SdkLoadingView();
        }

        if (snapshot.hasError) {
          final failure = _toFailure(snapshot.error, snapshot.stackTrace);
          return _buildError(context, failure);
        }

        final manifest = _manifest;
        if (manifest == null || _screenStack.isEmpty) {
          return widget.loadingBuilder?.call(context) ?? const SdkLoadingView();
        }

        final currentScreen = _screenStack.last;
        final router = MpRouter(
          push: _mpRouterPush,
          replace: _mpRouterReplace,
          reset: _mpRouterReset,
          pop: _mpRouterPop,
          popToRoot: _mpRouterPopToRoot,
          popToScreen: _mpRouterPopToScreen,
        );
        return MiniProgramSdkScope(
          miniProgramId: manifest.id,
          hostBridge: widget.hostBridge,
          capabilityRegistry: widget.capabilityRegistry,
          backendConnector: _activeBackendConnector,
          locationProvider: widget.locationProvider,
          locationPolicy: _locationPolicyFor(manifest.id),
          authController: widget.authController,
          cacheManager: _cacheManager,
          cachePolicy: _activeCachePolicy ?? _cachePolicyFor(manifest.id),
          miniProgramVersion: manifest.version,
          dataResourceManager: _dataResourceManager,
          jsonAssetSource: widget.source is MiniProgramJsonAssetSource
              ? widget.source as MiniProgramJsonAssetSource
              : null,
          backendStore: _backendStore,
          stateManager: _stateManager,
          router: router,
          routeParams: currentScreen.routeParams,
          featureFlagEvaluator: widget.featureFlagEvaluator,
          logger: widget.logger,
          openMiniProgramScreen: _openMiniProgramScreen,
          resetMiniProgramStack: _resetMiniProgramStack,
          replaceMiniProgramScreen: _replaceMiniProgramScreen,
          popMiniProgramScreen: _popMiniProgramScreen,
          popToMiniProgramRoot: _popToMiniProgramRoot,
          popToMiniProgramScreen: _popToMiniProgramScreen,
          child: PopScope<void>(
            canPop: _screenStack.length <= 1,
            onPopInvokedWithResult: (didPop, _) async {
              if (!didPop) {
                await _handleWillPop();
              }
            },
            child: Builder(
              builder: (context) {
                if (currentScreen.failure != null) {
                  return _buildError(context, currentScreen.failure!);
                }

                late final Widget rendered;
                try {
                  rendered = KeyedSubtree(
                    key: ObjectKey(currentScreen.navigationIdentity),
                    child: _rendererRegistry
                        .resolve(manifest)
                        .render(
                          MiniProgramRenderRequest(
                            context: context,
                            manifest: manifest,
                            screenId: currentScreen.screenId,
                            screenJson: currentScreen.screenJson!,
                            logger: widget.logger,
                          ),
                        ),
                  );
                } catch (error, stackTrace) {
                  return _buildError(
                    context,
                    _toFailure(
                      error,
                      stackTrace,
                      manifest: manifest,
                      screenId: currentScreen.screenId,
                    ),
                  );
                }

                if (!_usedStaleManifestCache && !currentScreen.usedStaleCache) {
                  return rendered;
                }

                return Stack(
                  children: [
                    Positioned.fill(child: rendered),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: SdkOfflineNotice(
                          cachedAssetCount: currentScreen.resolvedAssetCount,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
