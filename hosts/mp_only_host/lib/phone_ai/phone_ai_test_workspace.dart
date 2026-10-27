import 'dart:async';

import 'package:flutter/material.dart';

import 'host_ai_bubble.dart';
import 'phone_ai_goal_sheet.dart';
import 'phone_ai_model.dart';
import 'phone_ai_runner.dart';
import 'phone_ai_session.dart';

export 'phone_ai_model.dart' show phoneAiTestEnabled;
export 'host_ai_bubble.dart' show HostAiBubbleStyle;

/// Reference-host assistant composition. The host owns the bubble, goal panel,
/// model client, and runner; none are part of the mini-program artifact or SDK.
class PhoneAiTestWorkspace extends StatefulWidget {
  const PhoneAiTestWorkspace({
    super.key,
    required this.appId,
    required this.dispatch,
    required this.navigatorKey,
    required this.child,
    this.modelFactory = createPhoneAiModel,
    this.limits = const PhoneAiLimits(),
    this.bubbleStyle = const HostAiBubbleStyle(),
    this.onBubbleDocked,
    this.initialGoal,
    this.session,
    this.isHost = false,
  });

  final String appId;
  final PhoneAiDispatch dispatch;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final PhoneAiModelFactory modelFactory;
  final PhoneAiLimits limits;
  final HostAiBubbleStyle bubbleStyle;
  final ValueChanged<Alignment>? onBubbleDocked;
  final String? initialGoal;
  final PhoneAiSession? session;
  final bool isHost;

  @override
  State<PhoneAiTestWorkspace> createState() => _PhoneAiTestWorkspaceState();
}

