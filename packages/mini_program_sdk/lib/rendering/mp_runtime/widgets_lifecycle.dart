part of '../mp_screen_renderer.dart';

enum _MpInitializeStatus { loading, success, error }

class _MpCondition extends StatelessWidget {
  const _MpCondition({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final activeBindings = bindings.copyWith(scope: scope);
    final state = scope?.stateManager;
    final paths = _stateBindingPaths(node.props['condition']);
    if (state == null || paths.isEmpty) {
      return _buildBranch(activeBindings);
    }
    final listenable = Listenable.merge(
      paths.map(state.watch).toList(growable: false),
    );
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) => _buildBranch(
        bindings.copyWith(scope: MiniProgramSdkScope.maybeOf(context)),
      ),
    );
  }

  Widget _buildBranch(_MpRenderBindings activeBindings) {
    final resolved = activeBindings.resolveValue(node.props['condition']);
    final template = resolved == true
        ? node.props['whenTrue'] as _MpNode
        : node.props['whenFalse'] as _MpNode?;
    return template == null
        ? const SizedBox.shrink()
        : _MpNodeView(node: template, bindings: activeBindings);
  }
}

class _MpCountdown extends StatefulWidget {
  const _MpCountdown({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpCountdown> createState() => _MpCountdownState();
}

class _MpCountdownState extends State<_MpCountdown>
    with WidgetsBindingObserver {
  final List<Listenable> _inputListenables = <Listenable>[];
  final Set<String> _inputPaths = <String>{};

  MpStateManager? _stateManager;
  Timer? _timer;
  DateTime? _lastWakeAt;
  DateTime? _suspendedAt;
  Duration _scheduledDelay = Duration.zero;
  Duration _remaining = Duration.zero;
  Object? _restartToken;
  bool _initialized = false;
  bool _running = false;
  bool _completed = false;
  bool _lifecycleSuspended = false;
  int? _lastWrittenSeconds;
  int _generation = 0;

  Duration get _duration =>
      Duration(milliseconds: _int(widget.node, 'durationMs', fallback: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = MiniProgramSdkScope.maybeOf(context);
    final managerChanged = !identical(scope?.stateManager, _stateManager);
    _replaceInputListeners(scope?.stateManager);
    if (!_initialized && scope != null) {
      _reset(scope, notify: false, deferStart: true);
    } else if (_initialized && managerChanged && scope != null) {
      _reset(scope, notify: false, deferStart: true);
    } else if (_initialized && scope != null) {
      _synchronizeBoundInputs(scope, notify: false);
    }
  }

  @override
  void didUpdateWidget(covariant _MpCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scope = MiniProgramSdkScope.maybeOf(context);
    _replaceInputListeners(scope?.stateManager);
    if (scope == null) {
      return;
    }
    final configurationChanged =
        _int(oldWidget.node, 'durationMs', fallback: 1) !=
            _int(widget.node, 'durationMs', fallback: 1) ||
        oldWidget.node.props['remainingState'] !=
            widget.node.props['remainingState'] ||
        _countdownCompletionKey(oldWidget.node) !=
            _countdownCompletionKey(widget.node);
    if (configurationChanged) {
      _reset(scope, notify: false, deferStart: true);
    } else {
      _synchronizeBoundInputs(scope, notify: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeFromLifecycle();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _suspendForLifecycle();
    }
  }

  void _replaceInputListeners(MpStateManager? manager) {
    final nextPaths = <String>{
      ..._stateBindingPaths(widget.node.props['running']),
      ..._stateBindingPaths(widget.node.props['restartToken']),
    };
    if (identical(manager, _stateManager) &&
        _stateValuesEqual(
          nextPaths.toList()..sort(),
          _inputPaths.toList()..sort(),
        )) {
      return;
    }
    for (final listenable in _inputListenables) {
      listenable.removeListener(_handleBoundInputChange);
    }
    _inputListenables.clear();
    _inputPaths
      ..clear()
      ..addAll(nextPaths);
    _stateManager = manager;
    if (manager == null) {
      return;
    }
    for (final path in nextPaths) {
      final listenable = manager.watch(path);
      listenable.addListener(_handleBoundInputChange);
      _inputListenables.add(listenable);
    }
  }

  void _handleBoundInputChange() {
    if (!mounted) {
      return;
    }
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope != null) {
      _synchronizeBoundInputs(scope, notify: true);
    }
  }

  void _synchronizeBoundInputs(
    MiniProgramSdkScope scope, {
    required bool notify,
  }) {
    final bindings = widget.bindings.copyWith(scope: scope);
    final nextToken = bindings.resolveValue(widget.node.props['restartToken']);
    final nextRunning =
        bindings.resolveValue(widget.node.props['running']) == true;
    if (!_stateValuesEqual(nextToken, _restartToken)) {
      _reset(scope, notify: notify, deferStart: !notify);
      return;
    }
    if (nextRunning == _running) {
      return;
    }
    if (nextRunning) {
      _running = true;
      if (!_completed) {
        _resume();
      }
    } else {
      _pause();
    }
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _reset(
    MiniProgramSdkScope scope, {
    required bool notify,
    bool deferStart = false,
  }) {
    _generation += 1;
    _timer?.cancel();
    _timer = null;
    _lastWakeAt = null;
    _scheduledDelay = Duration.zero;
    _remaining = _duration;
    _completed = false;
    _lastWrittenSeconds = null;
    final bindings = widget.bindings.copyWith(scope: scope);
    _restartToken = bindings.resolveValue(widget.node.props['restartToken']);
    _running = bindings.resolveValue(widget.node.props['running']) == true;
    _initialized = true;
    if (deferStart) {
      final generation = _generation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) {
          return;
        }
        final activeScope = MiniProgramSdkScope.maybeOf(context);
        if (activeScope == null) {
          return;
        }
        _writeRemaining(activeScope);
        if (_running) {
          _resume();
        }
        setState(() {});
      });
    } else {
      _writeRemaining(scope);
      if (_running) {
        _resume();
      }
      if (notify && mounted) {
        setState(() {});
      }
    }
  }

  void _resume() {
    if (_completed || _remaining <= Duration.zero || _lifecycleSuspended) {
      return;
    }
    _scheduleNextWake();
  }

  void _pause() {
    if (_running && !_lifecycleSuspended) {
      _captureWallClockElapsed();
    }
    _running = false;
    _lastWakeAt = null;
    _scheduledDelay = Duration.zero;
    _timer?.cancel();
    _timer = null;
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope != null) {
      _writeRemaining(scope);
    }
  }

