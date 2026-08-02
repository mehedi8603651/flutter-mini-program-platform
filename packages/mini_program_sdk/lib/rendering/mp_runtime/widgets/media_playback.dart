part of '../../mp_screen_renderer.dart';

class _MpVideoView extends StatefulWidget {
  const _MpVideoView({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpVideoView> createState() => _MpVideoViewState();
}

class _MpVideoViewState extends State<_MpVideoView> {
  MiniProgramSdkScope? _scope;
  MiniProgramMediaPlaybackSession? _session;
  String? _loadKey;
  String? _errorMessage;
  MiniProgramMediaPlaybackStatus? _lastStatus;
  bool _readyDispatched = false;
  bool _endedDispatched = false;
  bool _errorDispatched = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = MiniProgramSdkScope.maybeOf(context);
    final source = widget.bindings.resolveMap(
      Map<String, dynamic>.from(widget.node.props['source'] as Map),
    );
    final key =
        '${scope?.miniProgramId}|${_string(widget.node, 'playerId')}|'
        '${jsonEncode(source)}';
    if (key == _loadKey && scope == _scope) return;
    _loadKey = key;
    _scope = scope;
    _generation++;
    unawaited(_load(scope, source, _generation));
  }

  Future<void> _load(
    MiniProgramSdkScope? scope,
    Map<String, dynamic> source,
    int generation,
  ) async {
    final previous = _session;
    if (previous != null) previous.removeListener(_handleSessionChanged);
    _session = null;
    _errorMessage = null;
    _readyDispatched = false;
    _endedDispatched = false;
    _errorDispatched = false;
    if (mounted) setState(() {});
    if (scope == null) {
      _setFailure('Mini-program media scope is unavailable.');
      return;
    }
    if (!scope.mediaPlaybackPolicy.videoEnabled) {
      _writeFailure(
        scope,
        MiniProgramErrorCodes.mediaNotAccepted,
        'Video playback is not accepted by host policy.',
      );
      return;
    }
    if (scope.mediaPlaybackManager == null) {
      _writeFailure(
        scope,
        MiniProgramErrorCodes.mediaProviderUnavailable,
        'The host does not provide video playback on this platform.',
      );
      return;
    }
    _writeStatus(scope, 'loading');
    try {
      final session = await _loadMediaSession(
        scope,
        playerId: _string(widget.node, 'playerId'),
        kind: MiniProgramMediaPlaybackKind.video,
        source: source,
        cacheMode: _mediaCacheModeFromName(_string(widget.node, 'cacheMode')),
        autoplay: _bool(widget.node, 'autoplay'),
        loop: _bool(widget.node, 'loop'),
        volume: _double(widget.node, 'volume', fallback: 1),
        speed: _double(widget.node, 'speed', fallback: 1),
        muted: _bool(widget.node, 'muted'),
      );
      if (!mounted || generation != _generation) return;
      _session = session;
      _lastStatus = session.snapshot.status;
      session.addListener(_handleSessionChanged);
      if (session.snapshot.status == MiniProgramMediaPlaybackStatus.error) {
        _writeFailure(
          scope,
          MiniProgramErrorCodes.mediaPlaybackFailed,
          'Video playback failed.',
        );
        return;
      }
      _writeSuccess(scope, session.snapshot.status.name);
      setState(() {});
      if (_isReadyStatus(session.snapshot.status)) {
        _dispatchLifecycleAction(scope, 'onReady', generation);
      }
    } on MiniProgramMediaPlaybackException catch (error) {
      if (!mounted || generation != _generation) return;
      _writeFailure(scope, error.errorCode, error.message);
    } catch (error, stackTrace) {
      scope.logger.error(
        'Inline video failed to load.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'playerId': _string(widget.node, 'playerId'),
        },
      );
      if (!mounted || generation != _generation) return;
      _writeFailure(
        scope,
        MiniProgramErrorCodes.mediaLoadFailed,
        'The video could not be loaded.',
      );
    }
  }

  void _handleSessionChanged() {
    final session = _session;
    final scope = _scope;
    if (!mounted || session == null || scope == null) return;
    final status = session.snapshot.status;
    final previousStatus = _lastStatus;
    if (previousStatus != status) {
      _lastStatus = status;
      if (status == MiniProgramMediaPlaybackStatus.error) {
        _writeFailure(
          scope,
          MiniProgramErrorCodes.mediaPlaybackFailed,
          'Video playback failed.',
        );
        return;
      }
      _errorMessage = null;
      _writeSuccess(scope, status.name);
      if (_isReadyStatus(status)) {
        _dispatchLifecycleAction(scope, 'onReady', _generation);
      }
      if (status == MiniProgramMediaPlaybackStatus.completed &&
          !_endedDispatched) {
        _endedDispatched = true;
        _dispatchLifecycleAction(scope, 'onEnded', _generation);
      } else if (status != MiniProgramMediaPlaybackStatus.completed) {
        _endedDispatched = false;
      }
      _errorDispatched = false;
    }
    setState(() {});
  }

