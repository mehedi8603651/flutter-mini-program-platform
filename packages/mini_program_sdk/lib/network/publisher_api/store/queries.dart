part of '../../mini_program_backend_store.dart';

typedef MiniProgramBackendRequestInterceptor =
    Future<MiniProgramBackendRequest> Function(MiniProgramBackendRequest);

enum MiniProgramBackendSnapshotStatus { idle, loading, success, failed }

@immutable
class MiniProgramBackendQuery {
  const MiniProgramBackendQuery({
    required this.requestId,
    required this.endpoint,
    this.method = 'GET',
    this.body = const <String, dynamic>{},
    this.cacheTtl,
    this.forceRefresh = false,
  });

  final String requestId;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final Duration? cacheTtl;
  final bool forceRefresh;

  MiniProgramBackendRequest toRequest({required String miniProgramId}) {
    final ttl = cacheTtl;
    return MiniProgramBackendRequest(
      miniProgramId: miniProgramId,
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      body: body,
      cachePolicy: ttl == null
          ? const MiniProgramBackendCachePolicy.noCache()
          : MiniProgramBackendCachePolicy(ttl: ttl),
      forceRefresh: forceRefresh,
    );
  }
}

@immutable
class MiniProgramPagedBackendQuery {
  const MiniProgramPagedBackendQuery({
    required this.requestId,
    required this.endpoint,
    this.limit = 20,
    this.initialCursor,
    this.cursorParam = 'cursor',
    this.limitParam = 'limit',
    this.itemsPath = 'items',
    this.nextCursorPath = 'nextCursor',
    this.hasMorePath = 'hasMore',
    this.cacheTtl,
    this.forceRefresh = false,
  });

  final String requestId;
  final String endpoint;
  final int limit;
  final String? initialCursor;
  final String cursorParam;
  final String limitParam;
  final String itemsPath;
  final String nextCursorPath;
  final String hasMorePath;
  final Duration? cacheTtl;
  final bool forceRefresh;

  MiniProgramBackendRequest toRequest({
    required String miniProgramId,
    Object? cursor,
  }) {
    final ttl = cacheTtl;
    return MiniProgramBackendRequest(
      miniProgramId: miniProgramId,
      requestId: requestId,
      endpoint: _endpointWithPageParams(cursor: cursor),
      method: 'GET',
      cachePolicy: ttl == null
          ? const MiniProgramBackendCachePolicy.noCache()
          : MiniProgramBackendCachePolicy(ttl: ttl),
      forceRefresh: forceRefresh,
    );
  }

  String _endpointWithPageParams({Object? cursor}) {
    final parsed = Uri.parse(endpoint);
    final params = <String, String>{
      ...parsed.queryParameters,
      limitParam: limit.toString(),
    };
    final cursorValue = cursor?.toString().trim();
    if (cursorValue != null && cursorValue.isNotEmpty) {
      params[cursorParam] = cursorValue;
    }
    return parsed.replace(queryParameters: params).toString();
  }
}
