import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart'
    hide MiniProgramCachePolicy;

import 'cache/asset_cache.dart';
import 'cache/manifest_cache.dart';
import 'cache/runtime_cache.dart';
import 'cache/screen_cache.dart';
import 'auth/mini_program_auth.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'data/mini_program_data_resource.dart';
import 'host_bridge.dart';
import 'manifest_loader.dart';
import 'mini_program_failure.dart';
import 'network/asset_resolver.dart';
import 'network/mini_program_backend_connector.dart';
import 'network/mini_program_backend_store.dart';
import 'network/mini_program_source.dart';
import 'network/mini_program_source_exception.dart';
import 'observability/sdk_logger.dart';
import 'rendering/mini_program_screen_renderer.dart';
import 'sdk_context.dart';
import 'state/mp_state.dart';
import 'widgets/sdk_error_view.dart';
import 'widgets/sdk_loading_view.dart';
import 'widgets/sdk_offline_notice.dart';

typedef MiniProgramErrorBuilder =
    Widget Function(BuildContext context, MiniProgramFailure failure);

/// Entry widget for loading, validating, and rendering a portable mini-program.
class MiniProgramHost extends StatefulWidget {
  const MiniProgramHost({
    super.key,
    required this.miniProgramId,
    required this.sdkVersion,
    required this.source,
    required this.hostBridge,
    required this.capabilityRegistry,
    this.backendConnector,
    this.authController,
    this.assetCache,
    this.manifestCache,
    this.screenCache,
    this.cacheManager,
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
    this.logger = const DebugPrintSdkLogger(),
    this.renderers = const <MiniProgramScreenRenderer>[],
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String miniProgramId;
  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final MiniProgramBackendConnector? backendConnector;
  final MiniProgramAuthController? authController;
  final AssetCache? assetCache;
  final ManifestCache? manifestCache;
  final ScreenCache? screenCache;
  final MiniProgramCacheManager? cacheManager;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final SdkLogger logger;
  final List<MiniProgramScreenRenderer> renderers;
  final WidgetBuilder? loadingBuilder;
  final MiniProgramErrorBuilder? errorBuilder;

  @override
  State<MiniProgramHost> createState() => _MiniProgramHostState();
}

class _MiniProgramHostState extends State<MiniProgramHost> {
  final ManifestLoader _manifestLoader = const ManifestLoader();
  final AssetResolver _assetResolver = AssetResolver();
  final MiniProgramBackendStore _backendStore = MiniProgramBackendStore();
  final MpStateManager _stateManager = MpStateManager();
  final MiniProgramDataResourceManager _dataResourceManager =
      MiniProgramDataResourceManager();

  late MiniProgramScreenRendererRegistry _rendererRegistry;
  late MiniProgramCacheManager _cacheManager;
  late Future<void> _loadFuture;
  int _loadGeneration = 0;
  MiniProgramManifest? _manifest;
  String? _activeCacheAppId;
  MiniProgramCachePolicy? _activeCachePolicy;
  MiniProgramBackendConnector? _activeBackendConnector;
  DisposableMiniProgramBackendConnector? _ownedBackendConnector;
  bool _usedStaleManifestCache = false;
  List<_RenderedMiniProgramScreen> _screenStack =
      const <_RenderedMiniProgramScreen>[];

  @override
  void initState() {
    super.initState();
    _cacheManager = widget.cacheManager ?? MiniProgramCacheManager.inMemory();
    _rebuildRendererRegistry();
    _restartLoad();
  }

  @override
  void didUpdateWidget(covariant MiniProgramHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.miniProgramId != oldWidget.miniProgramId ||
        widget.sdkVersion != oldWidget.sdkVersion ||
        widget.source != oldWidget.source ||
        widget.hostBridge != oldWidget.hostBridge ||
        widget.capabilityRegistry != oldWidget.capabilityRegistry ||
        widget.backendConnector != oldWidget.backendConnector ||
        widget.authController != oldWidget.authController ||
        widget.assetCache != oldWidget.assetCache ||
        widget.manifestCache != oldWidget.manifestCache ||
        widget.screenCache != oldWidget.screenCache ||
        widget.cacheManager != oldWidget.cacheManager ||
        widget.featureFlagEvaluator != oldWidget.featureFlagEvaluator ||
        widget.logger != oldWidget.logger ||
        !listEquals(widget.renderers, oldWidget.renderers)) {
      if (widget.cacheManager != oldWidget.cacheManager) {
        _closeActiveCacheApp();
      }
      _cacheManager = widget.cacheManager ?? MiniProgramCacheManager.inMemory();
      _rebuildRendererRegistry();
      _restartLoad();
    }
  }

  void _rebuildRendererRegistry() {
    _rendererRegistry = MiniProgramScreenRendererRegistry.withDefaults(
      widget.renderers,
    );
  }

  void _restartLoad() {
    _closeActiveCacheApp();
    _disposeOwnedBackendConnector();
    _loadGeneration++;
    _manifest = null;
    _activeCacheAppId = null;
    _activeCachePolicy = null;
    _usedStaleManifestCache = false;
    _screenStack = const <_RenderedMiniProgramScreen>[];
    _backendStore.clear();
    _stateManager.clear();
    _dataResourceManager.clear();
    _loadFuture = _loadMiniProgram(_loadGeneration);
  }

  @override
  void dispose() {
    _closeActiveCacheApp();
    _disposeOwnedBackendConnector();
    _backendStore.dispose();
    _stateManager.dispose();
    super.dispose();
  }

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

    setState(() {
      _manifest = loadedMiniProgram.manifest;
      _activeCacheAppId = loadedMiniProgram.manifest.id;
      _activeCachePolicy = cachePolicy;
      _usedStaleManifestCache = loadedMiniProgram.usedStaleManifestCache;
      _screenStack = <_RenderedMiniProgramScreen>[initialScreen];
    });
  }

