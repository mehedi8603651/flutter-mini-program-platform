part of '../../../mp_screen_renderer.dart';

class _MpBrightnessScope extends StatefulWidget {
  const _MpBrightnessScope({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpBrightnessScope> createState() => _MpBrightnessScopeState();
}

class _MpBrightnessScopeState extends State<_MpBrightnessScope> {
  final Object _owner = Object();
  MiniProgramDisplayBrightnessManager? _manager;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleActivation();
  }

  @override
  void didUpdateWidget(covariant _MpBrightnessScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_double(oldWidget.node, 'level', fallback: 1) !=
            _double(widget.node, 'level', fallback: 1) ||
        oldWidget.node.props['statusState'] !=
            widget.node.props['statusState'] ||
        oldWidget.node.props['errorState'] != widget.node.props['errorState']) {
      _scheduleActivation();
    }
  }

  void _scheduleActivation() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final generation = ++_generation;
    scheduleMicrotask(() => _activate(scope, generation));
  }

  Future<void> _activate(MiniProgramSdkScope? scope, int generation) async {
    final previousManager = _manager;
    _manager = null;
    if (previousManager != null) {
      await previousManager.release(_owner);
    }
    if (!mounted || generation != _generation || scope == null) {
      return;
    }

    _writeStatus(scope, 'loading');
    final policy = scope.displayBrightnessPolicy;
    if (!policy.enabled) {
      _writeFailure(
        scope,
        MiniProgramErrorCodes.displayBrightnessNotAccepted,
        'Temporary display brightness is not accepted by this host.',
      );
      return;
    }
    final manager = scope.displayBrightnessManager;
    if (manager == null) {
      _writeFailure(
        scope,
        MiniProgramErrorCodes.displayBrightnessUnavailable,
        'Temporary display brightness is unavailable in this host.',
      );
      return;
    }

    final requestedLevel = _double(widget.node, 'level', fallback: 1);
    final effectiveLevel = math.min(requestedLevel, policy.maxLevel);
    try {
      await manager.acquire(
        miniProgramId: scope.miniProgramId,
        owner: _owner,
        level: effectiveLevel,
      );
      if (!mounted || generation != _generation) {
        await manager.release(_owner);
        return;
      }
      _manager = manager;
      _writeSuccess(scope);
    } on Object catch (error, stackTrace) {
      final failure = error is MiniProgramDisplayBrightnessException
          ? error
          : const MiniProgramDisplayBrightnessException(
              errorCode: MiniProgramErrorCodes.displayBrightnessOperationFailed,
              message: 'The host could not update display brightness.',
            );
      scope.logger.error(
        'Mp brightnessScope could not apply the requested brightness.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'level': effectiveLevel,
        },
      );
      if (mounted && generation == _generation) {
        _writeFailure(scope, failure.errorCode, failure.message);
      }
    }
  }

  void _writeStatus(MiniProgramSdkScope scope, String value) {
    final key = widget.node.props['statusState'] as String?;
    if (key == null) {
      return;
    }
    try {
      scope.stateManager?.set(key, value);
    } on Object catch (error) {
      scope.logger.warn(
        'Mp brightnessScope could not write status state.',
        context: <String, Object?>{'error': error.toString()},
      );
    }
  }

  void _writeSuccess(MiniProgramSdkScope scope) {
    final state = scope.stateManager;
    if (state == null) {
      return;
    }
    final statusState = widget.node.props['statusState'] as String?;
    final errorState = widget.node.props['errorState'] as String?;
    try {
      state.batchUpdates(() {
        if (statusState != null) {
          state.set(statusState, 'active');
        }
        if (errorState != null) {
          state.remove(errorState);
        }
      });
    } on Object catch (error) {
      scope.logger.warn(
        'Mp brightnessScope could not write success state.',
        context: <String, Object?>{'error': error.toString()},
      );
    }
  }

  void _writeFailure(
    MiniProgramSdkScope scope,
    String errorCode,
    String message,
  ) {
    final state = scope.stateManager;
    if (state == null) {
      return;
    }
    final statusState = widget.node.props['statusState'] as String?;
    final errorState = widget.node.props['errorState'] as String?;
    try {
      state.batchUpdates(() {
        if (statusState != null) {
          state.set(statusState, 'error');
        }
        if (errorState != null) {
          state.set(errorState, <String, Object?>{
            'action': 'display.brightnessScope',
            'code': errorCode,
            'message': message,
          });
        }
      });
    } on Object catch (error) {
      scope.logger.warn(
        'Mp brightnessScope could not write failure state.',
        context: <String, Object?>{'error': error.toString()},
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    final manager = _manager;
    _manager = null;
    if (manager != null) {
      unawaited(manager.release(_owner));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _MpNodeView(node: widget.node.children.single, bindings: widget.bindings);
}
