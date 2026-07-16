part of '../../../mp_screen_renderer.dart';

class _MpLazyChunk extends StatefulWidget {
  const _MpLazyChunk({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  State<_MpLazyChunk> createState() => _MpLazyChunkState();
}

class _MpLazyChunkState extends State<_MpLazyChunk> {
  _MpLazyStatus _status = _MpLazyStatus.idle;
  List<Object?> _items = const <Object?>[];
  Object? _nextCursor;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  bool _started = false;
  int _pageCount = 0;
  int _generation = 0;
  String? _registeredKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerIfPossible();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _MpLazyChunk oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lazyChunkRuntimeKey(widget) != _lazyChunkRuntimeKey(oldWidget)) {
      _generation += 1;
      _items = const <Object?>[];
      _nextCursor = null;
      _hasMore = false;
      _loadingMore = false;
      _loadMoreFailed = false;
      _started = false;
      _pageCount = 0;
      _status = _MpLazyStatus.idle;
    }
    _registerIfPossible();
    _startIfNeeded();
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  void _registerIfPossible() {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return;
    }
    final key = _lazyChunkRegistryKey(
      scope.miniProgramId,
      widget.bindings.screenId,
      _string(widget.node, 'id'),
    );
    if (_registeredKey == key) {
      return;
    }
    _unregister();
    _registeredKey = key;
    _MpLazyChunkRegistry.register(key, this);
  }

