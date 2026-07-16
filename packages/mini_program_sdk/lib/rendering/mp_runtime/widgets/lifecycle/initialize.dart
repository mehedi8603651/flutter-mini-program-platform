part of '../../../mp_screen_renderer.dart';

enum _MpInitializeStatus { loading, success, error }

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
