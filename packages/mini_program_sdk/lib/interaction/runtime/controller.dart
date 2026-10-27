part of '../mini_program_interaction.dart';

/// Provider-neutral foreground UI bridge. Owned by the host, never an artifact.
/// No model, API key, server, per-action catalog or native plugin is required.
class MiniProgramInteractionController {
  MiniProgramInteractionController({this.onExit});

  /// Optional host-owned root Back operation (for example, showHost for a
  /// retained separate Android task). The SDK never finishes a task itself.
  final Future<void> Function()? onExit;
  final Map<String, _InteractionSurfaceState> _surfaces = {};
  final LinkedHashMap<String, String> _seen = LinkedHashMap();
  SemanticsHandle? _semantics;
  bool _disposed = false;
  bool _executing = false;

  void _attach(_InteractionSurfaceState surface) {
    if (_disposed) throw StateError('Interaction controller is disposed.');
    _semantics ??= SemanticsBinding.instance.ensureSemantics();
    _surfaces[surface.sessionId] = surface;
  }

  void _detach(_InteractionSurfaceState surface) {
    _surfaces.remove(surface.sessionId);
    if (_surfaces.isEmpty) {
      _semantics?.dispose();
      _semantics = null;
    }
  }

  /// Reads only the current rendered surface. Hidden sessions return no nodes.
  Future<MiniProgramInteractionSnapshot> observe({String? sessionId}) async {
    var rendered = await _frame();
    for (final surface in _surfaces.values.toList()) {
      if (surface.current) rendered = await _settleRoutes(surface) && rendered;
    }
    return _observeNow(sessionId: sessionId, renderPending: !rendered);
  }

  MiniProgramInteractionSnapshot _observeNow({
    String? sessionId,
    bool renderPending = false,
  }) {
    final candidates = _surfaces.values.where((s) => s.current).toList();
    final selected = sessionId == null
        ? candidates.length == 1
              ? candidates.single
              : null
        : _surfaces[sessionId];
    if (selected == null || _disposed) {
      return MiniProgramInteractionSnapshot(
        appId: '',
        sessionId: sessionId ?? '',
        screenId: '',
        revision: 1,
        status: _disposed
            ? 'disposed'
            : candidates.length > 1
            ? 'blocked'
            : 'unavailable',
        nodes: const [],
      );
    }
    return _capture(selected, renderPending: renderPending);
  }

  /// Runs one interaction against exactly the observed session/revision.
  /// Retry an uncertain response by observing; never replay a new request ID.
  Future<MiniProgramInteractionResult> interact(
    MiniProgramInteractionRequest request,
  ) async {
    if (_executing) return _result(request, 'rejected', 'interaction_busy');
    _executing = true;
    try {
      if (!await _frame()) {
        return _result(
          request,
          'rejected',
          'render_pending',
          renderPending: true,
        );
      }
      final snapshot = _observeNow(sessionId: request.sessionId);
      final surface = _surfaces[request.sessionId];
      if (_disposed || surface == null || !surface.current) {
        return _result(request, 'rejected', 'foreground_required');
      }
      if (_seen.containsKey(request.requestId)) {
        return _result(request, 'rejected', 'duplicate_request');
      }
      if (snapshot.revision != request.revision) {
        return _result(request, 'rejected', 'stale_view');
      }
      if (surface.pending) {
        return _result(request, 'pending', 'interaction_pending');
      }
      final target = surface.targets[request.targetId];
      if (request.action != MiniProgramInteractionAction.back &&
          (target == null || !target.actions.contains(request.action))) {
        return _result(request, 'rejected', 'target_unavailable');
      }
      // Bound replay memory. Revision consumption also prevents old commands
      // from becoming executable again after an entry is evicted.
      _seen[request.requestId] = request.sessionId;
      if (_seen.length > 256) _seen.remove(_seen.keys.first);
      surface.generation++;
      final userGeneration = surface.userGeneration;
      final execution = MiniProgramInteractionExecution(
        isAllowed: () =>
            !_disposed &&
            surface.current &&
            surface.userGeneration == userGeneration,
      );
      surface.executions.add(execution);
      try {
        if (request.action == MiniProgramInteractionAction.back) {
          if (!await execution.run(() => _back(surface))) {
            return _result(request, 'rejected', 'back_unavailable');
          }
        } else if (request.action == MiniProgramInteractionAction.enterText) {
          if (!target!.node.getSemanticsData().hasAction(
            SemanticsAction.setText,
          )) {
            execution.run(
              () => target.owner.performAction(
                target.node.id,
                SemanticsAction.tap,
              ),
            );
            await _frame();
          }
          // Focus/keyboard changes may alter the tree. Check this exact live
          // node and ownership again before writing any text.
          _capture(surface);
          final focused = surface.targets[request.targetId];
          if (!execution.isAllowed() ||
              focused == null ||
              !identical(focused.node, target.node) ||
              !focused.node.getSemanticsData().hasAction(
                SemanticsAction.setText,
              )) {
            return _result(request, 'rejected', 'target_unavailable');
          }
          execution.run(
            () => focused.owner.performAction(
              focused.node.id,
              SemanticsAction.setText,
              request.text,
            ),
          );
        } else {
          execution.run(
            () => target!.owner.performAction(
              target.node.id,
              _semanticActions[request.action]!,
            ),
          );
        }
        var rendered = await _frame();
        rendered = await _settleRoutes(surface) && rendered;
        // A second frame catches local state and route changes without waiting
        // indefinitely for animations, open dialogs, or a backend response.
        rendered = await _frame() && rendered;
        final last = execution.lastResult;
        final code = last is HostActionResult && !last.isSuccess
            ? last.errorCode ?? 'action_failed'
            : last is MiniProgramBackendResult && !last.isSuccess
            ? last.errorCode ?? 'backend_failed'
            : null;
        final status = execution.cancelled || !execution.isAllowed()
            ? 'interrupted'
            : execution.failed || code != null
            ? 'failed'
            : surface.pending || !rendered
            ? 'pending'
            : 'completed';
        return _result(request, status, code, renderPending: !rendered);
      } on Object {
        return _result(request, 'failed', 'interaction_failed');
      } finally {
        execution.active = false;
      }
    } finally {
      _executing = false;
    }
  }

