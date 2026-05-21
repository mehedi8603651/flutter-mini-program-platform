import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:stac/stac.dart';

import 'cache/asset_cache.dart';
import 'cache/manifest_cache.dart';
import 'cache/screen_cache.dart';
import 'capability_registry.dart';
import 'feature_flag_evaluator.dart';
import 'host_bridge.dart';
import 'manifest_loader.dart';
import 'mini_program_failure.dart';
import 'network/asset_resolver.dart';
import 'network/mini_program_backend_connector.dart';
import 'network/mini_program_backend_store.dart';
import 'network/mini_program_source.dart';
import 'network/mini_program_source_exception.dart';
import 'observability/sdk_logger.dart';
import 'rendering/stac_initializer.dart';
import 'sdk_context.dart';
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
    this.assetCache,
    this.manifestCache,
    this.screenCache,
    this.featureFlagEvaluator = const AllowAllFeatureFlagEvaluator(),
    this.logger = const DebugPrintSdkLogger(),
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String miniProgramId;
  final String sdkVersion;
  final MiniProgramSource source;
  final HostBridge hostBridge;
  final CapabilityRegistry capabilityRegistry;
  final MiniProgramBackendConnector? backendConnector;
  final AssetCache? assetCache;
  final ManifestCache? manifestCache;
  final ScreenCache? screenCache;
  final FeatureFlagEvaluator featureFlagEvaluator;
  final SdkLogger logger;
  final WidgetBuilder? loadingBuilder;
  final MiniProgramErrorBuilder? errorBuilder;

  @override
  State<MiniProgramHost> createState() => _MiniProgramHostState();
}

class _MiniProgramHostState extends State<MiniProgramHost> {
  final ManifestLoader _manifestLoader = const ManifestLoader();
  final AssetResolver _assetResolver = AssetResolver();
  final MiniProgramBackendStore _backendStore = MiniProgramBackendStore();

  late Future<void> _loadFuture;
  int _loadGeneration = 0;
  MiniProgramManifest? _manifest;
  bool _usedStaleManifestCache = false;
  List<_RenderedMiniProgramScreen> _screenStack =
      const <_RenderedMiniProgramScreen>[];

  @override
  void initState() {
    super.initState();
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
        widget.assetCache != oldWidget.assetCache ||
        widget.manifestCache != oldWidget.manifestCache ||
        widget.screenCache != oldWidget.screenCache ||
        widget.featureFlagEvaluator != oldWidget.featureFlagEvaluator ||
        widget.logger != oldWidget.logger) {
      _restartLoad();
    }
  }

  void _restartLoad() {
    _loadGeneration++;
    _manifest = null;
    _usedStaleManifestCache = false;
    _screenStack = const <_RenderedMiniProgramScreen>[];
    _backendStore.clear();
    _loadFuture = _loadMiniProgram(_loadGeneration);
  }

  @override
  void dispose() {
    _backendStore.dispose();
    super.dispose();
  }

  Future<void> _loadMiniProgram(int generation) async {
    await StacInitializer.ensureInitialized(logger: widget.logger);

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

    setState(() {
      _manifest = loadedMiniProgram.manifest;
      _usedStaleManifestCache = loadedMiniProgram.usedStaleManifestCache;
      _screenStack = <_RenderedMiniProgramScreen>[initialScreen];
    });
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

  Future<_RenderedMiniProgramScreen> _loadNavigationScreen({
    required MiniProgramManifest manifest,
    required String screenId,
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
        return MiniProgramSdkScope(
          miniProgramId: manifest.id,
          hostBridge: widget.hostBridge,
          capabilityRegistry: widget.capabilityRegistry,
          backendConnector: widget.backendConnector,
          backendStore: _backendStore,
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

                final rendered = Stac.fromJson(
                  currentScreen.screenJson!,
                  context,
                );
                if (rendered == null) {
                  final failure = MiniProgramFailure(
                    errorCode: MiniProgramErrorCodes.manifestParseFailure,
                    message:
                        'Failed to render screen "${currentScreen.screenId}" for mini-program "${manifest.id}".',
                    fallback: manifest.fallback,
                    details: <String, dynamic>{
                      'miniProgramId': manifest.id,
                      'screenId': currentScreen.screenId,
                    },
                  );

                  widget.logger.warn(
                    'Stac returned null while rendering a mini-program screen.',
                    context: <String, Object?>{
                      'miniProgramId': manifest.id,
                      'screenId': currentScreen.screenId,
                    },
                  );
                  return _buildError(context, failure);
                }

                if (!_usedStaleManifestCache && !currentScreen.usedStaleCache) {
                  return rendered;
                }

                return Stack(
                  children: [
                    Positioned.fill(child: rendered),
                    IgnorePointer(
                      child: SdkOfflineNotice(
                        cachedAssetCount: currentScreen.resolvedAssetCount,
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
  const _RenderedMiniProgramScreen.content({
    required this.screenId,
    required this.screenJson,
    this.usedStaleCache = false,
    this.cachedAssetCount = 0,
    this.downloadedAssetCount = 0,
    this.failedAssetCount = 0,
  }) : failure = null;

  const _RenderedMiniProgramScreen.failure({
    required this.screenId,
    required this.failure,
  }) : screenJson = null,
       usedStaleCache = false,
       cachedAssetCount = 0,
       downloadedAssetCount = 0,
       failedAssetCount = 0;

  final String screenId;
  final Map<String, dynamic>? screenJson;
  final MiniProgramFailure? failure;
  final bool usedStaleCache;
  final int cachedAssetCount;
  final int downloadedAssetCount;
  final int failedAssetCount;

  int get resolvedAssetCount => cachedAssetCount + downloadedAssetCount;
}
