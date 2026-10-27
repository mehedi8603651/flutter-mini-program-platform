part of '../mini_program_interaction.dart';

/// Opt-in boundary around one trusted, rendered mini-program subtree.
/// MiniProgramHost installs this automatically when given a controller.
class MiniProgramInteractionSurface extends StatefulWidget {
  const MiniProgramInteractionSurface({
    super.key,
    required this.controller,
    required this.appId,
    required this.screenId,
    required this.child,
    this.visibility = MiniProgramVisibility.foreground,
    this.revisionToken,
    this.onBack,
    this.screenIdProvider,
    this.canGoBack,
  });

  final MiniProgramInteractionController controller;
  final String appId;
  final String screenId;

  /// Reads the loaded screen identity without rebuilding the boundary.
  final String Function()? screenIdProvider;
  final Widget child;
  final MiniProgramVisibility visibility;

  /// An opaque local change counter, never sent to an AI server.
  final Object? Function()? revisionToken;
  final Future<bool> Function()? onBack;
  final bool Function()? canGoBack;

  /// Trusted renderer hook: manual text edits interrupt an AI action sequence.
  static void userInput(BuildContext context) => context
      .getInheritedWidgetOfExactType<_InteractionScope>()
      ?.owner
      .userInput();

  /// Carries ownership to an SDK-created popup route. Other host routes,
  /// authentication UI and native platform views remain outside this boundary.
  static Widget ownedRoute({
    required BuildContext source,
    required Widget child,
  }) => routeBuilder(source)(child);

  /// Capture ownership while the source is active, before a deferred route
  /// builder runs. The builder must never look up a disposed source context.
  static Widget Function(Widget) routeBuilder(BuildContext source) {
    final owner = source
        .getInheritedWidgetOfExactType<_InteractionScope>()
        ?.owner;
    return (child) => owner == null
        ? child
        : _InteractionOwnedRoute(owner: owner, child: child);
  }

  @override
  State<MiniProgramInteractionSurface> createState() =>
      _InteractionSurfaceState();
}

class _InteractionSurfaceState extends State<MiniProgramInteractionSurface>
    with WidgetsBindingObserver {
  final tag = SemanticsTag('mini-program-${_sessionId()}');
  final sessionId = _sessionId();
  final Set<ModalRoute<dynamic>> routes = {};
  ModalRoute<dynamic>? route;
  int generation = 0;
  int revision = 0;
  Object? fingerprint;
  final Map<String, _InteractionTarget> targets = {};
  final Set<MiniProgramInteractionExecution> executions = {};
  int userGeneration = 0;

  bool get pending =>
      executions.any((e) => e.pending > 0 && !e.waitingForPanel);

  bool get visible =>
      mounted &&
      widget.visibility == MiniProgramVisibility.foreground &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  bool get current =>
      visible && (route?.isCurrent != false || routes.any((r) => r.isCurrent));

  String get screenId => widget.screenIdProvider?.call() ?? widget.screenId;

  bool get canGoBack =>
      current &&
      (View.of(context).viewInsets.bottom > 0 ||
          routes.any((r) => r.isCurrent) ||
          (widget.canGoBack?.call() ?? widget.onBack != null) ||
          route?.navigator?.canPop() == true ||
          widget.controller.onExit != null);

  void userInput() {
    if (MiniProgramInteractionExecution.current == null) manualInvalidate();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(MiniProgramInteractionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.appId != widget.appId) {
      // A host ownership change must interrupt work started by the old owner,
      // even when the rendered subtree stays mounted and foregrounded.
      manualInvalidate();
      for (final execution in executions) {
        execution.cancelled = true;
      }
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
    if (oldWidget.appId != widget.appId ||
        oldWidget.visibility != widget.visibility ||
        oldWidget.screenId != widget.screenId) {
      invalidate();
    }
  }

  void invalidate() {
    generation++;
    if (!visible) {
      for (final execution in executions) {
        execution.cancelled = true;
      }
    }
  }

  void manualInvalidate() {
    userGeneration++;
    invalidate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    invalidate();
    if (state != AppLifecycleState.resumed) {
      for (final execution in executions) {
        execution.cancelled = true;
      }
    }
  }

  @override
  void dispose() {
    for (final execution in executions) {
      execution.cancelled = true;
    }
    widget.controller._detach(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InteractionScope(
    owner: this,
    child: Listener(
      onPointerDown: (_) => manualInvalidate(),
      onPointerSignal: (_) => manualInvalidate(),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        tagForChildren: tag,
        child: widget.child,
      ),
    ),
  );
}

class _InteractionScope extends InheritedWidget {
  const _InteractionScope({required this.owner, required super.child});
  final _InteractionSurfaceState owner;
  @override
  bool updateShouldNotify(_InteractionScope oldWidget) =>
      owner != oldWidget.owner;
}

class _InteractionOwnedRoute extends StatefulWidget {
  const _InteractionOwnedRoute({required this.owner, required this.child});
  final _InteractionSurfaceState owner;
  final Widget child;
  @override
  State<_InteractionOwnedRoute> createState() => _InteractionOwnedRouteState();
}

class _InteractionOwnedRouteState extends State<_InteractionOwnedRoute> {
  ModalRoute<dynamic>? route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (route != next) {
      if (route != null) widget.owner.routes.remove(route);
      route = next;
      if (route != null) widget.owner.routes.add(route!);
      widget.owner.invalidate();
    }
  }

  @override
  void dispose() {
    widget.owner.routes.remove(route);
    widget.owner.invalidate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InteractionScope(
    owner: widget.owner,
    child: Listener(
      onPointerDown: (_) => widget.owner.manualInvalidate(),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        tagForChildren: widget.owner.tag,
        child: widget.child,
      ),
    ),
  );
}

String _sessionId() {
  final random = math.Random.secure();
  return List.generate(
    12,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