  MiniProgramCachePolicy _cachePolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramCachePolicyProvider) {
      return (source as MiniProgramCachePolicyProvider).cachePolicyFor(appId);
    }
    return _cacheManager.defaultPolicy;
  }

  MiniProgramLiveStatePolicy _liveStatePolicyFor(String appId) {
    final source = widget.source;
    if (source is MiniProgramLiveStatePolicyProvider) {
      return (source as MiniProgramLiveStatePolicyProvider).liveStatePolicyFor(
        appId,
      );
    }
    return const MiniProgramLiveStatePolicy();
  }

  MiniProgramBackendConnector? _backendConnectorFor(
    LoadedMiniProgram loadedMiniProgram,
  ) {
    final contract = loadedMiniProgram.publisherBackendContract;
    if (contract == null) {
      return widget.backendConnector;
    }
    final source = widget.source;
    final policy = source is MiniProgramPublisherApiPolicyProvider
        ? (source as MiniProgramPublisherApiPolicyProvider)
              .publisherApiPolicyFor(contract.appId)
        : const MiniProgramPublisherApiPolicy();
    if (!policy.enabled) {
      return const DisabledMiniProgramBackendConnector();
    }
    final deliveryContext = source is MiniProgramDeliveryContextProvider
        ? (source as MiniProgramDeliveryContextProvider).deliveryContext
        : null;
    if (deliveryContext == null) {
      widget.logger.warn(
        'Publisher API was accepted, but the mini-program source does not '
        'provide delivery context for request headers.',
        context: <String, Object?>{'miniProgramId': contract.appId},
      );
      return null;
    }
    return EndpointRoutingMiniProgramBackendConnector(
      backends: <String, MiniProgramBackendEndpoint>{
        contract.appId: MiniProgramBackendEndpoint(
          baseUri: contract.backendBaseUri,
        ),
      },
      deliveryContext: deliveryContext,
    );
  }

  void _setActiveBackendConnector(MiniProgramBackendConnector? connector) {
    _disposeOwnedBackendConnector();
    _activeBackendConnector = connector;
    if (connector is DisposableMiniProgramBackendConnector &&
        !identical(connector, widget.backendConnector)) {
      _ownedBackendConnector = connector;
    }
  }

  void _disposeOwnedBackendConnector() {
    _ownedBackendConnector?.dispose();
    _ownedBackendConnector = null;
    _activeBackendConnector = null;
  }

  void _closeActiveCacheApp() {
    final appId = _activeCacheAppId;
    if (appId == null) {
      return;
    }
    unawaited(_cacheManager.closeApp(appId, policy: _activeCachePolicy));
    _activeCacheAppId = null;
    _activeCachePolicy = null;
  }

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

    setState(() {
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

    setState(() {
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

    setState(() {
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

    setState(() {
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
      setState(() {
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
      setState(() {
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
    setState(() {
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
    setState(() {
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
    setState(() {
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
    setState(() {
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
    setState(() {
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
    setState(() {
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

  @override
  Widget build(BuildContext context) {
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

  MiniProgramFailure _toFailure(
    Object? error,
    StackTrace? stackTrace, {
    MiniProgramManifest? manifest,
    String? screenId,
  }) {
    if (error is MiniProgramLoadException) {
      return error.failure;
    }

    if (error is MiniProgramSourceException) {
      return MiniProgramFailure(
        errorCode: error.errorCode,
        message: error.message,
        fallback: manifest?.fallback,
        cause: error,
        stackTrace: stackTrace,
        details: <String, dynamic>{
          'miniProgramId': manifest?.id ?? widget.miniProgramId,
          if (screenId != null) 'screenId': screenId,
          ...error.details,
        },
      );
    }

    if (error is MiniProgramRenderException) {
      final resolvedManifest =
          manifest ??
          MiniProgramManifest(
            id: widget.miniProgramId,
            version: 'unknown',
            entry: screenId ?? 'unknown',
            contractVersion: 'unknown',
            sdkVersionRange: const SdkVersionRange(value: '>=0.0.0'),
            requiredCapabilities: const <CapabilityId>[],
          );
      return error.toFailure(
        manifest: resolvedManifest,
        screenId: screenId ?? resolvedManifest.entry,
        stackTrace: stackTrace,
      );
    }

    widget.logger.error(
      'Unhandled mini-program host error.',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'miniProgramId': manifest?.id ?? widget.miniProgramId,
        if (screenId != null) 'screenId': screenId,
      },
    );
    return MiniProgramFailure(
      message: screenId == null
          ? 'Failed to load mini-program "${widget.miniProgramId}".'
          : 'Failed to load screen "$screenId" for mini-program "${manifest?.id ?? widget.miniProgramId}".',
      fallback: manifest?.fallback,
      cause: error,
      stackTrace: stackTrace,
      details: <String, dynamic>{
        'miniProgramId': manifest?.id ?? widget.miniProgramId,
        if (screenId != null) 'screenId': screenId,
      },
    );
  }

  Widget _buildError(BuildContext context, MiniProgramFailure failure) {
    return widget.errorBuilder?.call(context, failure) ??
        SdkErrorView(failure: failure);
  }
}

class _RenderedMiniProgramScreen {
  _RenderedMiniProgramScreen.content({
    required this.screenId,
    required this.screenJson,
    this.routeParams = const <String, dynamic>{},
    this.usedStaleCache = false,
    this.cachedAssetCount = 0,
    this.downloadedAssetCount = 0,
    this.failedAssetCount = 0,
    Object? navigationIdentity,
  }) : navigationIdentity = navigationIdentity ?? Object(),
       failure = null;

  _RenderedMiniProgramScreen.failure({
    required this.screenId,
    required this.failure,
    this.routeParams = const <String, dynamic>{},
    Object? navigationIdentity,
  }) : screenJson = null,
       navigationIdentity = navigationIdentity ?? Object(),
       usedStaleCache = false,
       cachedAssetCount = 0,
       downloadedAssetCount = 0,
       failedAssetCount = 0;

  final String screenId;
  final Map<String, dynamic>? screenJson;
  final Map<String, dynamic> routeParams;
  final Object navigationIdentity;
  final MiniProgramFailure? failure;
  final bool usedStaleCache;
  final int cachedAssetCount;
  final int downloadedAssetCount;
  final int failedAssetCount;

  int get resolvedAssetCount => cachedAssetCount + downloadedAssetCount;

  _RenderedMiniProgramScreen withRouteResult(Map<String, dynamic> result) {
    final updatedParams = <String, dynamic>{...routeParams}..remove('result');
    if (result.isNotEmpty) {
      updatedParams['result'] = result;
    }
    if (failure != null) {
      return _RenderedMiniProgramScreen.failure(
        screenId: screenId,
        failure: failure!,
        routeParams: updatedParams,
        navigationIdentity: navigationIdentity,
      );
    }
    return _RenderedMiniProgramScreen.content(
      screenId: screenId,
      screenJson: screenJson!,
      routeParams: updatedParams,
      usedStaleCache: usedStaleCache,
      cachedAssetCount: cachedAssetCount,
      downloadedAssetCount: downloadedAssetCount,
      failedAssetCount: failedAssetCount,
      navigationIdentity: navigationIdentity,
    );
  }
}
