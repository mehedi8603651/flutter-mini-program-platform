part of '../../../mp_screen_renderer.dart';

enum _MpLazyStatus { idle, loading, success, error }

class _MpLazySection extends StatefulWidget {
  const _MpLazySection({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpLazySection> createState() => _MpLazySectionState();
}

class _MpLazySectionState extends State<_MpLazySection> {
  _MpLazyStatus _status = _MpLazyStatus.idle;
  bool _started = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpLazySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_runtimeKey(widget) != _runtimeKey(oldWidget)) {
      _generation += 1;
      _started = false;
      _status = _MpLazyStatus.idle;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    if (_started) {
      return;
    }
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }

    if (_bool(widget.node, 'once') &&
        _mpLazyOnceKeys.contains(_onceKey(scope))) {
      _status = _MpLazyStatus.success;
      _writeStatus(scope, 'success');
      return;
    }

    _started = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      unawaited(_run(activeScope, generation));
    });
  }

  Future<void> _run(MiniProgramSdkScope scope, int generation) async {
    final cacheKey = widget.node.props['cacheKey'] as String?;
    final targetState = widget.node.props['targetState'] as String?;
    final state = scope.stateManager;
    _writeStatus(scope, 'loading');

    if (cacheKey != null) {
      if (state == null) {
        _finishError(scope, generation);
        return;
      }
      final cache = scope.cacheManager.forApp(
        scope.miniProgramId,
        policy: scope.cachePolicy,
      );
      final bucket = _lazyCacheBucket(widget.node);
      final found = await cache.has(cacheKey, bucket: bucket);
      if (!mounted || generation != _generation) {
        return;
      }
      if (found) {
        final cachedValue = await cache.get<Object?>(cacheKey, bucket: bucket);
        if (!mounted || generation != _generation) {
          return;
        }
        state.set(targetState!, cachedValue);
        _writeStatus(scope, 'success');
        _finishSuccess(scope, generation);
        if (!_bool(widget.node, 'refreshIfCached')) {
          return;
        }
        await _runActionsAndMaybeCache(
          scope,
          generation,
          preserveCachedContent: true,
        );
        return;
      }
    }

    if ((widget.node.props['actions'] as List<_MpAction>).isEmpty) {
      _writeStatus(scope, 'success');
      await _saveTargetStateToCache(scope, generation);
      _finishSuccess(scope, generation);
      return;
    }

    _setStatus(_MpLazyStatus.loading, generation);
    await _runActionsAndMaybeCache(
      scope,
      generation,
      preserveCachedContent: false,
    );
  }

  Future<void> _runActionsAndMaybeCache(
    MiniProgramSdkScope scope,
    int generation, {
    required bool preserveCachedContent,
  }) async {
    final retry = _int(widget.node, 'retry', fallback: 0);
    final retryDelay = Duration(
      milliseconds: _int(widget.node, 'retryDelayMs', fallback: 300),
    );

    _MpLazyActionOutcome outcome = const _MpLazyActionOutcome.failure();
    for (var attempt = 0; attempt <= retry; attempt += 1) {
      outcome = await _runActions(scope);
      if (!mounted || generation != _generation) {
        return;
      }
      if (outcome.success) {
        break;
      }
      if (attempt < retry && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
        if (!mounted || generation != _generation) {
          return;
        }
      }
    }

    if (!outcome.success) {
      if (!preserveCachedContent) {
        _writeStatus(scope, 'error');
        _finishError(scope, generation);
      }
      return;
    }

    final targetState = widget.node.props['targetState'] as String?;
    if (targetState != null && outcome.hasData) {
      final state = scope.stateManager;
      if (state == null) {
        if (!preserveCachedContent) {
          _finishError(scope, generation);
        }
        return;
      }
      state.set(targetState, outcome.data);
    }
    await _saveTargetStateToCache(scope, generation);
    _writeStatus(scope, 'success');
    _finishSuccess(scope, generation);
  }

  Future<_MpLazyActionOutcome> _runActions(MiniProgramSdkScope scope) async {
    final actions = widget.node.props['actions'] as List<_MpAction>;
    if (actions.isEmpty) {
      return const _MpLazyActionOutcome.success(hasData: false);
    }

    Object? lastResult;
    for (final action in actions) {
      lastResult = await _MpActionDispatcher.dispatch(
        context,
        action,
        widget.bindings.copyWith(scope: scope),
      );
      if (_lazyActionFailed(lastResult)) {
        return _MpLazyActionOutcome.failure(lastResult);
      }
    }
    return _MpLazyActionOutcome.success(
      data: _lazyResultData(lastResult),
      hasData: true,
    );
  }

  Future<void> _saveTargetStateToCache(
    MiniProgramSdkScope scope,
    int generation,
  ) async {
    final cacheKey = widget.node.props['cacheKey'] as String?;
    final targetState = widget.node.props['targetState'] as String?;
    if (cacheKey == null || targetState == null) {
      return;
    }
    final state = scope.stateManager;
    if (state == null) {
      return;
    }
    final value = state.get<Object?>(targetState);
    await scope.cacheManager
        .forApp(scope.miniProgramId, policy: scope.cachePolicy)
        .set(
          cacheKey,
          value,
          bucket: _lazyCacheBucket(widget.node),
          ttl: _lazyTtl(widget.node),
        );
    if (!mounted || generation != _generation) {
      return;
    }
  }

  void _finishSuccess(MiniProgramSdkScope scope, int generation) {
    if (_bool(widget.node, 'once')) {
      _mpLazyOnceKeys.add(_onceKey(scope));
    }
    _setStatus(_MpLazyStatus.success, generation);
  }

  void _finishError(MiniProgramSdkScope scope, int generation) {
    _setStatus(_MpLazyStatus.error, generation);
  }

  void _setStatus(_MpLazyStatus status, int generation) {
    if (!mounted || generation != _generation || _status == status) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  void _writeStatus(MiniProgramSdkScope scope, String value) {
    final statusState = widget.node.props['statusState'] as String?;
    if (statusState == null) {
      return;
    }
    scope.stateManager?.set(statusState, value);
  }

  String _onceKey(MiniProgramSdkScope scope) {
    return '${scope.miniProgramId}/${widget.bindings.screenId ?? 'unknown'}/'
        '${_string(widget.node, 'id')}';
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    return switch (_status) {
      _MpLazyStatus.idle =>
        widget.node.props.containsKey('cacheKey')
            ? const SizedBox.shrink()
            : _renderTemplate(scope, 'placeholder') ?? const SizedBox.shrink(),
      _MpLazyStatus.loading =>
        _renderTemplate(scope, 'placeholder') ?? const SizedBox.shrink(),
      _MpLazyStatus.success => _MpNodeView(
        node: widget.node.children.single,
        bindings: widget.bindings.copyWith(scope: scope),
      ),
      _MpLazyStatus.error =>
        _renderTemplate(scope, 'error') ?? const Text('Failed to load'),
    };
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, String propName) {
    final template = widget.node.props[propName] as _MpNode?;
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: widget.bindings.copyWith(scope: scope),
    );
  }
}
