part of '../mp_screen_renderer.dart';

class _MpImage extends StatelessWidget {
  const _MpImage({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final src = bindings.resolveString(node.props['src'] as String);
    final source = _resolvedImageSource(src);
    Widget image;
    switch (source) {
      case 'network':
        if (!_isHttpImageSrc(src)) {
          image = _imageErrorFallback(context);
          break;
        }
        image = Image.network(
          src,
          errorBuilder: (context, error, stackTrace) =>
              _imageErrorFallback(context),
          fit: _mpBoxFit(_string(node, 'fit')),
          frameBuilder: _imageFrameBuilder,
          headers: _resolvedHeaders(),
          semanticLabel: _semanticLabel,
        );
        break;
      case 'asset':
        image = Image.asset(
          src,
          errorBuilder: (context, error, stackTrace) =>
              _imageErrorFallback(context),
          fit: _mpBoxFit(_string(node, 'fit')),
          frameBuilder: _imageFrameBuilder,
          semanticLabel: _semanticLabel,
        );
        break;
      case 'base64':
        try {
          image = Image.memory(
            base64Decode(_paddedBase64(_base64ImagePayload(src))),
            errorBuilder: (context, error, stackTrace) =>
                _imageErrorFallback(context),
            fit: _mpBoxFit(_string(node, 'fit')),
            frameBuilder: _imageFrameBuilder,
            semanticLabel: _semanticLabel,
          );
        } on FormatException {
          image = _imageErrorFallback(context);
        }
        break;
      default:
        image = _imageErrorFallback(context);
        break;
    }

    final width = _optionalDouble(node, 'width');
    final height = _optionalDouble(node, 'height');
    if (width == null && height == null) {
      return image;
    }
    return SizedBox(width: width, height: height, child: image);
  }

  String? get _semanticLabel {
    final label = node.props['semanticLabel'] ?? node.props['alt'];
    return label == null ? null : bindings.resolveString(label as String);
  }

  String _resolvedImageSource(String src) {
    final configured = _string(node, 'source');
    if (configured != 'auto') {
      return configured;
    }
    if (_isHttpImageSrc(src)) {
      return 'network';
    }
    if (_isDataUriBase64Image(src)) {
      return 'base64';
    }
    if (_isAssetLikeImageSrc(src)) {
      return 'asset';
    }
    try {
      base64Decode(_paddedBase64(_base64ImagePayload(src)));
      return 'base64';
    } on FormatException {
      return 'asset';
    }
  }

  Map<String, String>? _resolvedHeaders() {
    final headers = node.props['headers'] as Map<String, dynamic>?;
    if (headers == null || headers.isEmpty) {
      return null;
    }
    return <String, String>{
      for (final entry in headers.entries)
        entry.key: bindings.resolveString(entry.value as String),
    };
  }

  Widget _imageFrameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded || frame != null) {
      return _fadeIn(child, wasSynchronouslyLoaded: wasSynchronouslyLoaded);
    }
    return _imageLoadingFallback(context);
  }

  Widget _fadeIn(Widget child, {required bool wasSynchronouslyLoaded}) {
    final durationMs = _int(node, 'fadeInDurationMs', fallback: 200);
    if (wasSynchronouslyLoaded || durationMs <= 0) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: child,
    );
  }

  Widget _imageLoadingFallback(BuildContext context) {
    final placeholder = node.props['placeholder'] as _MpNode?;
    if (placeholder == null) {
      return const SizedBox.shrink();
    }
    return _MpNodeView(node: placeholder, bindings: bindings);
  }

  Widget _imageErrorFallback(BuildContext context) {
    final error = node.props['error'] as _MpNode?;
    if (error != null) {
      return _MpNodeView(node: error, bindings: bindings);
    }
    final label = _semanticLabel;
    if (label != null && label.isNotEmpty) {
      return Text(label);
    }
    return const Text('Image unavailable');
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
    final colors = _mpButtonColors(
      primary: widget.primary,
      enabled: true,
      hoveredOrFocused: _hovered || _focused,
      pressed: _pressed,
      theme: widget.bindings.theme,
    );

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
              color: colors.background,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: _mpThemeTextStyle(
                    widget.bindings.theme,
                    'button',
                    defaultColor: colors.foreground,
                    defaultSize: 15,
                    defaultWeight: 'semibold',
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
  const _MpAuthBuilder({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

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
          bindings: bindings.copyWith(scope: scope),
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

class _MpPagedBackendBuilder extends StatefulWidget {
  const _MpPagedBackendBuilder({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

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
          bindings: widget.bindings.copyWith(
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
      bindings: widget.bindings.copyWith(scope: scope),
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

String _searchEndpoint(
  _MpNode node, {
  required String query,
  required int limit,
}) {
  final parsed = Uri.parse(_string(node, 'endpoint'));
  final params = <String, String>{
    ...parsed.queryParameters,
    _string(node, 'queryParam'): query,
    _string(node, 'limitParam'): limit.toString(),
  };
  return parsed.replace(queryParameters: params).toString();
}

Map<String, dynamic> _searchBody(
  _MpNode node,
  _MpRenderBindings bindings, {
  required String query,
  required int limit,
}) {
  final resolvedBody = Map<String, dynamic>.from(
    bindings.resolveValue(node.props['body']) as Map? ??
        const <String, dynamic>{},
  );
  return <String, dynamic>{
    ...resolvedBody,
    _string(node, 'queryParam'): query,
    _string(node, 'limitParam'): limit,
  };
}

Map<String, dynamic> _normalizeSearchData(Map<String, dynamic> data) {
  if (data.isEmpty) {
    return const <String, dynamic>{'items': <Object?>[]};
  }
  return Map<String, dynamic>.from(data);
}

bool _searchDataIsEmpty(Map<String, dynamic> data) {
  final items = data['items'];
  if (items is List) {
    return items.isEmpty;
  }
  return data.isEmpty;
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
