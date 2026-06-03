part of '../mp_screen_renderer.dart';

class _MpScreenView extends StatelessWidget {
  const _MpScreenView({required this.screen});

  final _MpScreen screen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: _MpNodeView(
          node: screen.root,
          bindings: _MpRenderBindings(
            scope: MiniProgramSdkScope.maybeOf(context),
          ),
        ),
      ),
    );
  }
}

class _MpNodeView extends StatelessWidget {
  const _MpNodeView({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    return switch (node.type) {
      'column' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: node.children
            .map((child) => _MpNodeView(node: child, bindings: bindings))
            .toList(growable: false),
      ),
      'row' => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: node.children
            .map(
              (child) => Flexible(
                child: _MpNodeView(node: child, bindings: bindings),
              ),
            )
            .toList(growable: false),
      ),
      'text' => Text(
        bindings.resolveString(node.props['data'] as String),
        style: const TextStyle(
          fontSize: 15,
          height: 1.35,
          color: Color(0xFF263238),
        ),
      ),
      'heading' => Text(
        bindings.resolveString(node.props['data'] as String),
        style: const TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      'sizedBox' => SizedBox(
        width: (node.props['width'] as num?)?.toDouble(),
        height: (node.props['height'] as num?)?.toDouble(),
      ),
      'image' => _MpImage(node: node, bindings: bindings),
      'card' => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _MpNodeView(node: node.children.single, bindings: bindings),
        ),
      ),
      'primaryButton' => _MpButton(
        label: bindings.resolveString(node.props['label'] as String),
        action: node.props['action'] as _MpAction,
        primary: true,
        bindings: bindings,
      ),
      'secondaryButton' => _MpButton(
        label: bindings.resolveString(node.props['label'] as String),
        action: node.props['action'] as _MpAction,
        primary: false,
        bindings: bindings,
      ),
      'authBuilder' => _MpAuthBuilder(node: node),
      'backendBuilder' => _MpBackendBuilder(node: node),
      'pagedBackendBuilder' => _MpPagedBackendBuilder(node: node),
      _ => throw MiniProgramRenderException(
        message: 'Unsupported Mp node type "${node.type}".',
        details: <String, dynamic>{'nodeType': node.type},
      ),
    };
  }
}

class _MpImage extends StatelessWidget {
  const _MpImage({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final src = bindings.resolveString(node.props['src'] as String);
    final uri = Uri.tryParse(src);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                MpScreenValidator._isLocalPreviewHost(uri.host)))) {
      return _imageFallback();
    }
    return Image.network(
      src,
      semanticLabel: node.props['alt'] == null
          ? null
          : bindings.resolveString(node.props['alt'] as String),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _imageFallback(),
    );
  }

  Widget _imageFallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFE5E7EB)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Image unavailable'),
      ),
    );
  }
}

class _MpButton extends StatefulWidget {
  const _MpButton({
    required this.label,
    required this.action,
    required this.primary,
    required this.bindings,
  });

  final String label;
  final _MpAction action;
  final bool primary;
  final _MpRenderBindings bindings;

  @override
  State<_MpButton> createState() => _MpButtonState();
}

