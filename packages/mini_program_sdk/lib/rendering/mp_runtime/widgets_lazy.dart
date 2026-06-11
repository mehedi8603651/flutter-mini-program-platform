part of '../mp_screen_renderer.dart';

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

class _MpLazyChunkPage {
  const _MpLazyChunkPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.pageCount,
  });

  final List<Object?> items;
  final Object? nextCursor;
  final bool hasMore;
  final int pageCount;

  _MpLazyChunkPage copyWith({List<Object?>? items, int? pageCount}) {
    return _MpLazyChunkPage(
      items: items ?? this.items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      pageCount: pageCount ?? this.pageCount,
    );
  }
}

class _MpLazyChunkActionOutcome {
  const _MpLazyChunkActionOutcome.success(this.page)
    : success = true,
      data = null;

  const _MpLazyChunkActionOutcome.failure([this.data])
    : success = false,
      page = const _MpLazyChunkPage(
        items: <Object?>[],
        nextCursor: null,
        hasMore: false,
        pageCount: 0,
      );

  final bool success;
  final _MpLazyChunkPage page;
  final Object? data;
}

abstract final class _MpLazyChunkRegistry {
  static final Map<String, _MpLazyChunkState> _entries =
      <String, _MpLazyChunkState>{};

  static void register(String key, _MpLazyChunkState state) {
    _entries[key] = state;
  }

  static void unregister(String key, _MpLazyChunkState state) {
    if (identical(_entries[key], state)) {
      _entries.remove(key);
    }
  }

  static Future<HostActionResult> loadMore({
    required MiniProgramSdkScope scope,
    required String? screenId,
    required String id,
  }) {
    final key = _lazyChunkRegistryKey(scope.miniProgramId, screenId, id);
    final state = _entries[key];
    if (state == null) {
      return Future<HostActionResult>.value(
        HostActionResult.failed(
          actionName: 'lazy.chunk.loadMore',
          message: 'No active Mp lazy chunk is registered for "$id".',
          errorCode: 'lazy_chunk_not_registered',
        ),
      );
    }
    return state.loadMoreFromAction();
  }
}

final Set<String> _mpLazyChunkOnceKeys = <String>{};

String _lazyChunkRegistryKey(
  String miniProgramId,
  String? screenId,
  String id,
) {
  return '$miniProgramId/${screenId ?? 'unknown'}/$id';
}

String _lazyChunkRuntimeKey(_MpLazyChunk widget) {
  final node = widget.node;
  final initialActions =
      node.props['initialActions'] as List<_MpAction>? ?? const <_MpAction>[];
  final loadMoreActions =
      node.props['loadMoreActions'] as List<_MpAction>? ?? const <_MpAction>[];
  return <String>[
    widget.bindings.screenId ?? '',
    _string(node, 'id'),
    _string(node, 'itemsState'),
    (node.props['cursorState'] as String?) ?? '',
    (node.props['hasMoreState'] as String?) ?? '',
    (node.props['statusState'] as String?) ?? '',
    (node.props['cacheKeyPrefix'] as String?) ?? '',
    _string(node, 'bucket'),
    _bool(node, 'once').toString(),
    _bool(node, 'refreshIfCached').toString(),
    _int(node, 'retry', fallback: 0).toString(),
    _int(node, 'retryDelayMs', fallback: 300).toString(),
    (node.props['ttlMs'] as int?)?.toString() ?? '',
    for (final action in initialActions) _lazyActionKey(action),
    for (final action in loadMoreActions) _lazyActionKey(action),
  ].join('|');
}

_MpLazyChunkPage _lazyChunkPageFromResult(Object? result) {
  final data = _lazyResultData(result);
  final map = data is Map
      ? Map<String, dynamic>.from(data)
      : const <String, dynamic>{};
  return _MpLazyChunkPage(
    items: _lazyChunkItems(map['items']),
    nextCursor: map['nextCursor'],
    hasMore: _lazyChunkBool(map['hasMore']),
    pageCount: map['pageCount'] is int ? map['pageCount'] as int : 1,
  );
}

_MpLazyChunkPage? _lazyChunkPageFromCache(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map = Map<String, dynamic>.from(value);
  return _MpLazyChunkPage(
    items: _lazyChunkItems(map['items']),
    nextCursor: map['nextCursor'],
    hasMore: _lazyChunkBool(map['hasMore']),
    pageCount: map['pageCount'] is int ? map['pageCount'] as int : 1,
  );
}

List<Object?> _lazyChunkItems(Object? value) {
  return value is List ? List<Object?>.from(value) : const <Object?>[];
}

bool _lazyChunkBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return false;
}

List<Object?> _lazyChunkMergedItems(
  List<Object?> existing,
  List<Object?> incoming,
) {
  if (_lazyChunkHasPrefix(incoming, existing)) {
    return List<Object?>.from(incoming);
  }
  return <Object?>[...existing, ...incoming];
}

