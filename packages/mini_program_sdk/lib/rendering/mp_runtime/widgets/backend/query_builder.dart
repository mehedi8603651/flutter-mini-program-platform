part of '../../../mp_screen_renderer.dart';

class _MpBackendBuilder extends StatefulWidget {
  const _MpBackendBuilder({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpBackendBuilder> createState() => _MpBackendBuilderState();
}

class _MpBackendBuilderState extends State<_MpBackendBuilder> {
  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpBackendBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryKey(widget.node) != _queryKey(oldWidget.node)) {
      _startedKey = null;
    }
    _startIfNeeded();
  }

  void _startIfNeeded() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    final model = widget.node;
    final key = _queryKey(model);
    if (_startedKey == key) {
      return;
    }
    final snapshot = scope.backendStore.snapshot(_string(model, 'requestId'));
    if (!_bool(model, 'forceRefresh') && !snapshot.isIdle) {
      _startedKey = key;
      return;
    }

    _startedKey = key;
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final activeScope = MiniProgramSdkScope.maybeOf(context);
      if (activeScope == null) {
        return;
      }
      final bindings = widget.bindings.copyWith(scope: activeScope);
      activeScope.backendStore.runQuery(
        connector: activeScope.backendConnector,
        miniProgramId: activeScope.miniProgramId,
        query: _backendQuery(model, bindings),
        requestInterceptor: activeScope.authController == null
            ? null
            : (request) => activeScope.authController!.authorizeRequest(
                request: request,
                connector: activeScope.backendConnector,
              ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: scope.authController == null
          ? scope.backendStore
          : Listenable.merge(<Listenable>[
              scope.backendStore,
              scope.authController!,
            ]),
      builder: (context, _) {
        final snapshot = scope.backendStore.snapshot(
          _string(widget.node, 'requestId'),
        );
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
  ) {
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasData) {
      return _renderTemplate(scope, widget.node.props['loading'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (snapshot.isFailure) {
      return _renderTemplate(scope, widget.node.props['error'] as _MpNode?) ??
          _renderTemplate(scope, widget.node.props['child'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    final itemTemplate = widget.node.props['itemTemplate'] as _MpNode?;
    if (itemTemplate != null) {
      return _renderItems(scope, snapshot, itemTemplate);
    }

    return _renderTemplate(scope, widget.node.props['child'] as _MpNode?) ??
        const SizedBox.shrink();
  }

  Widget _renderItems(
    MiniProgramSdkScope scope,
    MiniProgramBackendSnapshot snapshot,
    _MpNode itemTemplate,
  ) {
    final itemsPath = widget.node.props['itemsPath'] as String?;
    final rawItems = itemsPath == null || itemsPath.isEmpty
        ? snapshot.data['items']
        : _readPath(snapshot.toBindingData(), itemsPath);
    if (rawItems is! List || rawItems.isEmpty) {
      return _renderTemplate(scope, widget.node.props['empty'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final rawItem in rawItems)
          _MpNodeView(
            node: itemTemplate,
            bindings: widget.bindings.copyWith(
              scope: scope,
              item: rawItem is Map
                  ? Map<String, dynamic>.from(rawItem)
                  : <String, dynamic>{'value': rawItem},
            ),
          ),
      ],
    );
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, _MpNode? template) {
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: widget.bindings.copyWith(scope: scope),
    );
  }
}
