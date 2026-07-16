import '../../core/mp_action.dart';
import '../../core/mp_node.dart';
import 'lazy_node_builders.dart';

/// Authoring helpers for lazy-loading Mp sections.
final class MpLazy {
  /// Creates lazy authoring helpers.
  const MpLazy();

  /// Loads a section on first mount, with optional cache hydration.
  MpNode section({
    required String id,
    required MpNode child,
    List<MpAction> actions = const <MpAction>[],
    MpNode? placeholder,
    MpNode? error,
    bool once = true,
    String? statusState,
    String? cacheKey,
    String bucket = 'data',
    String? targetState,
    Duration? ttl,
    bool refreshIfCached = false,
    int retry = 0,
    Duration retryDelay = const Duration(milliseconds: 300),
  }) => buildLazySectionNode(
    id: id,
    child: child,
    actions: actions,
    placeholder: placeholder,
    error: error,
    once: once,
    statusState: statusState,
    cacheKey: cacheKey,
    bucket: bucket,
    targetState: targetState,
    ttl: ttl,
    refreshIfCached: refreshIfCached,
    retry: retry,
    retryDelay: retryDelay,
  );

  /// Loads repeated backend data in chunks, with manual load-more support.
  MpNode chunk({
    required String id,
    required MpNode itemTemplate,
    required List<MpAction> initialActions,
    required List<MpAction> loadMoreActions,
    required String itemsState,
    String? cursorState,
    String? hasMoreState,
    String? statusState,
    String? cacheKeyPrefix,
    String bucket = 'data',
    MpNode? placeholder,
    MpNode? empty,
    MpNode? error,
    MpNode? loadingMore,
    MpNode? loadMore,
    MpNode? end,
    bool once = true,
    bool refreshIfCached = false,
    Duration? ttl,
    int retry = 0,
    Duration retryDelay = const Duration(milliseconds: 300),
  }) => buildLazyChunkNode(
    id: id,
    itemTemplate: itemTemplate,
    initialActions: initialActions,
    loadMoreActions: loadMoreActions,
    itemsState: itemsState,
    cursorState: cursorState,
    hasMoreState: hasMoreState,
    statusState: statusState,
    cacheKeyPrefix: cacheKeyPrefix,
    bucket: bucket,
    placeholder: placeholder,
    empty: empty,
    error: error,
    loadingMore: loadingMore,
    loadMore: loadMore,
    end: end,
    once: once,
    refreshIfCached: refreshIfCached,
    ttl: ttl,
    retry: retry,
    retryDelay: retryDelay,
  );

  /// Triggers a rendered lazy chunk to load the next chunk.
  MpAction loadMore({required String id}) =>
      buildLazyChunkLoadMoreAction(id: id);
}
