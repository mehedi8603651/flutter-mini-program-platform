part of '../mini_program_host.dart';

class _MiniProgramHostState extends State<MiniProgramHost>
    with WidgetsBindingObserver {
  final ManifestLoader _manifestLoader = const ManifestLoader();
  final AssetResolver _assetResolver = AssetResolver();
  final MiniProgramBackendStore _backendStore = MiniProgramBackendStore();
  final MpStateManager _stateManager = MpStateManager();
  final MiniProgramDataResourceManager _dataResourceManager =
      MiniProgramDataResourceManager();
  MiniProgramFileTransferManager? _fileTransferManager;
  MiniProgramDisplayBrightnessManager? _displayBrightnessManager;
  MiniProgramMediaManager? _mediaManager;
  MiniProgramMediaPlaybackManager? _mediaPlaybackManager;
  MiniProgramCameraManager? _cameraManager;
  MiniProgramGalleryManager? _galleryManager;
  MiniProgramMicrophoneManager? _microphoneManager;
  MiniProgramFlashlightManager? _flashlightManager;
  MiniProgramQrManager? _qrManager;
  MiniProgramShareManager? _shareManager;

  late MiniProgramScreenRendererRegistry _rendererRegistry;
  late MiniProgramCacheManager _cacheManager;
  late Future<void> _loadFuture;
  late MiniProgramVisibility _surfaceVisibility;
  Future<void> _foregroundLifecycleTail = Future<void>.value();
  int _loadGeneration = 0;
  MiniProgramManifest? _manifest;
  String? _activeCacheAppId;
  MiniProgramCachePolicy? _activeCachePolicy;
  MiniProgramBackendConnector? _activeBackendConnector;
  DisposableMiniProgramBackendConnector? _ownedBackendConnector;
  bool _usedStaleManifestCache = false;
  List<_RenderedMiniProgramScreen> _screenStack =
      const <_RenderedMiniProgramScreen>[];
  bool _appIsForeground = true;
  bool _foregroundResourcesSuspended = false;
  bool _hostDisposed = false;

  @override
  void initState() {
    super.initState();
    _surfaceVisibility = widget.visibility;
    WidgetsBinding.instance.addObserver(this);
    _cacheManager = widget.cacheManager ?? MiniProgramCacheManager.inMemory();
    _fileTransferManager = _managerFor(widget.fileTransferProvider);
    _displayBrightnessManager = _displayBrightnessManagerFor(
      widget.displayBrightnessProvider,
    );
    _mediaManager = _mediaManagerFor(
      widget.mediaProvider ??
          widget.galleryProvider ??
          widget.microphoneProvider,
    );
    _galleryManager = _galleryManagerFor(widget.galleryProvider, _mediaManager);
    _microphoneManager = _microphoneManagerFor(
      widget.microphoneProvider,
      _mediaManager,
    );
    _mediaPlaybackManager = _mediaPlaybackManagerFor(
      widget.mediaPlaybackProvider,
    );
    _cameraManager = _cameraManagerFor(widget.cameraProvider, _mediaManager);
    _flashlightManager = _flashlightManagerFor(widget.flashlightProvider);
    _qrManager = _qrManagerFor(widget.qrScannerProvider);
    _shareManager = _shareManagerFor(widget.shareProvider);
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
        widget.displayBrightnessProvider !=
            oldWidget.displayBrightnessProvider ||
        widget.cameraProvider != oldWidget.cameraProvider ||
        widget.galleryProvider != oldWidget.galleryProvider ||
        widget.microphoneProvider != oldWidget.microphoneProvider ||
        widget.mediaProvider != oldWidget.mediaProvider ||
        widget.mediaPlaybackProvider != oldWidget.mediaPlaybackProvider ||
        widget.flashlightProvider != oldWidget.flashlightProvider ||
        widget.qrScannerProvider != oldWidget.qrScannerProvider ||
        widget.clipboardProvider != oldWidget.clipboardProvider ||
        widget.vibrationProvider != oldWidget.vibrationProvider ||
        widget.phoneProvider != oldWidget.phoneProvider ||
        widget.shareProvider != oldWidget.shareProvider ||
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
      if (widget.displayBrightnessProvider !=
          oldWidget.displayBrightnessProvider) {
        unawaited(_displayBrightnessManager?.dispose());
        _displayBrightnessManager = _displayBrightnessManagerFor(
          widget.displayBrightnessProvider,
        );
      }
      if (widget.cameraProvider != oldWidget.cameraProvider ||
          widget.galleryProvider != oldWidget.galleryProvider ||
          widget.microphoneProvider != oldWidget.microphoneProvider ||
          widget.mediaProvider != oldWidget.mediaProvider) {
        unawaited(_cameraManager?.dispose());
        unawaited(_galleryManager?.dispose());
        unawaited(_microphoneManager?.dispose());
        if (widget.mediaProvider != oldWidget.mediaProvider ||
            widget.galleryProvider != oldWidget.galleryProvider ||
            widget.microphoneProvider != oldWidget.microphoneProvider) {
          unawaited(_mediaManager?.dispose());
          _mediaManager = _mediaManagerFor(
            widget.mediaProvider ??
                widget.galleryProvider ??
                widget.microphoneProvider,
          );
        }
        _galleryManager = _galleryManagerFor(
          widget.galleryProvider,
          _mediaManager,
        );
        _microphoneManager = _microphoneManagerFor(
          widget.microphoneProvider,
          _mediaManager,
        );
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
      if (widget.shareProvider != oldWidget.shareProvider) {
        _shareManager?.dispose();
        _shareManager = _shareManagerFor(widget.shareProvider);
      }
      if (widget.mediaPlaybackProvider != oldWidget.mediaPlaybackProvider) {
        unawaited(_mediaPlaybackManager?.dispose());
        _mediaPlaybackManager = _mediaPlaybackManagerFor(
          widget.mediaPlaybackProvider,
        );
      }
      _rebuildRendererRegistry();
      _restartLoad();
    }

    if (widget.visibility != oldWidget.visibility) {
      _surfaceVisibility = widget.visibility;
      _scheduleForegroundLifecycle();
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
      unawaited(_displayBrightnessManager?.releaseAllFor(activeAppId));
      unawaited(_cameraManager?.releaseAllFor(activeAppId));
      unawaited(_galleryManager?.releaseAllFor(activeAppId));
      unawaited(_microphoneManager?.releaseAllFor(activeAppId));
      unawaited(_mediaManager?.releaseAllFor(activeAppId));
      unawaited(_flashlightManager?.releaseFor(activeAppId));
      unawaited(_qrManager?.releaseFor(activeAppId));
      unawaited(_mediaPlaybackManager?.releaseAllFor(activeAppId));
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
    _foregroundResourcesSuspended = false;
    _scheduleForegroundLifecycle();
  }

  @override
  void dispose() {
    _hostDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _closeActiveCacheApp();
    _disposeOwnedBackendConnector();
    _backendStore.dispose();
    _stateManager.dispose();
    unawaited(_fileTransferManager?.dispose());
    unawaited(_displayBrightnessManager?.dispose());
    unawaited(_cameraManager?.dispose());
    unawaited(_galleryManager?.dispose());
    unawaited(_microphoneManager?.dispose());
    unawaited(_mediaManager?.dispose());
    unawaited(_flashlightManager?.dispose());
    unawaited(_qrManager?.dispose());
    _shareManager?.dispose();
    unawaited(_mediaPlaybackManager?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appIsForeground = true;
      _scheduleForegroundLifecycle();
      return;
    }
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final appId = _manifest?.id;
      if (appId != null) {
        unawaited(
          _bestEffort(_microphoneManager?.stopFor(appId, background: true)),
        );
      }
    }
    _appIsForeground = false;
    _scheduleForegroundLifecycle();
  }

  bool get _shouldKeepForegroundResources {
    return _appIsForeground &&
        _surfaceVisibility == MiniProgramVisibility.foreground;
  }

  void _scheduleForegroundLifecycle() {
    _foregroundLifecycleTail = _foregroundLifecycleTail
        .then<void>((_) => _applyForegroundLifecycle())
        .catchError((Object _, StackTrace __) {
          // Foreground cleanup must not surface provider errors to the host.
        });
  }

  Future<void> _applyForegroundLifecycle() async {
    if (_hostDisposed) {
      return;
    }
    final recordingAppId = _manifest?.id;
    if (_surfaceVisibility != MiniProgramVisibility.foreground &&
        recordingAppId != null) {
      await _bestEffort(
        _microphoneManager?.stopFor(recordingAppId, background: true),
      );
    }
    if (_shouldKeepForegroundResources) {
      if (_foregroundResourcesSuspended) {
        _foregroundResourcesSuspended = false;
        await _bestEffort(_displayBrightnessManager?.resume());
      }
      return;
    }

    if (_foregroundResourcesSuspended) {
      return;
    }
    _foregroundResourcesSuspended = true;
    await _bestEffort(_displayBrightnessManager?.suspend());

    final appId = _manifest?.id;
    if (appId == null) {
      return;
    }
    await _bestEffort(_mediaPlaybackManager?.pauseAllFor(appId));
    await _bestEffort(_cameraManager?.cancelFor(appId));
    await _bestEffort(_flashlightManager?.releaseFor(appId));
    await _bestEffort(_qrManager?.releaseFor(appId));
  }

  Future<void> _bestEffort<T>(Future<T>? operation) async {
    if (operation == null) {
      return;
    }
    try {
      await operation;
    } on Object {
      // Foreground lifecycle cleanup is best effort.
    }
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

  MiniProgramGalleryManager? _galleryManagerFor(
    MiniProgramGalleryProvider? provider,
    MiniProgramMediaManager? mediaManager,
  ) => provider == null || mediaManager == null
      ? null
      : MiniProgramGalleryManager(provider, mediaManager: mediaManager);

  MiniProgramMicrophoneManager? _microphoneManagerFor(
    MiniProgramMicrophoneProvider? provider,
    MiniProgramMediaManager? mediaManager,
  ) => provider == null || mediaManager == null
      ? null
      : MiniProgramMicrophoneManager(provider, mediaManager: mediaManager);

  MiniProgramDisplayBrightnessManager? _displayBrightnessManagerFor(
    MiniProgramDisplayBrightnessProvider? provider,
  ) => provider == null ? null : MiniProgramDisplayBrightnessManager(provider);

  MiniProgramMediaManager? _mediaManagerFor(
    MiniProgramMediaProvider? provider,
  ) => provider == null ? null : MiniProgramMediaManager(provider);

  MiniProgramFlashlightManager? _flashlightManagerFor(
    MiniProgramFlashlightProvider? provider,
  ) => provider == null ? null : MiniProgramFlashlightManager(provider);

  MiniProgramQrManager? _qrManagerFor(MiniProgramQrScannerProvider? provider) =>
      provider == null ? null : MiniProgramQrManager(provider);

  MiniProgramShareManager? _shareManagerFor(
    MiniProgramShareProvider? provider,
  ) => provider == null ? null : MiniProgramShareManager(provider);

  MiniProgramMediaPlaybackManager? _mediaPlaybackManagerFor(
    MiniProgramMediaPlaybackProvider? provider,
  ) => provider == null ? null : MiniProgramMediaPlaybackManager(provider);
}