  Future<bool> _back(_InteractionSurfaceState surface) async {
    final insets = MediaQuery.viewInsetsOf(surface.context);
    if (insets.bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      return true;
    }
    final popup = surface.routes.where((r) => r.isCurrent).firstOrNull;
    if (popup != null) {
      await popup.navigator?.maybePop();
      return true;
    }
    if (await surface.widget.onBack?.call() == true) return true;
    if (surface.route?.navigator != null &&
        await surface.route!.navigator!.maybePop()) {
      return true;
    }
    if (onExit != null) {
      await onExit!();
      return true;
    }
    return false;
  }

  MiniProgramInteractionResult _result(
    MiniProgramInteractionRequest request,
    String status,
    String? code, {
    bool renderPending = false,
  }) => MiniProgramInteractionResult(
    requestId: request.requestId,
    status: status,
    code: code,
    snapshot: _observeNow(
      sessionId: request.sessionId,
      renderPending: renderPending,
    ),
  );

  /// JSON boundary for a host-owned authenticated transport. Never expose this
  /// as an unauthenticated network service or to artifact-provided code.
  Future<Map<String, Object?>> handleRequest(
    Map<String, dynamic> request,
  ) async {
    try {
      if (utf8.encode(jsonEncode(request)).length > 20000) {
        throw const FormatException('Interaction request is too large.');
      }
      if (request['method'] == 'observe' &&
          request.keys.every((k) => k == 'method' || k == 'sessionId') &&
          (request['sessionId'] == null || request['sessionId'] is String)) {
        return (await observe(
          sessionId: request['sessionId'] as String?,
        )).toJson();
      }
      if (request['method'] == 'interact' &&
          request.length == 2 &&
          request['request'] is Map) {
        return (await interact(
          MiniProgramInteractionRequest.fromJson(
            Map<String, dynamic>.from(request['request'] as Map),
          ),
        )).toJson();
      }
    } on Object {
      return {'status': 'rejected', 'code': 'invalid_request'};
    }
    return {'status': 'rejected', 'code': 'invalid_request'};
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final surface in _surfaces.values) {
      for (final execution in surface.executions) {
        execution.cancelled = true;
      }
    }
    _surfaces.clear();
    _seen.clear();
    _semantics?.dispose();
    _semantics = null;
  }
}

Future<bool> _settleRoutes(_InteractionSurfaceState surface) async {
  bool animating(ModalRoute<dynamic> route) =>
      route.animation?.status == AnimationStatus.forward ||
      route.animation?.status == AnimationStatus.reverse;
  for (
    var i = 0;
    i < 24 &&
        surface.current &&
        ((surface.route != null && animating(surface.route!)) ||
            surface.routes.any(animating));
    i++
  ) {
    if (!await _frame()) return false;
  }
  return !((surface.route != null && animating(surface.route!)) ||
      surface.routes.any(animating));
}

Future<bool> _frame() async {
  WidgetsBinding.instance.ensureVisualUpdate();
  return WidgetsBinding.instance.endOfFrame
      .then((_) => true)
      .timeout(const Duration(milliseconds: 750), onTimeout: () => false);
}