class _MpButtonState extends State<_MpButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.primary
        ? (_pressed
              ? const Color(0xFF065F56)
              : _hovered || _focused
              ? const Color(0xFF0F766E)
              : const Color(0xFF0B7A75))
        : const Color(0xFFFFFFFF);
    final foreground = widget.primary
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF0B7A75);

    return Semantics(
      button: true,
      label: widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () => unawaited(
            _MpActionDispatcher.dispatch(
              context,
              widget.action,
              widget.bindings,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: const Color(0xFF0B7A75)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MpAuthBuilder extends StatelessWidget {
  const _MpAuthBuilder({required this.node});

  final _MpNode node;

  @override
  Widget build(BuildContext context) {
    final scope = MiniProgramSdkScope.maybeOf(context);
    final controller = scope?.authController;
    if (scope == null || controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[controller, scope.backendStore]),
      builder: (context, _) {
        final snapshot = controller.snapshot(scope.miniProgramId);
        final template = _templateFor(snapshot);
        if (template == null) {
          return const SizedBox.shrink();
        }
        return _MpNodeView(
          node: template,
          bindings: _MpRenderBindings(scope: scope),
        );
      },
    );
  }

  _MpNode? _templateFor(MiniProgramAuthSnapshot snapshot) {
    if (snapshot.loading) {
      return node.props['loading'] as _MpNode?;
    }
    if (snapshot.authenticated) {
      return node.props['signedIn'] as _MpNode?;
    }
    if (snapshot.hasError) {
      return (node.props['error'] ?? node.props['signedOut']) as _MpNode?;
    }
    return node.props['signedOut'] as _MpNode?;
  }
}

class _MpBackendBuilder extends StatefulWidget {
  const _MpBackendBuilder({required this.node});

  final _MpNode node;

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
      final bindings = _MpRenderBindings(scope: activeScope);
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
            bindings: _MpRenderBindings(
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
      bindings: _MpRenderBindings(scope: scope),
    );
  }
}

class _MpPagedBackendBuilder extends StatefulWidget {
  const _MpPagedBackendBuilder({required this.node});

  final _MpNode node;

  @override
  State<_MpPagedBackendBuilder> createState() => _MpPagedBackendBuilderState();
}

class _MpPagedBackendBuilderState extends State<_MpPagedBackendBuilder> {
  String? _startedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpPagedBackendBuilder oldWidget) {
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
    final key = _queryKey(widget.node);
    if (_startedKey == key) {
      return;
    }
    final snapshot = scope.backendStore.pagedSnapshot(
      _string(widget.node, 'requestId'),
    );
    if (!_bool(widget.node, 'forceRefresh') && !snapshot.isIdle) {
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
      activeScope.backendStore.runPagedQuery(
        connector: activeScope.backendConnector,
        miniProgramId: activeScope.miniProgramId,
        query: _pagedQuery(widget.node),
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
        final snapshot = scope.backendStore.pagedSnapshot(
          _string(widget.node, 'requestId'),
        );
        return _renderSnapshot(scope, snapshot);
      },
    );
  }

  Widget _renderSnapshot(
    MiniProgramSdkScope scope,
    MiniProgramPagedBackendSnapshot snapshot,
  ) {
    if ((snapshot.isIdle || snapshot.isLoading) && !snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['loading'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (snapshot.isFailure && !snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['error'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    if (!snapshot.hasItems) {
      return _renderTemplate(scope, widget.node.props['empty'] as _MpNode?) ??
          const SizedBox.shrink();
    }

    final children = <Widget>[
      for (final rawItem in snapshot.items)
        _MpNodeView(
          node: widget.node.props['itemTemplate'] as _MpNode,
          bindings: _MpRenderBindings(
            scope: scope,
            item: rawItem is Map
                ? Map<String, dynamic>.from(rawItem)
                : <String, dynamic>{'value': rawItem},
          ),
        ),
    ];

    if (snapshot.isFailure) {
      final error = _renderTemplate(
        scope,
        widget.node.props['error'] as _MpNode?,
      );
      if (error != null) {
        children.add(error);
      }
    } else if (snapshot.loadingMore) {
      final loadingMore = _renderTemplate(
        scope,
        widget.node.props['loadingMore'] as _MpNode?,
      );
      if (loadingMore != null) {
        children.add(loadingMore);
      }
    } else if (snapshot.hasMore) {
      final loadMore = _renderTemplate(
        scope,
        widget.node.props['loadMore'] as _MpNode?,
      );
      if (loadMore != null) {
        children.add(loadMore);
      }
    } else {
      final end = _renderTemplate(scope, widget.node.props['end'] as _MpNode?);
      if (end != null) {
        children.add(end);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _renderTemplate(MiniProgramSdkScope scope, _MpNode? template) {
    if (template == null) {
      return null;
    }
    return _MpNodeView(
      node: template,
      bindings: _MpRenderBindings(scope: scope),
    );
  }
}

MiniProgramBackendQuery _backendQuery(
  _MpNode node,
  _MpRenderBindings bindings,
) {
  return MiniProgramBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    method: _string(node, 'method'),
    body: Map<String, dynamic>.from(
      bindings.resolveValue(node.props['body']) as Map? ??
          const <String, dynamic>{},
    ),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

MiniProgramPagedBackendQuery _pagedQuery(_MpNode node) {
  return MiniProgramPagedBackendQuery(
    requestId: _string(node, 'requestId'),
    endpoint: _string(node, 'endpoint'),
    limit: _int(node, 'limit', fallback: 20),
    initialCursor: node.props['initialCursor'] as String?,
    cursorParam: _string(node, 'cursorParam'),
    limitParam: _string(node, 'limitParam'),
    itemsPath: _string(node, 'itemsPath'),
    nextCursorPath: _string(node, 'nextCursorPath'),
    hasMorePath: _string(node, 'hasMorePath'),
    cacheTtl: _duration(node, 'cacheTtlSeconds'),
    forceRefresh: _bool(node, 'forceRefresh'),
  );
}

String _queryKey(_MpNode node) {
  return jsonEncode(
    node.props.map<String, Object?>((key, value) {
      if (value is _MpNode) {
        return MapEntry<String, Object?>(key, value.type);
      }
      return MapEntry<String, Object?>(key, value);
    }),
  );
}

String _string(_MpNode node, String key) => node.props[key] as String;

bool _bool(_MpNode node, String key) => node.props[key] == true;

int _int(_MpNode node, String key, {required int fallback}) {
  return node.props[key] as int? ?? fallback;
}

Duration? _duration(_MpNode node, String key) {
  final seconds = node.props[key] as int?;
  return seconds == null ? null : Duration(seconds: seconds);
}
