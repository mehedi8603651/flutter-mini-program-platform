import '../../core/authoring_validation.dart';
import '../../core/mp_node.dart';
import '../../core/value_normalization.dart';

MpNode buildBackendBuilderNode({
  required String requestId,
  required String endpoint,
  String method = 'GET',
  Map<String, Object?> body = const <String, Object?>{},
  int? cacheTtlSeconds,
  bool forceRefresh = false,
  MpNode? loading,
  MpNode? error,
  MpNode? empty,
  MpNode? child,
  MpNode? itemTemplate,
  String? itemsPath,
}) => MpNode(
  'backendBuilder',
  props: <String, Object?>{
    'requestId': requiredAuthoringString(requestId, 'requestId'),
    'endpoint': requiredAuthoringString(endpoint, 'endpoint'),
    'method': requiredAuthoringString(method, 'method'),
    if (body.isNotEmpty) 'body': body,
    if (cacheTtlSeconds != null)
      'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
    if (forceRefresh) 'forceRefresh': true,
    if (loading != null) 'loading': loading,
    if (error != null) 'error': error,
    if (empty != null) 'empty': empty,
    if (child != null) 'child': child,
    if (itemTemplate != null) 'itemTemplate': itemTemplate,
    if (itemsPath != null)
      'itemsPath': requiredAuthoringString(itemsPath, 'itemsPath'),
  },
);

MpNode buildPagedBackendBuilderNode({
  required String requestId,
  required String endpoint,
  required MpNode itemTemplate,
  int limit = 20,
  String? initialCursor,
  String cursorParam = 'cursor',
  String limitParam = 'limit',
  String itemsPath = 'items',
  String nextCursorPath = 'nextCursor',
  String hasMorePath = 'hasMore',
  int? cacheTtlSeconds,
  bool forceRefresh = false,
  MpNode? loading,
  MpNode? loadingMore,
  MpNode? error,
  MpNode? empty,
  MpNode? end,
  MpNode? loadMore,
}) => MpNode(
  'pagedBackendBuilder',
  props: <String, Object?>{
    'requestId': requiredAuthoringString(requestId, 'requestId'),
    'endpoint': requiredAuthoringString(endpoint, 'endpoint'),
    'itemTemplate': itemTemplate,
    'limit': positiveInt(limit, 'limit'),
    if (initialCursor != null)
      'initialCursor': requiredAuthoringString(initialCursor, 'initialCursor'),
    'cursorParam': requiredAuthoringString(cursorParam, 'cursorParam'),
    'limitParam': requiredAuthoringString(limitParam, 'limitParam'),
    'itemsPath': requiredAuthoringString(itemsPath, 'itemsPath'),
    'nextCursorPath': requiredAuthoringString(nextCursorPath, 'nextCursorPath'),
    'hasMorePath': requiredAuthoringString(hasMorePath, 'hasMorePath'),
    if (cacheTtlSeconds != null)
      'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
    if (forceRefresh) 'forceRefresh': true,
    if (loading != null) 'loading': loading,
    if (loadingMore != null) 'loadingMore': loadingMore,
    if (error != null) 'error': error,
    if (empty != null) 'empty': empty,
    if (end != null) 'end': end,
    if (loadMore != null) 'loadMore': loadMore,
  },
);
