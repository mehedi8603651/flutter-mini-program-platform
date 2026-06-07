import 'mp_action.dart';
import 'mp_node.dart';
import 'widgets/lazy_widgets.dart';

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
}
