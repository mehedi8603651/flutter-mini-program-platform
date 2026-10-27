part of '../../mp_screen_renderer.dart';

/// Owns only this rendered screen's modal routes. The screen remains mounted
/// underneath them; none of the close paths pop an arbitrary host route.
class _MpOverlayHost extends StatefulWidget {
  const _MpOverlayHost({required this.child});
  final Widget child;

  @override
  State<_MpOverlayHost> createState() => _MpOverlayHostState();
}

class _MpOverlayHostState extends State<_MpOverlayHost>
    with WidgetsBindingObserver {
  final changes = ValueNotifier<int>(0);
  final _sessions = <_MpOverlaySession>[];
  MiniProgramSdkScope? scope;
  ModalRoute<dynamic>? _ownerRoute;
  bool _notifyScheduled = false;

  bool get foreground =>
      mounted &&
      scope?.isForeground == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MiniProgramSdkScope.maybeOf(context);
    final route = ModalRoute.of(context);
    if (scope != null &&
        (scope?.miniProgramId != next?.miniProgramId ||
            !identical(scope?.stateManager, next?.stateManager) ||
            !identical(_ownerRoute, route))) {
      _cancelAll();
    }
    scope = next;
    _ownerRoute = route;
    if (next?.isForeground != true &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed)) {
      _cancelAll();
    }
    if (!_notifyScheduled) {
      _notifyScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (mounted) changes.value++;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // System pickers and external Activities pause this engine too. Keep pure
    // UI and action contexts alive; the host still suspends sensitive device
    // resources. Check explicit visibility after resumed host dependencies land.
    if (state == AppLifecycleState.detached) {
      _cancelAll();
    } else if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scope?.isForeground != true) _cancelAll();
      });
    }
  }

  Future<HostActionResult> open(
    BuildContext source,
    String kind,
    String type,
    Map<String, dynamic> props,
    _MpRenderBindings bindings,
  ) async {
    if (!foreground || ModalRoute.of(source)?.isCurrent == false) {
      return HostActionResult.failed(
        actionName: type,
        message: 'Panels require a foreground mini-program route.',
        errorCode: MiniProgramErrorCodes.overlayForegroundRequired,
      );
    }
    final navigator = Navigator.maybeOf(source);
    if (navigator == null) {
      return HostActionResult.failed(
        actionName: type,
        message: 'A Navigator is unavailable for the mini-program panel.',
        errorCode: MiniProgramErrorCodes.overlayUnavailable,
      );
    }
    if (_sessions.where((s) => !s.cancelled).length >= 8) {
      return HostActionResult.failed(
        actionName: type,
        message: 'A mini-program may open at most eight nested panels.',
        errorCode: MiniProgramErrorCodes.overlayLimitExceeded,
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final session = _MpOverlaySession(
      owner: this,
      navigator: navigator,
      kind: kind,
      props: props,
      bindings: bindings,
      form: _MpFormScope.maybeOf(source),
      themes: InheritedTheme.capture(from: source, to: navigator.context),
    );
    final side = props['side'];
    final offset = switch (side) {
      'left' => const Offset(-1, 0),
      'right' => const Offset(1, 0),
      'bottom' => const Offset(0, 1),
      'top' => const Offset(0, -1),
      _ => Offset.zero,
    };
    final interactionRoute = MiniProgramInteractionSurface.routeBuilder(source);
    session.route = RawDialogRoute<void>(
      settings: RouteSettings(name: 'mini-program/panel/$kind'),
      barrierDismissible: props['dismissible'] == true,
      barrierLabel: MaterialLocalizations.of(source).modalBarrierDismissLabel,
      barrierColor: props['barrierColor'] == null
          ? const Color(0x66000000)
          : _mpColor(
              props['barrierColor'] as String,
              fallback: const Color(0x66000000),
            ),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          interactionRoute(_MpOwnedPanel(session: session)),
      transitionBuilder: (_, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return offset == Offset.zero
            ? FadeTransition(opacity: curve, child: child)
            : SlideTransition(
                position: Tween(begin: offset, end: Offset.zero).animate(curve),
                child: child,
              );
      },
    );
    _sessions.add(session);
    final interaction = MiniProgramInteractionExecution.current;
    if (interaction != null) interaction.waitingForPanel = true;
    try {
      await navigator.push<void>(session.route);
      return session.cancelled
          ? HostActionResult.failed(
              actionName: type,
              message: 'The panel owner is no longer active.',
              errorCode: MiniProgramErrorCodes.overlayRequestCancelled,
            )
          : HostActionResult.success(actionName: type);
    } finally {
      if (interaction != null) interaction.waitingForPanel = false;
      _sessions.remove(session);
    }
  }

  HostActionResult close(String kind, String type) {
    final active = _sessions.where((s) => !s.cancelled && s.route.isActive);
    final session = active.isEmpty ? null : active.last;
    final closed =
        foreground &&
        session?.kind == kind &&
        session?.route.isCurrent == true &&
        session!.navigator.mounted;
    if (closed) session.navigator.pop();
    return HostActionResult.success(actionName: type, data: {'closed': closed});
  }

  void _cancelAll() {
    for (final session in _sessions.reversed.toList()) {
      session.cancelled = true;
      // Dependency changes and disposal can occur while Navigator is locked.
      // Remove the exact owned route even if another host route covers it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (session.navigator.mounted && session.route.isActive) {
          session.navigator.removeRoute(session.route);
        }
      });
    }
    if (_sessions.isNotEmpty) WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _cancelAll();
    scope = null;
    WidgetsBinding.instance.removeObserver(this);
    changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _MpOverlayScope(owner: this, child: widget.child);
}

