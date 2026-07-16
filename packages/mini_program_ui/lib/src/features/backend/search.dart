import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import '../../core/value_normalization.dart';

/// Backend search and typeahead helper builders.
final class MpSearch {
  /// Creates backend search helper builders.
  const MpSearch();

  /// Creates a state-driven backend search input for typeahead results.
  MpNode input({
    required String stateKey,
    required String targetState,
    required String endpoint,
    String? requestId,
    String queryParam = 'q',
    String limitParam = 'limit',
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    String label = 'Search',
    String? hint,
    String? initialValue,
    int minLength = 2,
    int limit = 20,
    Duration debounce = const Duration(milliseconds: 300),
    String? statusState,
    String? errorState,
    bool clearResultsBelowMinLength = true,
    int? cacheTtlSeconds,
  }) => buildBackendSearchInputNode(
    stateKey: stateKey,
    targetState: targetState,
    endpoint: endpoint,
    requestId: requestId,
    queryParam: queryParam,
    limitParam: limitParam,
    method: method,
    body: body,
    label: label,
    hint: hint,
    initialValue: initialValue,
    minLength: minLength,
    limit: limit,
    debounce: debounce,
    statusState: statusState,
    errorState: errorState,
    clearResultsBelowMinLength: clearResultsBelowMinLength,
    cacheTtlSeconds: cacheTtlSeconds,
  );

  /// Clears the current backend search query, results, status, and error state.
  MpAction clear({
    required String queryState,
    required String targetState,
    String? statusState,
    String? errorState,
  }) {
    return MpAction(
      'search.clear',
      props: <String, Object?>{
        'queryState': requiredStateKey(queryState, 'queryState'),
        'targetState': requiredStateKey(targetState, 'targetState'),
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
      },
    );
  }

  /// Refreshes the first backend search page for the current query.
  MpAction refresh({
    required String queryState,
    required String targetState,
    required String endpoint,
    String? requestId,
    String queryParam = 'q',
    String limitParam = 'limit',
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int limit = 20,
    String itemsPath = 'items',
    String nextCursorPath = 'nextCursor',
    String hasMorePath = 'hasMore',
    String? statusState,
    String? errorState,
    int? cacheTtlSeconds,
    bool skipWhenNoQuery = true,
  }) {
    final normalizedQueryState = requiredStateKey(queryState, 'queryState');
    return MpAction(
      'search.refresh',
      props: <String, Object?>{
        'queryState': normalizedQueryState,
        'targetState': requiredStateKey(targetState, 'targetState'),
        'endpoint': stableAuthoringString(endpoint, 'endpoint'),
        'requestId': requestId == null
            ? '${_generatedSearchRequestId(normalizedQueryState)}_refresh'
            : stableAuthoringString(requestId, 'requestId'),
        'queryParam': requiredFieldName(queryParam, 'queryParam'),
        'limitParam': requiredFieldName(limitParam, 'limitParam'),
        'method': _searchMethod(method),
        if (body.isNotEmpty) 'body': body,
        'limit': _searchLimit(limit),
        'itemsPath': stableAuthoringString(itemsPath, 'itemsPath'),
        'nextCursorPath': stableAuthoringString(
          nextCursorPath,
          'nextCursorPath',
        ),
        'hasMorePath': stableAuthoringString(hasMorePath, 'hasMorePath'),
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
        if (cacheTtlSeconds != null)
          'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
        if (!skipWhenNoQuery) 'skipWhenNoQuery': false,
      },
    );
  }

  /// Loads the next backend search page into an existing search result state.
  MpAction loadMore({
    required String queryState,
    required String targetState,
    required String endpoint,
    String? requestId,
    String queryParam = 'q',
    String cursorParam = 'cursor',
    String limitParam = 'limit',
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int limit = 20,
    String itemsPath = 'items',
    String nextCursorPath = 'nextCursor',
    String hasMorePath = 'hasMore',
    String? statusState,
    String? errorState,
    int? cacheTtlSeconds,
    bool skipWhenNoQuery = true,
  }) {
    final normalizedQueryState = requiredStateKey(queryState, 'queryState');
    return MpAction(
      'search.loadMore',
      props: <String, Object?>{
        'queryState': normalizedQueryState,
        'targetState': requiredStateKey(targetState, 'targetState'),
        'endpoint': stableAuthoringString(endpoint, 'endpoint'),
        'requestId': requestId == null
            ? '${_generatedSearchRequestId(normalizedQueryState)}_load_more'
            : stableAuthoringString(requestId, 'requestId'),
        'queryParam': requiredFieldName(queryParam, 'queryParam'),
        'cursorParam': requiredFieldName(cursorParam, 'cursorParam'),
        'limitParam': requiredFieldName(limitParam, 'limitParam'),
        'method': _searchMethod(method),
        if (body.isNotEmpty) 'body': body,
        'limit': _searchLimit(limit),
        'itemsPath': stableAuthoringString(itemsPath, 'itemsPath'),
        'nextCursorPath': stableAuthoringString(
          nextCursorPath,
          'nextCursorPath',
        ),
        'hasMorePath': stableAuthoringString(hasMorePath, 'hasMorePath'),
        if (statusState != null)
          'statusState': requiredStateKey(statusState, 'statusState'),
        if (errorState != null)
          'errorState': requiredStateKey(errorState, 'errorState'),
        if (cacheTtlSeconds != null)
          'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
        if (!skipWhenNoQuery) 'skipWhenNoQuery': false,
      },
    );
  }
}