  bool _isReadyStatus(MiniProgramMediaPlaybackStatus status) =>
      switch (status) {
        MiniProgramMediaPlaybackStatus.ready ||
        MiniProgramMediaPlaybackStatus.playing ||
        MiniProgramMediaPlaybackStatus.paused ||
        MiniProgramMediaPlaybackStatus.completed => true,
        _ => false,
      };

  void _writeStatus(MiniProgramSdkScope scope, String status) {
    final key = widget.node.props['statusState'] as String?;
    if (key != null) scope.stateManager?.set(key, status);
  }

  void _writeSuccess(MiniProgramSdkScope scope, String status) {
    scope.stateManager?.batchUpdates(() {
      _writeStatus(scope, status);
      final error = widget.node.props['errorState'] as String?;
      if (error != null) scope.stateManager?.remove(error);
    });
  }

  void _writeFailure(MiniProgramSdkScope scope, String code, String message) {
    scope.stateManager?.batchUpdates(() {
      _writeStatus(scope, 'error');
      final error = widget.node.props['errorState'] as String?;
      if (error != null) {
        scope.stateManager?.set(error, <String, dynamic>{
          'action': 'video.load',
          'code': code,
          'message': message,
        });
      }
    });
    if (!_errorDispatched) {
      _errorDispatched = true;
      _dispatchLifecycleAction(scope, 'onError', _generation);
    }
    _setFailure(message);
  }

  void _dispatchLifecycleAction(
    MiniProgramSdkScope scope,
    String property,
    int generation,
  ) {
    if (property == 'onReady') {
      if (_readyDispatched) return;
      _readyDispatched = true;
    }
    final action = widget.node.props[property] as _MpAction?;
    if (action == null) return;
    unawaited(_runLifecycleAction(scope, action, property, generation));
  }

  Future<void> _runLifecycleAction(
    MiniProgramSdkScope scope,
    _MpAction action,
    String property,
    int generation,
  ) async {
    final result = await _MpActionDispatcher.dispatch(
      context,
      action,
      widget.bindings.copyWith(scope: scope),
    );
    if (!mounted || generation != _generation) return;
    if (result is HostActionResult && !result.isSuccess) {
      scope.logger.warn(
        'Mp video lifecycle action failed.',
        context: <String, Object?>{
          'miniProgramId': scope.miniProgramId,
          'playerId': _string(widget.node, 'playerId'),
          'event': property,
          'action': result.actionName,
          'errorCode': result.errorCode,
        },
      );
    }
  }

  void _setFailure(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  void dispose() {
    _generation++;
    _session?.removeListener(_handleSessionChanged);
    final scope = _scope;
    if (scope != null) {
      unawaited(
        scope.mediaPlaybackManager?.release(
          scope.miniProgramId,
          _string(widget.node, 'playerId'),
        ),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _double(widget.node, 'aspectRatio', fallback: 16 / 9);
    final session = _session;
    Widget child;
    if (session != null) {
      child = session.buildVideoView(
        fit: _mpBoxFit(_string(widget.node, 'fit')),
        controls: _bool(widget.node, 'controls'),
        semanticLabel: widget.bindings.resolveString(
          _string(widget.node, 'semanticLabel'),
        ),
      );
    } else {
      child = _videoPlaceholder();
    }
    return AspectRatio(
      aspectRatio: ratio,
      child: ColoredBox(color: Colors.black, child: child),
    );
  }

  Widget _videoPlaceholder() {
    final poster = widget.node.props['poster'] as String?;
    final placeholder = poster == null
        ? const ColoredBox(color: Colors.black)
        : _MpImage(
            node: _MpNode(
              type: 'image',
              props: <String, dynamic>{
                'cache': true,
                'fadeInDurationMs': 0,
                'fit': 'cover',
                'source': widget.node.props['posterSource'] ?? 'auto',
                'src': poster,
              },
              children: const <_MpNode>[],
            ),
            bindings: widget.bindings,
          );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        placeholder,
        if (_errorMessage == null)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