class _MpOverlayScope extends InheritedWidget {
  const _MpOverlayScope({required this.owner, required super.child});
  final _MpOverlayHostState owner;

  static _MpOverlayHostState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MpOverlayScope>()?.owner;

  @override
  bool updateShouldNotify(_MpOverlayScope oldWidget) =>
      owner != oldWidget.owner;
}

class _MpOverlaySession {
  _MpOverlaySession({
    required this.owner,
    required this.navigator,
    required this.kind,
    required this.props,
    required this.bindings,
    required this.themes,
    this.form,
  });
  final _MpOverlayHostState owner;
  final NavigatorState navigator;
  final String kind;
  final Map<String, dynamic> props;
  final _MpRenderBindings bindings;
  final CapturedThemes themes;
  final _MpFormController? form;
  late final RawDialogRoute<void> route;
  bool cancelled = false;

  bool get current => !cancelled && owner.foreground && route.isCurrent;
  void close() {
    if (!cancelled && owner.mounted && route.isCurrent && navigator.mounted) {
      navigator.pop();
    }
  }
}

class _MpOwnedPanel extends StatelessWidget {
  const _MpOwnedPanel({required this.session});
  final _MpOverlaySession session;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      session.owner.changes,
      if (session.form != null && !session.form!._disposed) session.form!,
    ]),
    builder: (context, _) {
      final scope = session.owner.scope;
      if (scope == null || session.cancelled) return const SizedBox.shrink();
      final form = session.form;
      return _mpPanelSdkScope(
        scope,
        child: _MpOverlayScope(
          owner: session.owner,
          child: session.themes.wrap(
            form == null || form._disposed
                ? _MpPanelSurface(session: session)
                : _MpFormScope(
                    controller: form,
                    child: _MpPanelSurface(session: session),
                  ),
          ),
        ),
      );
    },
  );
}

// Navigator routes are siblings of the calling subtree. Forward its current
// trusted services and accepted policies, never build a default/empty SDK scope.
MiniProgramSdkScope _mpPanelSdkScope(
  MiniProgramSdkScope s, {
  required Widget child,
}) => MiniProgramSdkScope(
  miniProgramId: s.miniProgramId,
  hostBridge: s.hostBridge,
  capabilityRegistry: s.capabilityRegistry,
  backendConnector: s.backendConnector,
  locationProvider: s.locationProvider,
  locationPolicy: s.locationPolicy,
  fileTransferManager: s.fileTransferManager,
  filePolicy: s.filePolicy,
  displayBrightnessManager: s.displayBrightnessManager,
  displayBrightnessPolicy: s.displayBrightnessPolicy,
  cameraManager: s.cameraManager,
  cameraPolicy: s.cameraPolicy,
  galleryManager: s.galleryManager,
  galleryPolicy: s.galleryPolicy,
  microphoneManager: s.microphoneManager,
  microphonePolicy: s.microphonePolicy,
  mediaManager: s.mediaManager,
  mediaPlaybackManager: s.mediaPlaybackManager,
  mediaPlaybackPolicy: s.mediaPlaybackPolicy,
  mediaAssetSource: s.mediaAssetSource,
  flashlightManager: s.flashlightManager,
  flashlightPolicy: s.flashlightPolicy,
  qrManager: s.qrManager,
  qrPolicy: s.qrPolicy,
  clipboardProvider: s.clipboardProvider,
  clipboardPolicy: s.clipboardPolicy,
  vibrationProvider: s.vibrationProvider,
  vibrationPolicy: s.vibrationPolicy,
  phoneProvider: s.phoneProvider,
  phonePolicy: s.phonePolicy,
  mapsProvider: s.mapsProvider,
  bluetoothManager: s.bluetoothManager,
  nfcManager: s.nfcManager,
  bluetoothPolicy: s.bluetoothPolicy,
  nfcPolicy: s.nfcPolicy,
  mapsPolicy: s.mapsPolicy,
  isForeground: s.isForeground,
  shareManager: s.shareManager,
  sharePolicy: s.sharePolicy,
  authController: s.authController,
  cacheManager: s.cacheManager,
  cachePolicy: s.cachePolicy,
  miniProgramVersion: s.miniProgramVersion,
  dataResourceManager: s.dataResourceManager,
  jsonAssetSource: s.jsonAssetSource,
  backendStore: s.backendStore,
  stateManager: s.stateManager,
  router: s.router,
  routeParams: s.routeParams,
  featureFlagEvaluator: s.featureFlagEvaluator,
  logger: s.logger,
  openMiniProgramScreen: s.openMiniProgramScreen,
  resetMiniProgramStack: s.resetMiniProgramStack,
  replaceMiniProgramScreen: s.replaceMiniProgramScreen,
  popMiniProgramScreen: s.popMiniProgramScreen,
  popToMiniProgramRoot: s.popToMiniProgramRoot,
  popToMiniProgramScreen: s.popToMiniProgramScreen,
  child: child,
);
