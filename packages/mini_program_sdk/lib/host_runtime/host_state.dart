part of '../mini_program_host.dart';

class _MiniProgramHostState extends State<MiniProgramHost> {
  final ManifestLoader _manifestLoader = const ManifestLoader();
  final AssetResolver _assetResolver = AssetResolver();
  final MiniProgramBackendStore _backendStore = MiniProgramBackendStore();
  final MpStateManager _stateManager = MpStateManager();
  final MiniProgramDataResourceManager _dataResourceManager =
      MiniProgramDataResourceManager();
  MiniProgramFileTransferManager? _fileTransferManager;
  MiniProgramMediaManager? _mediaManager;
  MiniProgramCameraManager? _cameraManager;
  MiniProgramFlashlightManager? _flashlightManager;
  MiniProgramQrManager? _qrManager;

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
    _fileTransferManager = _managerFor(widget.fileTransferProvider);
    _mediaManager = _mediaManagerFor(widget.mediaProvider);
    _cameraManager = _cameraManagerFor(widget.cameraProvider, _mediaManager);
    _flashlightManager = _flashlightManagerFor(widget.flashlightProvider);
    _qrManager = _qrManagerFor(widget.qrScannerProvider);
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
        widget.locationProvider != oldWidget.locationProvider ||
        widget.fileTransferProvider != oldWidget.fileTransferProvider ||
        widget.cameraProvider != oldWidget.cameraProvider ||
        widget.mediaProvider != oldWidget.mediaProvider ||
        widget.flashlightProvider != oldWidget.flashlightProvider ||
        widget.qrScannerProvider != oldWidget.qrScannerProvider ||
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
      if (widget.fileTransferProvider != oldWidget.fileTransferProvider) {
        unawaited(_fileTransferManager?.dispose());
        _fileTransferManager = _managerFor(widget.fileTransferProvider);
      }
      if (widget.cameraProvider != oldWidget.cameraProvider ||
          widget.mediaProvider != oldWidget.mediaProvider) {
        unawaited(_cameraManager?.dispose());
        if (widget.mediaProvider != oldWidget.mediaProvider) {
          unawaited(_mediaManager?.dispose());
          _mediaManager = _mediaManagerFor(widget.mediaProvider);
        }
        _cameraManager = _cameraManagerFor(
          widget.cameraProvider,
          _mediaManager,
        );
      }
      if (widget.flashlightProvider != oldWidget.flashlightProvider) {
        unawaited(_flashlightManager?.dispose());
        _flashlightManager = _flashlightManagerFor(widget.flashlightProvider);
      }
      if (widget.qrScannerProvider != oldWidget.qrScannerProvider) {
        unawaited(_qrManager?.dispose());
        _qrManager = _qrManagerFor(widget.qrScannerProvider);
      }
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
    final activeAppId = _manifest?.id;
    if (activeAppId != null) {
      unawaited(_fileTransferManager?.cancelAllFor(activeAppId));
      unawaited(_cameraManager?.releaseAllFor(activeAppId));
      unawaited(_mediaManager?.releaseAllFor(activeAppId));
      unawaited(_flashlightManager?.releaseFor(activeAppId));
      unawaited(_qrManager?.releaseFor(activeAppId));
    }
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
    unawaited(_fileTransferManager?.dispose());
    unawaited(_cameraManager?.dispose());
    unawaited(_mediaManager?.dispose());
    unawaited(_flashlightManager?.dispose());
    unawaited(_qrManager?.dispose());
    super.dispose();
  }

  void _updateState(VoidCallback updates) {
    setState(updates);
  }

  @override
  Widget build(BuildContext context) => _buildHost(context);

  MiniProgramFileTransferManager? _managerFor(
    MiniProgramFileTransferProvider? provider,
  ) => provider == null ? null : MiniProgramFileTransferManager(provider);

  MiniProgramCameraManager? _cameraManagerFor(
    MiniProgramCameraProvider? provider,
    MiniProgramMediaManager? mediaManager,
  ) => provider == null
      ? null
      : MiniProgramCameraManager(provider, mediaManager: mediaManager);

  MiniProgramMediaManager? _mediaManagerFor(
    MiniProgramMediaProvider? provider,
  ) => provider == null ? null : MiniProgramMediaManager(provider);

  MiniProgramFlashlightManager? _flashlightManagerFor(
    MiniProgramFlashlightProvider? provider,
  ) => provider == null ? null : MiniProgramFlashlightManager(provider);

  MiniProgramQrManager? _qrManagerFor(MiniProgramQrScannerProvider? provider) =>
      provider == null ? null : MiniProgramQrManager(provider);
}