  void _unregister() {
    final key = _registeredKey;
    if (key == null) {
      return;
    }
    _MpLazyChunkRegistry.unregister(key, this);
    _registeredKey = null;
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
        _mpLazyChunkOnceKeys.contains(_onceKey(scope)) &&
        _hydrateFromState(scope)) {
      _writeStatus(scope, _items.isEmpty ? 'empty' : 'success');
      _status = _MpLazyStatus.success;
      _started = true;
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
      unawaited(_runInitial(activeScope, generation));
    });
  }

  bool _hydrateFromState(MiniProgramSdkScope scope) {
    final state = scope.stateManager;
    if (state == null) {
      return false;
    }
    final items = state.get<Object?>(_string(widget.node, 'itemsState'));
    if (items is! List || items.isEmpty) {
      return false;
    }
    _items = List<Object?>.from(items);
    final cursorState = widget.node.props['cursorState'] as String?;
    if (cursorState != null) {
      _nextCursor = state.get<Object?>(cursorState);
    }
    final hasMoreState = widget.node.props['hasMoreState'] as String?;
    if (hasMoreState != null) {
      _hasMore = state.get<bool>(hasMoreState) ?? false;
    }
    _pageCount = 1;
    return true;
  }

  Future<void> _runInitial(MiniProgramSdkScope scope, int generation) async {
    final state = scope.stateManager;
    if (state == null) {
      _finishInitialError(scope, generation);
      return;
    }

    _writeStatus(scope, 'loading');
    final cacheKeyPrefix = widget.node.props['cacheKeyPrefix'] as String?;
    if (cacheKeyPrefix != null) {
      final cached = await _readCachedPage(
        scope,
        _lazyChunkInitialCacheKey(cacheKeyPrefix),
      );
      if (!mounted || generation != _generation) {
        return;
      }
      if (cached != null) {
        _applyPage(scope, cached, append: false, generation: generation);
        _writeStatus(scope, _items.isEmpty ? 'empty' : 'success');
        _finishInitialSuccess(scope, generation);
        if (!_bool(widget.node, 'refreshIfCached')) {
          return;
        }
        await _runInitialActions(scope, generation, preserveVisible: true);
        return;
      }
    }

    _setStatus(_MpLazyStatus.loading, generation);
    await _runInitialActions(scope, generation, preserveVisible: false);
  }

  Future<void> _runInitialActions(
    MiniProgramSdkScope scope,
    int generation, {
    required bool preserveVisible,
  }) async {
    final outcome = await _runActionsWithRetry(
      scope,
      widget.node.props['initialActions'] as List<_MpAction>,
    );
    if (!mounted || generation != _generation) {
      return;
    }
    if (!outcome.success) {
      if (!preserveVisible) {
        _finishInitialError(scope, generation);
      }
      return;
    }
    _applyPage(scope, outcome.page, append: false, generation: generation);
    await _savePageToCache(scope, outcome.page, cursor: null);
    if (!mounted || generation != _generation) {
      return;
    }
    _writeStatus(scope, _items.isEmpty ? 'empty' : 'success');
    _finishInitialSuccess(scope, generation);
  }

  Future<HostActionResult> loadMoreFromAction() async {
    final scope = MiniProgramSdkScope.maybeOf(context);
    if (scope == null) {
      return HostActionResult.failed(
        actionName: 'lazy.chunk.loadMore',
        message: 'Mini-program SDK scope is unavailable for Mp lazy chunk.',
        errorCode: 'sdk_scope_unavailable',
      );
    }
    final state = scope.stateManager;
    if (state == null) {
      return HostActionResult.failed(
        actionName: 'lazy.chunk.loadMore',
        message: 'Mini-program state is unavailable for Mp lazy chunk.',
        errorCode: 'state_unavailable',
      );
    }
    if (_loadingMore || _status == _MpLazyStatus.loading) {
      return HostActionResult.success(
        actionName: 'lazy.chunk.loadMore',
        data: const <String, dynamic>{'skipped': true, 'reason': 'in_flight'},
      );
    }
    if (!_hasMore && _pageCount > 0) {
      return HostActionResult.success(
        actionName: 'lazy.chunk.loadMore',
        data: const <String, dynamic>{'skipped': true, 'reason': 'no_more'},
      );
    }

    final cursor = _nextCursor;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    _writeStatus(scope, 'loadingMore');

    final outcome = await _runActionsWithRetry(
      scope,
      widget.node.props['loadMoreActions'] as List<_MpAction>,
    );
    if (!mounted) {
      return HostActionResult.failed(
        actionName: 'lazy.chunk.loadMore',
        message: 'Mp lazy chunk was disposed before load more completed.',
        errorCode: 'lazy_chunk_disposed',
      );
    }
    if (!outcome.success) {
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
      _writeStatus(scope, 'error');
      return HostActionResult.failed(
        actionName: 'lazy.chunk.loadMore',
        message: 'Mp lazy chunk load more failed.',
        errorCode: 'lazy_chunk_load_more_failed',
      );
    }

    final appendedPage = _applyPage(
      scope,
      outcome.page,
      append: true,
      generation: _generation,
    );
    await _savePageToCache(scope, appendedPage, cursor: cursor);
    if (!mounted) {
      return HostActionResult.failed(
        actionName: 'lazy.chunk.loadMore',
        message: 'Mp lazy chunk was disposed before load more completed.',
        errorCode: 'lazy_chunk_disposed',
      );
    }
    _writeStatus(scope, _items.isEmpty ? 'empty' : 'success');
    return HostActionResult.success(
      actionName: 'lazy.chunk.loadMore',
      data: _lazyChunkStatePayload(
        items: appendedPage.items,
        nextCursor: _nextCursor,
        hasMore: _hasMore,
        pageCount: _pageCount,
      ),
    );
  }

  Future<_MpLazyChunkActionOutcome> _runActionsWithRetry(
    MiniProgramSdkScope scope,
    List<_MpAction> actions,
  ) async {
    final retry = _int(widget.node, 'retry', fallback: 0);
    final retryDelay = Duration(
      milliseconds: _int(widget.node, 'retryDelayMs', fallback: 300),
    );
    _MpLazyChunkActionOutcome outcome =
        const _MpLazyChunkActionOutcome.failure();
    for (var attempt = 0; attempt <= retry; attempt += 1) {
      outcome = await _runActions(scope, actions);
      if (outcome.success) {
        break;
      }
      if (attempt < retry && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
    }
    return outcome;
  }

  Future<_MpLazyChunkActionOutcome> _runActions(
    MiniProgramSdkScope scope,
    List<_MpAction> actions,
  ) async {
    Object? lastResult;
    for (final action in actions) {
      lastResult = await _MpActionDispatcher.dispatch(
        context,
        action,
        widget.bindings.copyWith(scope: scope),
      );
      if (_lazyActionFailed(lastResult)) {
        return _MpLazyChunkActionOutcome.failure(lastResult);
      }
    }
    return _MpLazyChunkActionOutcome.success(
      _lazyChunkPageFromResult(lastResult),
    );
  }

  _MpLazyChunkPage _applyPage(
    MiniProgramSdkScope scope,
    _MpLazyChunkPage page, {
    required bool append,
    required int generation,
  }) {
    final existing = append ? _items : const <Object?>[];
    final mergedItems = append
        ? _lazyChunkMergedItems(existing, page.items)
        : List<Object?>.from(page.items);
    final appendedItems = append
        ? _lazyChunkAppendedItems(existing, page.items, mergedItems)
        : List<Object?>.from(page.items);

    _items = mergedItems;
    _nextCursor = page.nextCursor;
    _hasMore = page.hasMore;
    _pageCount = append ? _pageCount + 1 : page.pageCount;
    _writeState(scope);
    if (mounted && generation == _generation) {
      setState(() {
        _status = _MpLazyStatus.success;
        _loadingMore = false;
        _loadMoreFailed = false;
      });
    }
    return page.copyWith(items: appendedItems, pageCount: _pageCount);
  }

  void _writeState(MiniProgramSdkScope scope) {
    final state = scope.stateManager;
    if (state == null) {
      return;
    }
    state.set(_string(widget.node, 'itemsState'), _items);
    final cursorState = widget.node.props['cursorState'] as String?;
    if (cursorState != null) {
      state.set(cursorState, _nextCursor);
    }
    final hasMoreState = widget.node.props['hasMoreState'] as String?;
    if (hasMoreState != null) {
      state.set(hasMoreState, _hasMore);
    }
  }

  Future<_MpLazyChunkPage?> _readCachedPage(
    MiniProgramSdkScope scope,
    String key,
  ) async {
    final cache = scope.cacheManager.forApp(
      scope.miniProgramId,
      policy: scope.cachePolicy,
    );
    final bucket = _lazyCacheBucket(widget.node);
    if (!await cache.has(key, bucket: bucket)) {
      return null;
    }
    final value = await cache.get<Object?>(key, bucket: bucket);
    return _lazyChunkPageFromCache(value);
  }

  Future<void> _savePageToCache(
    MiniProgramSdkScope scope,
    _MpLazyChunkPage page, {
    required Object? cursor,
  }) async {
    final prefix = widget.node.props['cacheKeyPrefix'] as String?;
    if (prefix == null) {
      return;
    }
    final key = cursor == null
        ? _lazyChunkInitialCacheKey(prefix)
        : _lazyChunkCursorCacheKey(prefix, cursor);
    await scope.cacheManager
        .forApp(scope.miniProgramId, policy: scope.cachePolicy)
        .set(
          key,
          _lazyChunkStatePayload(
            items: page.items,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
            pageCount: page.pageCount,
          ),
          bucket: _lazyCacheBucket(widget.node),
          ttl: _lazyTtl(widget.node),
        );
  }

  void _finishInitialSuccess(MiniProgramSdkScope scope, int generation) {
    if (_bool(widget.node, 'once')) {
      _mpLazyChunkOnceKeys.add(_onceKey(scope));
    }
    _setStatus(_MpLazyStatus.success, generation);
  }

  void _finishInitialError(MiniProgramSdkScope scope, int generation) {
    _writeStatus(scope, 'error');
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
    if ((_status == _MpLazyStatus.idle || _status == _MpLazyStatus.loading) &&
        _items.isEmpty) {
      return _renderTemplate(scope, 'placeholder') ?? const SizedBox.shrink();
    }
    if (_status == _MpLazyStatus.error && _items.isEmpty) {
      return _renderTemplate(scope, 'error') ?? const Text('Failed to load');
    }
    if (_items.isEmpty) {
      return _renderTemplate(scope, 'empty') ?? const SizedBox.shrink();
    }

    final itemTemplate = widget.node.props['itemTemplate'] as _MpNode;
    final children = <Widget>[
      for (var index = 0; index < _items.length; index += 1)
        _MpNodeView(
          node: itemTemplate,
          bindings: widget.bindings.copyWith(
            scope: scope,
            item: _mpItemBinding(_items[index]),
            index: index,
          ),
        ),
    ];

    if (_loadMoreFailed) {
      final error = _renderTemplate(scope, 'error');
      if (error != null) {
        children.add(error);
      }
    } else if (_loadingMore) {
      final loadingMore = _renderTemplate(scope, 'loadingMore');
      if (loadingMore != null) {
        children.add(loadingMore);
      }
    } else if (_hasMore) {
      final loadMore = _renderTemplate(scope, 'loadMore');
      if (loadMore != null) {
        children.add(loadMore);
      }
    } else {
      final end = _renderTemplate(scope, 'end');
      if (end != null) {
        children.add(end);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
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
