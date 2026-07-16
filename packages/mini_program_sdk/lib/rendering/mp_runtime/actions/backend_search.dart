part of '../../mp_screen_renderer.dart';

abstract final class _MpBackendSearchActionHandler {
  static Future<HostActionResult> _searchLoadMore(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'search.loadMore';
    final requestId =
        _optionalStringProp(props, 'requestId') ??
        'search_${_stringProp(props, 'queryState').replaceAll('.', '_')}_load_more';
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }

    final queryState = _stringProp(props, 'queryState');
    final targetState = _stringProp(props, 'targetState');
    final query = state.get<Object?>(queryState)?.toString().trim() ?? '';
    if (query.isEmpty && _boolProp(props, 'skipWhenNoQuery')) {
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: const <String, dynamic>{'skipped': true, 'reason': 'no_query'},
      );
    }

    final current = _searchStateMap(state.get<Object?>(targetState));
    if (current['hasMore'] == false) {
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: const <String, dynamic>{'skipped': true, 'reason': 'no_more'},
      );
    }

    final existingItems = _searchListValue(current['items']);
    state.set(targetState, <String, dynamic>{
      ...current,
      'items': existingItems,
      'itemCount': existingItems.length,
      'loadingMore': true,
    });
    _searchWriteStatus(state, props, 'loadingMore');
    _searchClearError(state, props);

    final connector = scope.backendConnector;
    if (connector == null) {
      const message = 'Publisher API is not configured for search.loadMore.';
      _searchPageFailed(
        state: state,
        props: props,
        targetState: targetState,
        current: current,
        existingItems: existingItems,
        message: message,
        errorCode: 'publisher_backend_not_configured',
      );
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: message,
        errorCode: 'publisher_backend_not_configured',
      );
    }

    final method = _optionalStringProp(props, 'method') ?? 'GET';
    final cursor = current['nextCursor'];
    var request = MiniProgramBackendRequest(
      miniProgramId: scope.miniProgramId,
      requestId: requestId,
      endpoint: method == 'GET'
          ? _searchLoadMoreEndpoint(props, query: query, cursor: cursor)
          : _stringProp(props, 'endpoint'),
      method: method,
      body: method == 'GET'
          ? const <String, dynamic>{}
          : _searchLoadMoreBody(props, query: query, cursor: cursor),
      cachePolicy: _cachePolicy(props),
    );
    request = await _authorize(scope, request);
    final result = await connector.call(request);
    if (result.isFailure) {
      _searchPageFailed(
        state: state,
        props: props,
        targetState: targetState,
        current: current,
        existingItems: existingItems,
        message: result.message ?? 'Search load more failed.',
        errorCode: result.errorCode,
      );
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: result.message ?? 'Search load more failed.',
        errorCode: result.errorCode,
        data: result.toJson(),
      );
    }

    final pageItems = _searchReadList(
      result.data,
      _stringProp(props, 'itemsPath'),
    );
    final mergedItems = <Object?>[...existingItems, ...pageItems];
    final nextCursor = _searchReadPath(
      result.data,
      _stringProp(props, 'nextCursorPath'),
    );
    final hasMore = _searchReadBool(
      result.data,
      _stringProp(props, 'hasMorePath'),
    );
    final previousPageCount = current['pageCount'] is int
        ? current['pageCount'] as int
        : existingItems.isEmpty
        ? 0
        : 1;
    final nextState = <String, dynamic>{
      ...current,
      'items': mergedItems,
      'itemCount': mergedItems.length,
      'pageCount': previousPageCount + 1,
      'hasMore': hasMore,
      'nextCursor': nextCursor,
      'loadingMore': false,
      'status': mergedItems.isEmpty ? 'empty' : 'success',
    };
    state.set(targetState, nextState);
    _searchClearError(state, props);
    _searchWriteStatus(state, props, mergedItems.isEmpty ? 'empty' : 'success');
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: nextState,
    );
  }

  static Future<HostActionResult> _searchClear(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'search.clear';
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(actionName);
    }

    state.set(_stringProp(props, 'queryState'), '');
    state.set(_stringProp(props, 'targetState'), _emptySearchState());
    _searchWriteStatus(state, props, 'idle');
    _searchClearError(state, props);
    return HostActionResult.success(
      actionName: actionName,
      data: const <String, dynamic>{'cleared': true},
    );
  }

  static Future<HostActionResult> _searchRefresh(
    MiniProgramSdkScope scope,
    Map<String, dynamic> props,
  ) async {
    const actionName = 'search.refresh';
    final requestId =
        _optionalStringProp(props, 'requestId') ??
        'search_${_stringProp(props, 'queryState').replaceAll('.', '_')}_refresh';
    final state = scope.stateManager;
    if (state == null) {
      return _MpStateActionHandler._stateUnavailable(
        actionName,
        requestId: requestId,
      );
    }

    final queryState = _stringProp(props, 'queryState');
    final targetState = _stringProp(props, 'targetState');
    final query = state.get<Object?>(queryState)?.toString().trim() ?? '';
    if (query.isEmpty && _boolProp(props, 'skipWhenNoQuery')) {
      return HostActionResult.success(
        requestId: requestId,
        actionName: actionName,
        data: const <String, dynamic>{'skipped': true, 'reason': 'no_query'},
      );
    }

    final current = _searchStateMap(state.get<Object?>(targetState));
    final existingItems = _searchListValue(current['items']);
    state.set(targetState, <String, dynamic>{
      ...current,
      'items': existingItems,
      'itemCount': existingItems.length,
      'loadingMore': false,
      'status': 'loading',
    });
    _searchWriteStatus(state, props, 'loading');
    _searchClearError(state, props);

    final connector = scope.backendConnector;
    if (connector == null) {
      const message = 'Publisher API is not configured for search.refresh.';
      _searchPageFailed(
        state: state,
        props: props,
        targetState: targetState,
        current: current,
        existingItems: existingItems,
        message: message,
        errorCode: 'publisher_backend_not_configured',
      );
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: message,
        errorCode: 'publisher_backend_not_configured',
      );
    }

    final method = _optionalStringProp(props, 'method') ?? 'GET';
    var request = MiniProgramBackendRequest(
      miniProgramId: scope.miniProgramId,
      requestId: requestId,
      endpoint: method == 'GET'
          ? _searchLoadMoreEndpoint(props, query: query, cursor: null)
          : _stringProp(props, 'endpoint'),
      method: method,
      body: method == 'GET'
          ? const <String, dynamic>{}
          : _searchLoadMoreBody(props, query: query, cursor: null),
      cachePolicy: _cachePolicy(props),
    );
    request = await _authorize(scope, request);
    final result = await connector.call(request);
    if (result.isFailure) {
      _searchPageFailed(
        state: state,
        props: props,
        targetState: targetState,
        current: current,
        existingItems: existingItems,
        message: result.message ?? 'Search refresh failed.',
        errorCode: result.errorCode,
      );
      return HostActionResult.failed(
        requestId: requestId,
        actionName: actionName,
        message: result.message ?? 'Search refresh failed.',
        errorCode: result.errorCode,
        data: result.toJson(),
      );
    }

    final pageItems = _searchReadList(
      result.data,
      _stringProp(props, 'itemsPath'),
    );
    final nextCursor = _searchReadPath(
      result.data,
      _stringProp(props, 'nextCursorPath'),
    );
    final hasMore = _searchReadBool(
      result.data,
      _stringProp(props, 'hasMorePath'),
    );
    final status = pageItems.isEmpty ? 'empty' : 'success';
    final nextState = <String, dynamic>{
      ...current,
      'items': pageItems,
      'itemCount': pageItems.length,
      'pageCount': 1,
      'hasMore': hasMore,
      'nextCursor': nextCursor,
      'loadingMore': false,
      'status': status,
    };
    state.set(targetState, nextState);
    _searchClearError(state, props);
    _searchWriteStatus(state, props, status);
    return HostActionResult.success(
      requestId: requestId,
      actionName: actionName,
      data: nextState,
    );
  }

  static Map<String, dynamic> _searchStateMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static List<Object?> _searchListValue(Object? value) {
    return value is List ? List<Object?>.from(value) : <Object?>[];
  }

  static Map<String, dynamic> _emptySearchState() {
    return <String, dynamic>{
      'items': <Object?>[],
      'itemCount': 0,
      'pageCount': 0,
      'hasMore': false,
      'nextCursor': null,
      'loadingMore': false,
      'status': 'idle',
    };
  }

  static String _searchLoadMoreEndpoint(
    Map<String, dynamic> props, {
    required String query,
    required Object? cursor,
  }) {
    final parsed = Uri.parse(_stringProp(props, 'endpoint'));
    final params = <String, String>{
      ...parsed.queryParameters,
      _stringProp(props, 'queryParam'): query,
      _stringProp(props, 'limitParam'): _intProp(
        props,
        'limit',
        fallback: 20,
      ).toString(),
    };
    final cursorValue = cursor?.toString().trim();
    if (cursorValue != null && cursorValue.isNotEmpty) {
      params[_stringProp(props, 'cursorParam')] = cursorValue;
    }
    return parsed.replace(queryParameters: params).toString();
  }

  static Map<String, dynamic> _searchLoadMoreBody(
    Map<String, dynamic> props, {
    required String query,
    required Object? cursor,
  }) {
    final body = <String, dynamic>{..._mapProp(props, 'body')};
    body[_stringProp(props, 'queryParam')] = query;
    body[_stringProp(props, 'limitParam')] = _intProp(
      props,
      'limit',
      fallback: 20,
    );
    final cursorValue = cursor?.toString().trim();
    if (cursorValue != null && cursorValue.isNotEmpty) {
      body[_stringProp(props, 'cursorParam')] = cursorValue;
    }
    return body;
  }

  static List<Object?> _searchReadList(Map<String, dynamic> data, String path) {
    final value = _searchReadPath(data, path);
    return value is List ? List<Object?>.from(value) : const <Object?>[];
  }

  static bool _searchReadBool(Map<String, dynamic> data, String path) {
    final value = _searchReadPath(data, path);
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  static Object? _searchReadPath(Object? source, String path) {
    Object? current = source;
    for (final rawSegment in path.split('.')) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) {
        return null;
      }
      if (current is Map) {
        current = current[segment];
      } else if (current is List) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  static void _searchWriteStatus(
    MpStateManager state,
    Map<String, dynamic> props,
    String status,
  ) {
    final statusState = _optionalStringProp(props, 'statusState');
    if (statusState != null) {
      state.set(statusState, status);
    }
  }

  static void _searchClearError(
    MpStateManager state,
    Map<String, dynamic> props,
  ) {
    final errorState = _optionalStringProp(props, 'errorState');
    if (errorState != null) {
      state.remove(errorState);
    }
  }

  static void _searchPageFailed({
    required MpStateManager state,
    required Map<String, dynamic> props,
    required String targetState,
    required Map<String, dynamic> current,
    required List<Object?> existingItems,
    required String message,
    required String? errorCode,
  }) {
    state.set(targetState, <String, dynamic>{
      ...current,
      'items': existingItems,
      'itemCount': existingItems.length,
      'loadingMore': false,
      'status': 'error',
    });
    _searchWriteStatus(state, props, 'error');
    final errorState = _optionalStringProp(props, 'errorState');
    if (errorState != null) {
      state.set(errorState, <String, dynamic>{
        'message': message,
        if (errorCode != null) 'code': errorCode,
      });
    }
  }

  static MiniProgramPagedBackendQuery _pagedQueryFromProps(
    Map<String, dynamic> props,
  ) {
    return MiniProgramPagedBackendQuery(
      requestId: _stringProp(props, 'requestId'),
      endpoint: _stringProp(props, 'endpoint'),
      limit: _intProp(props, 'limit', fallback: 20),
      initialCursor: _optionalStringProp(props, 'initialCursor'),
      cursorParam: _optionalStringProp(props, 'cursorParam') ?? 'cursor',
      limitParam: _optionalStringProp(props, 'limitParam') ?? 'limit',
      itemsPath: _optionalStringProp(props, 'itemsPath') ?? 'items',
      nextCursorPath:
          _optionalStringProp(props, 'nextCursorPath') ?? 'nextCursor',
      hasMorePath: _optionalStringProp(props, 'hasMorePath') ?? 'hasMore',
      cacheTtl: _cacheTtl(props),
    );
  }
}