class _PhoneAiTestWorkspaceState extends State<PhoneAiTestWorkspace>
    with WidgetsBindingObserver {
  late PhoneAiSession _runner;
  ModalBottomSheetRoute<String>? _goalRoute;
  int _foregroundGeneration = 0;

  @override
  void initState() {
    super.initState();
    _createRunner();
    WidgetsBinding.instance.addObserver(this);
  }

  void _createRunner() {
    if (widget.session != null) {
      _runner = widget.session!;
      return;
    }
    final goal =
        widget.initialGoal ??
        switch (widget.appId) {
          'mp_ai_food_demo' =>
            'Prepare a cart with exactly 2 portions of vegetarian noodles, enter '
                'No onions as the delivery note, and open the order review. '
                'Do not submit an order or make a payment.',
          'mp_ai_controls_demo' =>
            'Enter Green tea in Search products, choose Pickup, enable Use a reusable cup, '
                'set Pickup date to October 28, 2026, and open the preference review.',
          _ => 'Open the profile details screen using the visible controls.',
        };
    _runner = PhoneAiRunner(
      appId: widget.appId,
      dispatch: widget.dispatch,
      modelFactory: widget.modelFactory,
      limits: widget.limits,
      draft: goal,
      isForeground: () =>
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didUpdateWidget(PhoneAiTestWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appId != widget.appId ||
        oldWidget.dispatch != widget.dispatch ||
        oldWidget.modelFactory != widget.modelFactory ||
        oldWidget.limits != widget.limits ||
        oldWidget.navigatorKey != widget.navigatorKey ||
        oldWidget.initialGoal != widget.initialGoal ||
        oldWidget.session != widget.session) {
      _removeGoalRoute();
      if (oldWidget.session == null) _runner.dispose();
      _createRunner();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _foregroundGeneration++;
      // The shared owner distinguishes internal task handoff from leaving the
      // app. A background task view must not stop another foreground task.
      if (widget.session == null) {
        _runner.stop('Stopped — mini-program left the foreground');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeGoalRoute();
    if (widget.session == null) _runner.dispose();
    super.dispose();
  }

  void _removeGoalRoute() {
    final route = _goalRoute;
    _goalRoute = null;
    if (route == null) return;
    // Owner replacement/disposal can occur while the Navigator is building.
    // Remove this exact host route without popping a mini-program popup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  Future<void> _configure() async {
    if (_goalRoute != null) return;
    final routeContext = widget.navigatorKey.currentState?.overlay?.context;
    if (routeContext == null) return;
    final runner = _runner;
    // A host panel covers mini-program semantics. Pause before opening it,
    // rather than letting an in-flight decision act behind the panel.
    runner.stop('Paused — assistant panel opened');
    final route = ModalBottomSheetRoute<String>(
      isScrollControlled: true,
      useSafeArea: true,
      modalBarrierColor: Colors.black54,
      barrierLabel: MaterialLocalizations.of(
        routeContext,
      ).modalBarrierDismissLabel,
      builder: (_) => AnimatedBuilder(
        animation: runner,
        builder: (_, _) => PhoneAiGoalSheet(
          title: widget.bubbleStyle.label,
          initialGoal: runner.draft,
          continueGoal: runner.lastGoal,
          onGoalChanged: (value) {
            if (mounted && identical(runner, _runner)) {
              runner.updateDraft(value);
            }
          },
          status: runner.status,
          message: runner.message,
          history: List.of(runner.history),
          canContinue: runner.canContinue,
          decisions: runner.decisions,
          tokens: runner.tokens,
          costUsd: runner.costUsd,
          maxDecisions: runner.limits.maxDecisions,
          onCancelTask: runner.canContinue ? runner.cancel : null,
          isHost: widget.isHost,
        ),
      ),
    );
    setState(() => _goalRoute = route);
    try {
      final goal = await Navigator.of(routeContext).push(route);
      final foregroundGeneration = _foregroundGeneration;
      // A popped route's Future completes before its dismissal animation.
      // Wait for actual removal before observing the mini-program underneath.
      await route.completed;
      if (!mounted ||
          !identical(runner, _runner) ||
          goal == null ||
          foregroundGeneration != _foregroundGeneration ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final resume = runner.canContinue && runner.lastGoal == goal.trim();
      runner.updateDraft(goal);
      FocusManager.instance.primaryFocus?.unfocus();
      unawaited(runner.start(goal, continuePrevious: resume));
    } finally {
      if (mounted && identical(_goalRoute, route)) {
        setState(() => _goalRoute = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _runner,
    child: widget.child,
    builder: (context, child) => HostAiBubble(
      style: widget.bubbleStyle,
      onDocked: widget.onBubbleDocked,
      visible: _goalRoute == null,
      running: _runner.running,
      canStop: _runner.canContinue,
      status: _runner.status,
      statusLabel: switch (_runner.outcome) {
        PhoneAiOutcome.idle => null,
        PhoneAiOutcome.running => 'AI working',
        PhoneAiOutcome.completed => 'Done - tap AI',
        PhoneAiOutcome.needsInput => 'Needs input - tap AI',
        PhoneAiOutcome.blocked || PhoneAiOutcome.limited => 'Paused - tap AI',
        PhoneAiOutcome.failed => 'Error - tap AI',
        PhoneAiOutcome.stopped => 'Paused - tap AI',
        PhoneAiOutcome.cancelled => 'Task cancelled',
      },
      onPressed: _configure,
      onStop: _runner.cancel,
      badge: _runner.outcome == PhoneAiOutcome.idle
          ? null
          : Icon(
              switch (_runner.outcome) {
                PhoneAiOutcome.running => Icons.more_horiz,
                PhoneAiOutcome.completed => Icons.check_circle,
                PhoneAiOutcome.failed => Icons.error,
                PhoneAiOutcome.needsInput => Icons.help,
                PhoneAiOutcome.cancelled => Icons.stop_circle,
                _ => Icons.pause_circle_filled,
              },
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
      child: Listener(
        onPointerDown: (_) =>
            _runner.stop('Paused — you touched the current screen'),
        onPointerSignal: (_) =>
            _runner.stop('Paused — you scrolled the current screen'),
        child: child!,
      ),
    ),
  );
}
