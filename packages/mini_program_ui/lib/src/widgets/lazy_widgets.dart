import '../mp_action.dart';
import '../mp_node.dart';
import 'widget_props.dart';

const Set<String> _lazyCacheBuckets = <String>{
  'memory',
  'data',
  'image',
  'state',
};
final RegExp _stateKeyPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
);
final RegExp _unsafeCacheKeyPattern = RegExp(r'(^\.)|(\.\.)|[\\/:]');

const Set<String> _blockedStateSegments = <String>{
  'authorization',
  'credential',
  'idtoken',
  'password',
  'refreshtoken',
  'secret',
  'token',
};

MpNode buildLazySectionNode({
  required String id,
  required MpNode child,
  required List<MpAction> actions,
  MpNode? placeholder,
  MpNode? error,
  required bool once,
  String? statusState,
  String? cacheKey,
  required String bucket,
  String? targetState,
  Duration? ttl,
  required bool refreshIfCached,
  required int retry,
  required Duration retryDelay,
}) {
  final normalizedCacheKey = cacheKey == null
      ? null
      : lazyCacheKey(cacheKey, 'cacheKey');
  final normalizedTargetState = targetState == null
      ? null
      : lazyStateKey(targetState, 'targetState');
  if (normalizedCacheKey != null && normalizedTargetState == null) {
    throw ArgumentError('Provide targetState when cacheKey is provided.');
  }
  if (retry < 0) {
    throw ArgumentError.value(retry, 'retry', 'Value must be non-negative.');
  }
  final retryDelayMs = retryDelay.inMilliseconds;
  if (retryDelayMs < 0) {
    throw ArgumentError.value(
      retryDelay,
      'retryDelay',
      'Value must be non-negative.',
    );
  }
  final ttlMs = ttl?.inMilliseconds;
  if (ttlMs != null && ttlMs <= 0) {
    throw ArgumentError.value(ttl, 'ttl', 'Value must be positive.');
  }

  return MpNode(
    'lazy',
    props: <String, Object?>{
      'actions': actions,
      'bucket': lazyCacheBucket(bucket),
      if (normalizedCacheKey != null) 'cacheKey': normalizedCacheKey,
      if (error != null) 'error': error,
      'id': requiredWidgetString(id, 'id'),
      'once': once,
      if (placeholder != null) 'placeholder': placeholder,
      'refreshIfCached': refreshIfCached,
      'retry': retry,
      'retryDelayMs': retryDelayMs,
      if (statusState != null)
        'statusState': lazyStateKey(statusState, 'statusState'),
      if (normalizedTargetState != null) 'targetState': normalizedTargetState,
      if (ttlMs != null) 'ttlMs': ttlMs,
    },
    children: <MpNode>[child],
  );
}

MpNode buildLazyChunkNode({
  required String id,
  required MpNode itemTemplate,
  required List<MpAction> initialActions,
  required List<MpAction> loadMoreActions,
  required String itemsState,
  String? cursorState,
  String? hasMoreState,
  String? statusState,
  String? cacheKeyPrefix,
  required String bucket,
  MpNode? placeholder,
  MpNode? empty,
  MpNode? error,
  MpNode? loadingMore,
  MpNode? loadMore,
  MpNode? end,
  required bool once,
  required bool refreshIfCached,
  Duration? ttl,
  required int retry,
  required Duration retryDelay,
}) {
  if (retry < 0) {
    throw ArgumentError.value(retry, 'retry', 'Value must be non-negative.');
  }
  final retryDelayMs = retryDelay.inMilliseconds;
  if (retryDelayMs < 0) {
    throw ArgumentError.value(
      retryDelay,
      'retryDelay',
      'Value must be non-negative.',
    );
  }
  final ttlMs = ttl?.inMilliseconds;
  if (ttlMs != null && ttlMs <= 0) {
    throw ArgumentError.value(ttl, 'ttl', 'Value must be positive.');
  }

  return MpNode(
    'lazyChunk',
    props: <String, Object?>{
      'bucket': lazyCacheBucket(bucket),
      if (cacheKeyPrefix != null)
        'cacheKeyPrefix': lazyCacheKey(cacheKeyPrefix, 'cacheKeyPrefix'),
      if (cursorState != null)
        'cursorState': lazyStateKey(cursorState, 'cursorState'),
      if (empty != null) 'empty': empty,
      if (end != null) 'end': end,
      if (error != null) 'error': error,
      if (hasMoreState != null)
        'hasMoreState': lazyStateKey(hasMoreState, 'hasMoreState'),
      'id': requiredWidgetString(id, 'id'),
      'initialActions': requiredWidgetList(initialActions, 'initialActions'),
      'itemTemplate': itemTemplate,
      'itemsState': lazyStateKey(itemsState, 'itemsState'),
      if (loadingMore != null) 'loadingMore': loadingMore,
      'loadMoreActions': requiredWidgetList(loadMoreActions, 'loadMoreActions'),
      if (loadMore != null) 'loadMore': loadMore,
      'once': once,
      if (placeholder != null) 'placeholder': placeholder,
      'refreshIfCached': refreshIfCached,
      'retry': retry,
      'retryDelayMs': retryDelayMs,
      if (statusState != null)
        'statusState': lazyStateKey(statusState, 'statusState'),
      if (ttlMs != null) 'ttlMs': ttlMs,
    },
  );
}

MpAction buildLazyChunkLoadMoreAction({required String id}) => MpAction(
  'lazy.chunk.loadMore',
  props: <String, Object?>{'id': requiredWidgetString(id, 'id')},
);

String lazyCacheBucket(String value) {
  final bucket = requiredWidgetString(value, 'bucket');
  if (!_lazyCacheBuckets.contains(bucket)) {
    throw ArgumentError.value(
      value,
      'bucket',
      'Bucket must be one of: ${_lazyCacheBuckets.join(', ')}.',
    );
  }
  return bucket;
}

String lazyCacheKey(String value, String name) {
  final key = requiredWidgetString(value, name);
  if (_unsafeCacheKeyPattern.hasMatch(key)) {
    throw ArgumentError.value(
      value,
      name,
      'Cache key cannot contain path traversal, separators, or file path markers.',
    );
  }
  return key;
}

String lazyStateKey(String value, String name) {
  final key = requiredWidgetString(value, name);
  if (!_stateKeyPattern.hasMatch(key)) {
    throw ArgumentError.value(
      value,
      name,
      'State key must be a safe lowercase dot path.',
    );
  }
  for (final segment in key.split('.')) {
    final compact = segment.replaceAll('_', '').toLowerCase();
    if (_blockedStateSegments.contains(compact)) {
      throw ArgumentError.value(
        value,
        name,
        'State key cannot contain secret-like segments.',
      );
    }
  }
  return key;
}