List<Object?> _lazyChunkAppendedItems(
  List<Object?> existing,
  List<Object?> incoming,
  List<Object?> merged,
) {
  if (_lazyChunkHasPrefix(incoming, existing)) {
    return incoming.skip(existing.length).toList(growable: false);
  }
  return merged.skip(existing.length).toList(growable: false);
}

bool _lazyChunkHasPrefix(List<Object?> incoming, List<Object?> existing) {
  if (incoming.length < existing.length) {
    return false;
  }
  for (var index = 0; index < existing.length; index += 1) {
    if (!_lazyChunkSameValue(incoming[index], existing[index])) {
      return false;
    }
  }
  return true;
}

bool _lazyChunkSameValue(Object? a, Object? b) {
  try {
    return jsonEncode(a) == jsonEncode(b);
  } catch (_) {
    return a == b;
  }
}

Map<String, dynamic> _lazyChunkStatePayload({
  required List<Object?> items,
  required Object? nextCursor,
  required bool hasMore,
  required int pageCount,
}) {
  return <String, dynamic>{
    'items': items,
    'nextCursor': nextCursor,
    'hasMore': hasMore,
    'pageCount': pageCount,
  };
}

String _lazyChunkInitialCacheKey(String prefix) => '${prefix}__initial';

String _lazyChunkCursorCacheKey(String prefix, Object cursor) {
  final encoded = base64Url
      .encode(utf8.encode(cursor.toString()))
      .replaceAll('=', '');
  return '${prefix}__cursor_$encoded';
}

class _MpLazyActionOutcome {
  const _MpLazyActionOutcome.success({this.data, this.hasData = true})
    : success = true;

  const _MpLazyActionOutcome.failure([this.data])
    : success = false,
      hasData = false;

  final bool success;
  final Object? data;
  final bool hasData;
}

final Set<String> _mpLazyOnceKeys = <String>{};

String _runtimeKey(_MpLazySection widget) {
  final node = widget.node;
  final actions =
      node.props['actions'] as List<_MpAction>? ?? const <_MpAction>[];
  return <String>[
    widget.bindings.screenId ?? '',
    _string(node, 'id'),
    (node.props['cacheKey'] as String?) ?? '',
    _string(node, 'bucket'),
    (node.props['targetState'] as String?) ?? '',
    (node.props['statusState'] as String?) ?? '',
    _bool(node, 'once').toString(),
    _bool(node, 'refreshIfCached').toString(),
    _int(node, 'retry', fallback: 0).toString(),
    _int(node, 'retryDelayMs', fallback: 300).toString(),
    (node.props['ttlMs'] as int?)?.toString() ?? '',
    for (final action in actions) _lazyActionKey(action),
  ].join('|');
}

String _lazyActionKey(_MpAction action) {
  final keys = action.props.keys.toList(growable: false)..sort();
  final propsKey = keys
      .map((key) => '$key=${_lazyStableValueKey(action.props[key])}')
      .join(',');
  return '${action.type}:$propsKey';
}

String _lazyStableValueKey(Object? value) {
  if (value is _MpAction) {
    return _lazyActionKey(value);
  }
  if (value is _MpNode) {
    return 'node:${value.type}';
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '$key=${_lazyStableValueKey(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_lazyStableValueKey).join(',')}]';
  }
  return value.toString();
}

MiniProgramCacheBucket _lazyCacheBucket(_MpNode node) {
  return switch (_string(node, 'bucket')) {
    'memory' => MiniProgramCacheBucket.memory,
    'data' => MiniProgramCacheBucket.data,
    'image' => MiniProgramCacheBucket.image,
    'state' => MiniProgramCacheBucket.state,
    _ => MiniProgramCacheBucket.data,
  };
}

Duration? _lazyTtl(_MpNode node) {
  final ttlMs = node.props['ttlMs'] as int?;
  return ttlMs == null ? null : Duration(milliseconds: ttlMs);
}

bool _lazyActionFailed(Object? result) {
  if (result is HostActionResult) {
    return !result.isSuccess;
  }
  if (result is MiniProgramBackendResult) {
    return !result.isSuccess;
  }
  if (result is Map) {
    final status = result['status'];
    if (status == 'failed' || status == 'failure') {
      return true;
    }
    if (result['success'] == false) {
      return true;
    }
  }
  return false;
}

Object? _lazyResultData(Object? result) {
  if (result is MiniProgramBackendResult) {
    return result.data;
  }
  if (result is HostActionResult) {
    return result.data;
  }
  if (result is Map) {
    if (result.containsKey('data')) {
      return result['data'];
    }
    return Map<String, dynamic>.from(result);
  }
  return result;
}