MpNode buildBackendSearchInputNode({
  required String stateKey,
  required String targetState,
  required String endpoint,
  String? requestId,
  String queryParam = 'q',
  String limitParam = 'limit',
  String method = 'GET',
  Map<String, Object?> body = const <String, Object?>{},
  String label = 'Search',
  String? hint,
  String? initialValue,
  int minLength = 2,
  int limit = 20,
  Duration debounce = const Duration(milliseconds: 300),
  String? statusState,
  String? errorState,
  bool clearResultsBelowMinLength = true,
  int? cacheTtlSeconds,
}) {
  return MpNode(
    'searchInput',
    props: _searchInputProps(
      stateKey: stateKey,
      targetState: targetState,
      endpoint: endpoint,
      requestId: requestId,
      queryParam: queryParam,
      limitParam: limitParam,
      method: method,
      body: body,
      label: label,
      hint: hint,
      initialValue: initialValue,
      minLength: minLength,
      limit: limit,
      debounce: debounce,
      statusState: statusState,
      errorState: errorState,
      clearResultsBelowMinLength: clearResultsBelowMinLength,
      cacheTtlSeconds: cacheTtlSeconds,
    ),
  );
}

String _generatedSearchRequestId(String stateKey) {
  return 'search_${stateKey.replaceAll('.', '_')}';
}

int _searchLimit(int value) {
  if (value <= 0 || value > 100) {
    throw ArgumentError.value(
      value,
      'limit',
      'Search limit must be between 1 and 100.',
    );
  }
  return value;
}

String _searchMethod(String value) {
  final method = requiredAuthoringString(value, 'method').toUpperCase();
  if (method != 'GET' && method != 'POST') {
    throw ArgumentError.value(
      value,
      'method',
      'Search method must be GET or POST.',
    );
  }
  return method;
}

Map<String, Object?> _searchInputProps({
  required String stateKey,
  required String targetState,
  required String endpoint,
  String? requestId,
  String queryParam = 'q',
  String limitParam = 'limit',
  String method = 'GET',
  Map<String, Object?> body = const <String, Object?>{},
  String label = 'Search',
  String? hint,
  String? initialValue,
  int minLength = 2,
  int limit = 20,
  Duration debounce = const Duration(milliseconds: 300),
  String? statusState,
  String? errorState,
  bool clearResultsBelowMinLength = true,
  int? cacheTtlSeconds,
}) {
  final normalizedStateKey = requiredStateKey(stateKey, 'stateKey');
  return <String, Object?>{
    'stateKey': normalizedStateKey,
    'targetState': requiredStateKey(targetState, 'targetState'),
    'endpoint': stableAuthoringString(endpoint, 'endpoint'),
    'requestId': requestId == null
        ? _generatedSearchRequestId(normalizedStateKey)
        : stableAuthoringString(requestId, 'requestId'),
    'queryParam': requiredFieldName(queryParam, 'queryParam'),
    'limitParam': requiredFieldName(limitParam, 'limitParam'),
    'method': _searchMethod(method),
    if (body.isNotEmpty) 'body': body,
    'label': requiredAuthoringString(label, 'label'),
    if (hint != null) 'hint': requiredAuthoringString(hint, 'hint'),
    if (initialValue != null) 'initialValue': initialValue,
    'minLength': nonNegativeInt(minLength, 'minLength'),
    'limit': _searchLimit(limit),
    'debounceMs': nonNegativeInt(debounce.inMilliseconds, 'debounceMs'),
    if (statusState != null)
      'statusState': requiredStateKey(statusState, 'statusState'),
    if (errorState != null)
      'errorState': requiredStateKey(errorState, 'errorState'),
    if (!clearResultsBelowMinLength) 'clearResultsBelowMinLength': false,
    if (cacheTtlSeconds != null)
      'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
  };
}
