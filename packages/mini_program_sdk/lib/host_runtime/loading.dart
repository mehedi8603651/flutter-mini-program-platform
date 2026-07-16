part of '../mini_program_host.dart';

extension _MiniProgramHostLoading on _MiniProgramHostState {
  Future<void> _loadMiniProgram(int generation) async {
    final loadedMiniProgram = await _manifestLoader.load(
      miniProgramId: widget.miniProgramId,
      sdkVersion: widget.sdkVersion,
      source: widget.source,
      manifestCache: widget.manifestCache ?? InMemoryManifestCache.shared,
      screenCache: widget.screenCache ?? InMemoryScreenCache.shared,
      capabilityRegistry: widget.capabilityRegistry,
      featureFlagEvaluator: widget.featureFlagEvaluator,
      logger: widget.logger,
    );
    final renderer = _rendererRegistry.resolve(loadedMiniProgram.manifest);
    await renderer.ensureInitialized(logger: widget.logger);

    final initialScreen = _RenderedMiniProgramScreen.content(
      screenId: loadedMiniProgram.manifest.entry,
      screenJson: loadedMiniProgram.entryScreenJson,
      usedStaleCache: loadedMiniProgram.usedStaleEntryScreenCache,
      cachedAssetCount: loadedMiniProgram.cachedAssetCount,
      downloadedAssetCount: loadedMiniProgram.downloadedAssetCount,
      failedAssetCount: loadedMiniProgram.failedAssetCount,
    );

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    final cachePolicy = _cachePolicyFor(loadedMiniProgram.manifest.id);
    final liveStatePolicy = _liveStatePolicyFor(loadedMiniProgram.manifest.id);
    final backendConnector = _backendConnectorFor(loadedMiniProgram);
    _stateManager.updatePolicy(liveStatePolicy);
    await _cacheManager.openApp(
      loadedMiniProgram.manifest.id,
      policy: cachePolicy,
    );

    if (!mounted || generation != _loadGeneration) {
      await _cacheManager.closeApp(
        loadedMiniProgram.manifest.id,
        policy: cachePolicy,
      );
      if (backendConnector is DisposableMiniProgramBackendConnector &&
          !identical(backendConnector, widget.backendConnector)) {
        backendConnector.dispose();
      }
      return;
    }

    _setActiveBackendConnector(backendConnector);

    await widget.authController?.restore(
      miniProgramId: loadedMiniProgram.manifest.id,
      connector: _activeBackendConnector,
    );

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    _updateState(() {
      _manifest = loadedMiniProgram.manifest;
      _activeCacheAppId = loadedMiniProgram.manifest.id;
      _activeCachePolicy = cachePolicy;
      _usedStaleManifestCache = loadedMiniProgram.usedStaleManifestCache;
      _screenStack = <_RenderedMiniProgramScreen>[initialScreen];
    });
  }
}
