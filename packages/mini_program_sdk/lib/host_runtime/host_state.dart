part of '../mini_program_host.dart';

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
        widget.locationProvider != oldWidget.locationProvider ||
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

  void _updateState(VoidCallback updates) {
    setState(updates);
  }

  @override
  Widget build(BuildContext context) => _buildHost(context);
}
