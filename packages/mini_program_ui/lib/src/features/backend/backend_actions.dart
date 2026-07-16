import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/value_normalization.dart';

/// Publisher API action builders.
final class MpBackendActions {
  /// Creates Publisher API action helpers.
  const MpBackendActions();

  /// Calls a Publisher API endpoint without storing state.
  MpAction call({
    required String endpoint,
    String? requestId,
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int? cacheTtlSeconds,
  }) => MpAction(
    'backend.call',
    props: <String, Object?>{
      'endpoint': requiredAuthoringString(endpoint, 'endpoint'),
      if (requestId != null)
        'requestId': requiredAuthoringString(requestId, 'requestId'),
      'method': requiredAuthoringString(method, 'method'),
      if (body.isNotEmpty) 'body': body,
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
    },
  );

  /// Queries a Publisher API endpoint into SDK backend state.
  MpAction query({
    required String requestId,
    required String endpoint,
    String method = 'GET',
    Map<String, Object?> body = const <String, Object?>{},
    int? cacheTtlSeconds,
    bool forceRefresh = false,
  }) => MpAction(
    'backend.query',
    props: <String, Object?>{
      'requestId': requiredAuthoringString(requestId, 'requestId'),
      'endpoint': requiredAuthoringString(endpoint, 'endpoint'),
      'method': requiredAuthoringString(method, 'method'),
      if (body.isNotEmpty) 'body': body,
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
      if (forceRefresh) 'forceRefresh': true,
    },
  );

  /// Loads the next page for a paged Publisher API query.
  MpAction loadMore({
    required String requestId,
    String? endpoint,
    int limit = 20,
    String? initialCursor,
    String cursorParam = 'cursor',
    String limitParam = 'limit',
    String itemsPath = 'items',
    String nextCursorPath = 'nextCursor',
    String hasMorePath = 'hasMore',
    int? cacheTtlSeconds,
  }) => MpAction(
    'backend.loadMore',
    props: <String, Object?>{
      'requestId': requiredAuthoringString(requestId, 'requestId'),
      if (endpoint != null)
        'endpoint': requiredAuthoringString(endpoint, 'endpoint'),
      'limit': positiveInt(limit, 'limit'),
      if (initialCursor != null)
        'initialCursor': requiredAuthoringString(
          initialCursor,
          'initialCursor',
        ),
      'cursorParam': requiredAuthoringString(cursorParam, 'cursorParam'),
      'limitParam': requiredAuthoringString(limitParam, 'limitParam'),
      'itemsPath': requiredAuthoringString(itemsPath, 'itemsPath'),
      'nextCursorPath': requiredAuthoringString(
        nextCursorPath,
        'nextCursorPath',
      ),
      'hasMorePath': requiredAuthoringString(hasMorePath, 'hasMorePath'),
      if (cacheTtlSeconds != null)
        'cacheTtlSeconds': positiveInt(cacheTtlSeconds, 'cacheTtlSeconds'),
    },
  );
}