  void _scheduleNextWake() {
    _timer?.cancel();
    if (!_running ||
        _completed ||
        _lifecycleSuspended ||
        _remaining <= Duration.zero) {
      return;
    }
    final remainingMicros = _remaining.inMicroseconds;
    final seconds = (remainingMicros / Duration.microsecondsPerSecond).ceil();
    final untilNextSecond =
        remainingMicros - ((seconds - 1) * Duration.microsecondsPerSecond);
    _scheduledDelay = Duration(microseconds: math.max(1, untilNextSecond));
    _lastWakeAt = DateTime.now();
    _timer = Timer(_scheduledDelay, _handleTimerWake);
  }

  void _handleTimerWake() {
    if (!_running || _completed || _lifecycleSuspended) {
      return;
    }
    final wallElapsed = _lastWakeAt == null
        ? Duration.zero
        : DateTime.now().difference(_lastWakeAt!);
    final elapsed = wallElapsed > _scheduledDelay
        ? wallElapsed
        : _scheduledDelay;
    _remaining = elapsed >= _remaining ? Duration.zero : _remaining - elapsed;
    _lastWakeAt = null;
    _scheduledDelay = Duration.zero;
    if (_remaining <= Duration.zero) {
      _complete();
      return;
    }
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope != null) {
      _writeRemaining(scope);
    }
    if (mounted) {
      setState(() {});
    }
    _scheduleNextWake();
  }

  void _captureWallClockElapsed() {
    final lastWakeAt = _lastWakeAt;
    if (lastWakeAt == null) {
      return;
    }
    final elapsed = DateTime.now().difference(lastWakeAt);
    if (elapsed > Duration.zero) {
      _remaining = elapsed >= _remaining ? Duration.zero : _remaining - elapsed;
    }
  }

  void _suspendForLifecycle() {
    if (_lifecycleSuspended || !_running || _completed) {
      return;
    }
    _captureWallClockElapsed();
    _timer?.cancel();
    _timer = null;
    _lastWakeAt = null;
    _scheduledDelay = Duration.zero;
    _lifecycleSuspended = true;
    _suspendedAt = DateTime.now();
  }

  void _resumeFromLifecycle() {
    if (!_lifecycleSuspended) {
      return;
    }
    final suspendedAt = _suspendedAt;
    _lifecycleSuspended = false;
    _suspendedAt = null;
    if (_running && !_completed && suspendedAt != null) {
      final elapsed = DateTime.now().difference(suspendedAt);
      if (elapsed > Duration.zero) {
        _remaining = elapsed >= _remaining
            ? Duration.zero
            : _remaining - elapsed;
      }
      if (_remaining <= Duration.zero) {
        _complete();
      } else {
        final scope = MiniProgramSdkScope.maybeOf(context);
        if (scope != null) {
          _writeRemaining(scope);
        }
        if (mounted) {
          setState(() {});
        }
        _resume();
      }
    }
  }

  void _complete() {
    if (_completed) {
      return;
    }
    _completed = true;
    _running = false;
    _remaining = Duration.zero;
    _lastWakeAt = null;
    _scheduledDelay = Duration.zero;
    _timer?.cancel();
    _timer = null;
    final generation = _generation;
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope != null) {
      _writeRemaining(scope);
      final action = widget.node.props['onComplete'] as _MpAction?;
      if (action != null) {
        unawaited(_dispatchCompletion(scope, action, generation));
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _dispatchCompletion(
    MiniProgramSdkScope scope,
    _MpAction action,
    int generation,
  ) async {
    final result = await _MpActionDispatcher.dispatch(
      context,
      action,
      widget.bindings.copyWith(scope: scope),
    );
    if (generation != _generation ||
        result is! HostActionResult ||
        result.isSuccess) {
      return;
    }
    scope.logger.warn(
      'Mp countdown completion action failed.',
      context: <String, Object?>{
        'miniProgramId': scope.miniProgramId,
        'action': result.actionName,
        'errorCode': result.errorCode,
      },
    );
  }

  void _writeRemaining(MiniProgramSdkScope scope) {
    final key = widget.node.props['remainingState'] as String?;
    if (key == null) {
      return;
    }
    final seconds = (_remaining.inMicroseconds / Duration.microsecondsPerSecond)
        .ceil();
    if (seconds == _lastWrittenSeconds) {
      return;
    }
    try {
      scope.stateManager?.set(key, seconds);
      _lastWrittenSeconds = seconds;
    } catch (error, stackTrace) {
      scope.logger.error(
        'Mp countdown could not write remaining state.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'remainingState': key,
        },
      );
    }
  }

  @override
  void dispose() {
    _generation += 1;
    _timer?.cancel();
    for (final listenable in _inputListenables) {
      listenable.removeListener(_handleBoundInputChange);
    }
    _inputListenables.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MpNodeView(
    node: widget.node.children.single,
    bindings: widget.bindings.copyWith(
      scope: MiniProgramSdkScope.maybeOf(context),
    ),
  );
}

String _countdownCompletionKey(_MpNode node) {
  final action = node.props['onComplete'] as _MpAction?;
  return action == null ? '' : _lazyActionKey(action);
}

class _MpInitialize extends StatefulWidget {
  const _MpInitialize({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpInitialize> createState() => _MpInitializeState();
}

class _MpInitializeState extends State<_MpInitialize> {
  _MpInitializeStatus _status = _MpInitializeStatus.loading;
  bool _started = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpInitialize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initializeRuntimeKey(widget) != _initializeRuntimeKey(oldWidget)) {
      _generation += 1;
      _started = false;
      _status = _MpInitializeStatus.loading;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    if (_started || MiniProgramSdkScope.maybeOf(context) == null) {
      return;
    }
    _started = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) {
        return;
      }
      final scope = MiniProgramSdkScope.maybeOf(context);
      if (scope != null) {
        unawaited(_run(scope, generation));
      }
    });
  }

  Future<void> _run(MiniProgramSdkScope scope, int generation) async {
    try {
      _writeLoading(scope);
      final retry = _int(widget.node, 'retry', fallback: 0);
      final retryDelay = Duration(
        milliseconds: _int(widget.node, 'retryDelayMs', fallback: 300),
      );
      Object? failure;
      for (var attempt = 0; attempt <= retry; attempt += 1) {
        failure = await _runActions(scope);
        if (!mounted || generation != _generation) {
          return;
        }
        if (failure == null) {
          _writeSuccess(scope);
          _setStatus(_MpInitializeStatus.success, generation);
          return;
        }
        if (attempt < retry && retryDelay > Duration.zero) {
          await Future<void>.delayed(retryDelay);
          if (!mounted || generation != _generation) {
            return;
          }
        }
      }
      _writeFailure(scope, failure);
      _setStatus(_MpInitializeStatus.error, generation);
    } on MiniProgramStateLimitException catch (error) {
      _tryWriteFailure(
        scope,
        HostActionResult.failed(
          actionName: 'initialize',
          message: error.toString(),
          errorCode: MiniProgramErrorCodes.stateLimitExceeded,
          data: error.details,
        ),
      );
      _setStatus(_MpInitializeStatus.error, generation);
    } catch (error, stackTrace) {
      scope.logger.error(
        'Mp initialize failed.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'miniProgramId': scope.miniProgramId},
      );
      _tryWriteFailure(scope, error);
      _setStatus(_MpInitializeStatus.error, generation);
    }
  }

  Future<Object?> _runActions(MiniProgramSdkScope scope) async {
    final actions = widget.node.props['actions'] as List<_MpAction>;
    for (final action in actions) {
      final result = await _MpActionDispatcher.dispatch(
        context,
        action,
        widget.bindings.copyWith(scope: scope),
      );
      if (result is HostActionResult && !result.isSuccess) {
        return result;
      }
    }
    return null;
  }

  void _writeLoading(MiniProgramSdkScope scope) {
    final statusState = widget.node.props['statusState'] as String?;
    if (statusState != null) {
      scope.stateManager?.set(statusState, 'loading');
    }
  }

  void _writeSuccess(MiniProgramSdkScope scope) {
    final state = scope.stateManager;
    if (state == null) {
      return;
    }
    final statusState = widget.node.props['statusState'] as String?;
    final errorState = widget.node.props['errorState'] as String?;
    state.batchUpdates(() {
      if (statusState != null) {
        state.set(statusState, 'success');
      }
      if (errorState != null) {
        state.remove(errorState);
      }
    });
  }

  void _writeFailure(MiniProgramSdkScope scope, Object? failure) {
    final state = scope.stateManager;
    if (state == null) {
      return;
    }
    final statusState = widget.node.props['statusState'] as String?;
    final errorState = widget.node.props['errorState'] as String?;
    final result = failure is HostActionResult ? failure : null;
    state.batchUpdates(() {
      if (statusState != null) {
        state.set(statusState, 'error');
      }
      if (errorState != null) {
        state.set(errorState, <String, Object?>{
          'action': result?.actionName ?? 'initialize',
          'code': result?.errorCode ?? MiniProgramErrorCodes.initializeFailed,
          'message': result?.message ?? 'Mp initialization failed.',
        });
      }
    });
  }

  void _tryWriteFailure(MiniProgramSdkScope scope, Object? failure) {
    try {
      _writeFailure(scope, failure);
    } catch (error, stackTrace) {
      scope.logger.warn(
        'Mp initialize could not write failure state.',
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  void _setStatus(_MpInitializeStatus status, int generation) {
    if (!mounted || generation != _generation || _status == status) {
      return;
    }
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_status) {
      _MpInitializeStatus.loading =>
        _renderTemplate('loading') ?? const SizedBox.shrink(),
      _MpInitializeStatus.success => _MpNodeView(
        node: widget.node.children.single,
        bindings: widget.bindings,
      ),
      _MpInitializeStatus.error =>
        _renderTemplate('error') ?? const Text('Failed to initialize'),
    };
  }

  Widget? _renderTemplate(String name) {
    final template = widget.node.props[name] as _MpNode?;
    return template == null
        ? null
        : _MpNodeView(node: template, bindings: widget.bindings);
  }
}

class _MpStateScope extends StatefulWidget {
  const _MpStateScope({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpStateScope> createState() => _MpStateScopeState();
}

class _MpStateScopeState extends State<_MpStateScope> {
  MpStateManager? _stateManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MiniProgramSdkScope.maybeOf(context)?.stateManager;
    if (!identical(next, _stateManager)) {
      _clearOwnedState(widget.node, manager: _stateManager);
      _stateManager = next;
    }
  }

  @override
  void didUpdateWidget(covariant _MpStateScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_string(oldWidget.node, 'prefix') != _string(widget.node, 'prefix')) {
      _clearOwnedState(oldWidget.node);
    }
  }

  void _clearOwnedState(_MpNode node, {MpStateManager? manager}) {
    if (_bool(node, 'clearOnDispose')) {
      (manager ?? _stateManager)?.remove(_string(node, 'prefix'));
    }
  }

  @override
  void dispose() {
    _clearOwnedState(widget.node);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _MpNodeView(node: widget.node.children.single, bindings: widget.bindings);
}

String _initializeRuntimeKey(_MpInitialize widget) {
  final node = widget.node;
  final actions = node.props['actions'] as List<_MpAction>;
  return <String>[
    widget.bindings.screenId ?? '',
    (node.props['statusState'] as String?) ?? '',
    (node.props['errorState'] as String?) ?? '',
    _int(node, 'retry', fallback: 0).toString(),
    _int(node, 'retryDelayMs', fallback: 300).toString(),
    for (final action in actions) _lazyActionKey(action),
  ].join('|');
}
