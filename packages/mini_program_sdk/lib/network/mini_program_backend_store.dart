import 'package:flutter/foundation.dart';

import 'mini_program_backend_connector.dart';

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

@immutable
class MiniProgramBackendSnapshot {
  const MiniProgramBackendSnapshot({
    required this.requestId,
    required this.status,
    this.endpoint,
    this.method,
    this.statusCode,
    this.message,
    this.errorCode,
    this.data = const <String, dynamic>{},
    this.fromCache = false,
    this.updatedAt,
  });

  factory MiniProgramBackendSnapshot.idle(String requestId) {
    return MiniProgramBackendSnapshot(
      requestId: requestId,
      status: MiniProgramBackendSnapshotStatus.idle,
    );
  }

  factory MiniProgramBackendSnapshot.loading({
    required String requestId,
    required String endpoint,
    required String method,
    MiniProgramBackendSnapshot? previous,
  }) {
    return MiniProgramBackendSnapshot(
      requestId: requestId,
      status: MiniProgramBackendSnapshotStatus.loading,
      endpoint: endpoint,
      method: method,
      data: previous?.data ?? const <String, dynamic>{},
      fromCache: previous?.fromCache ?? false,
      updatedAt: previous?.updatedAt,
    );
  }

  factory MiniProgramBackendSnapshot.fromResult(
    MiniProgramBackendResult result, {
    required String requestId,
    MiniProgramBackendSnapshot? previous,
  }) {
    final isSuccess = result.isSuccess;
    return MiniProgramBackendSnapshot(
      requestId: requestId,
      status: isSuccess
          ? MiniProgramBackendSnapshotStatus.success
          : MiniProgramBackendSnapshotStatus.failed,
      endpoint: result.endpoint,
      method: result.method,
      statusCode: result.statusCode,
      message: result.message,
      errorCode: result.errorCode,
      data: isSuccess ? result.data : previous?.data ?? result.data,
      fromCache: result.fromCache,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  final String requestId;
  final MiniProgramBackendSnapshotStatus status;
  final String? endpoint;
  final String? method;
  final int? statusCode;
  final String? message;
  final String? errorCode;
  final Map<String, dynamic> data;
  final bool fromCache;
  final DateTime? updatedAt;

  bool get isIdle => status == MiniProgramBackendSnapshotStatus.idle;
  bool get isLoading => status == MiniProgramBackendSnapshotStatus.loading;
  bool get isSuccess => status == MiniProgramBackendSnapshotStatus.success;
  bool get isFailure => status == MiniProgramBackendSnapshotStatus.failed;
  bool get hasData => data.isNotEmpty;

  Map<String, dynamic> toBindingData() {
    return <String, dynamic>{
      'requestId': requestId,
      'status': status.name,
      'idle': isIdle,
      'loading': isLoading,
      'success': isSuccess,
      'failed': isFailure,
      'error': isFailure,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (statusCode != null) 'statusCode': statusCode,
      if (message != null) 'message': message,
      if (errorCode != null) 'errorCode': errorCode,
      'data': data,
      'hasData': hasData,
      'fromCache': fromCache,
      if (updatedAt != null) 'updatedAtUtc': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toBindingData();
}

@immutable
class MiniProgramPagedBackendSnapshot {
  const MiniProgramPagedBackendSnapshot({
    required this.requestId,
    required this.status,
    this.endpoint,
    this.method = 'GET',
    this.statusCode,
    this.message,
    this.errorCode,
    this.items = const <Object?>[],
    this.nextCursor,
    this.hasMore = false,
    this.pageCount = 0,
    this.loadingMore = false,
    this.fromCache = false,
    this.updatedAt,
  });

  factory MiniProgramPagedBackendSnapshot.idle(String requestId) {
    return MiniProgramPagedBackendSnapshot(
      requestId: requestId,
      status: MiniProgramBackendSnapshotStatus.idle,
    );
  }

  factory MiniProgramPagedBackendSnapshot.loading({
    required String requestId,
    required String endpoint,
    MiniProgramPagedBackendSnapshot? previous,
    bool loadingMore = false,
  }) {
    return MiniProgramPagedBackendSnapshot(
      requestId: requestId,
      status: MiniProgramBackendSnapshotStatus.loading,
      endpoint: endpoint,
      items: previous?.items ?? const <Object?>[],
      nextCursor: previous?.nextCursor,
      hasMore: previous?.hasMore ?? false,
      pageCount: previous?.pageCount ?? 0,
      loadingMore: loadingMore,
      fromCache: previous?.fromCache ?? false,
      updatedAt: previous?.updatedAt,
    );
  }

  factory MiniProgramPagedBackendSnapshot.fromResult(
    MiniProgramBackendResult result, {
    required String requestId,
    required MiniProgramPagedBackendQuery query,
    required bool append,
    MiniProgramPagedBackendSnapshot? previous,
  }) {
    final isSuccess = result.isSuccess;
    if (!isSuccess) {
      return MiniProgramPagedBackendSnapshot(
        requestId: requestId,
        status: MiniProgramBackendSnapshotStatus.failed,
        endpoint: result.endpoint,
        method: result.method ?? 'GET',
        statusCode: result.statusCode,
        message: result.message,
        errorCode: result.errorCode,
        items: previous?.items ?? const <Object?>[],
        nextCursor: previous?.nextCursor,
        hasMore: previous?.hasMore ?? false,
        pageCount: previous?.pageCount ?? 0,
        fromCache: result.fromCache,
        updatedAt: DateTime.now().toUtc(),
      );
    }

    final pageItems = _readList(result.data, query.itemsPath);
    final items = append
        ? <Object?>[...?previous?.items, ...pageItems]
        : pageItems;
    final nextCursor = _readPath(result.data, query.nextCursorPath);
    final hasMore = _readBool(result.data, query.hasMorePath);
    return MiniProgramPagedBackendSnapshot(
      requestId: requestId,
      status: MiniProgramBackendSnapshotStatus.success,
      endpoint: result.endpoint,
      method: result.method ?? 'GET',
      statusCode: result.statusCode,
      message: result.message,
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      pageCount: (append ? previous?.pageCount ?? 0 : 0) + 1,
      fromCache: result.fromCache,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  final String requestId;
  final MiniProgramBackendSnapshotStatus status;
  final String? endpoint;
  final String method;
  final int? statusCode;
  final String? message;
  final String? errorCode;
  final List<Object?> items;
  final Object? nextCursor;
  final bool hasMore;
  final int pageCount;
  final bool loadingMore;
  final bool fromCache;
  final DateTime? updatedAt;

  bool get isIdle => status == MiniProgramBackendSnapshotStatus.idle;
  bool get isLoading => status == MiniProgramBackendSnapshotStatus.loading;
  bool get isSuccess => status == MiniProgramBackendSnapshotStatus.success;
  bool get isFailure => status == MiniProgramBackendSnapshotStatus.failed;
  bool get hasItems => items.isNotEmpty;

  Map<String, dynamic> toBindingData() {
    return <String, dynamic>{
      'requestId': requestId,
      'status': status.name,
      'idle': isIdle,
      'loading': isLoading && !loadingMore,
      'loadingMore': loadingMore,
      'success': isSuccess,
      'failed': isFailure,
      'error': isFailure,
      if (endpoint != null) 'endpoint': endpoint,
      'method': method,
      if (statusCode != null) 'statusCode': statusCode,
      if (message != null) 'message': message,
      if (errorCode != null) 'errorCode': errorCode,
      'items': items,
      'itemCount': items.length,
      'pageCount': pageCount,
      'hasMore': hasMore,
      'nextCursor': nextCursor,
      'hasData': hasItems,
      'fromCache': fromCache,
      if (updatedAt != null) 'updatedAtUtc': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toBindingData();

  static List<Object?> _readList(Map<String, dynamic> data, String path) {
    final value = _readPath(data, path);
    return value is List ? List<Object?>.from(value) : const <Object?>[];
  }

  static bool _readBool(Map<String, dynamic> data, String path) {
    final value = _readPath(data, path);
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  static Object? _readPath(Object? source, String path) {
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
}

class MiniProgramBackendStore extends ChangeNotifier {
  final Map<String, MiniProgramBackendSnapshot> _snapshots =
      <String, MiniProgramBackendSnapshot>{};
  final Map<String, Future<MiniProgramBackendSnapshot>> _inFlight =
      <String, Future<MiniProgramBackendSnapshot>>{};
  final Map<String, MiniProgramPagedBackendSnapshot> _pagedSnapshots =
      <String, MiniProgramPagedBackendSnapshot>{};
  final Map<String, Future<MiniProgramPagedBackendSnapshot>> _pagedInFlight =
      <String, Future<MiniProgramPagedBackendSnapshot>>{};
  final Map<String, MiniProgramPagedBackendQuery> _pagedQueries =
      <String, MiniProgramPagedBackendQuery>{};
  int _generation = 0;
  bool _disposed = false;

  MiniProgramBackendSnapshot snapshot(String requestId) {
    return _snapshots[requestId] ?? MiniProgramBackendSnapshot.idle(requestId);
  }

  bool hasTerminalSnapshot(String requestId) {
    final snapshot = _snapshots[requestId];
    return snapshot != null && (snapshot.isSuccess || snapshot.isFailure);
  }

  MiniProgramPagedBackendSnapshot pagedSnapshot(String requestId) {
    return _pagedSnapshots[requestId] ??
        MiniProgramPagedBackendSnapshot.idle(requestId);
  }

  Future<MiniProgramBackendSnapshot> runQuery({
    required MiniProgramBackendConnector? connector,
    required String miniProgramId,
    required MiniProgramBackendQuery query,
    MiniProgramBackendRequestInterceptor? requestInterceptor,
  }) {
    final requestId = query.requestId.trim();
    if (requestId.isEmpty) {
      throw ArgumentError.value(query.requestId, 'requestId', 'is blank');
    }

    if (!query.forceRefresh) {
      final inFlight = _inFlight[requestId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = _runQuery(
      connector: connector,
      miniProgramId: miniProgramId,
      query: query,
      requestId: requestId,
      generation: _generation,
      requestInterceptor: requestInterceptor,
    );
    _inFlight[requestId] = future;
    future.whenComplete(() {
      if (identical(_inFlight[requestId], future)) {
        _inFlight.remove(requestId);
      }
    });
    return future;
  }

  Future<MiniProgramPagedBackendSnapshot> runPagedQuery({
    required MiniProgramBackendConnector? connector,
    required String miniProgramId,
    required MiniProgramPagedBackendQuery query,
    MiniProgramBackendRequestInterceptor? requestInterceptor,
  }) {
    final requestId = query.requestId.trim();
    if (requestId.isEmpty) {
      throw ArgumentError.value(query.requestId, 'requestId', 'is blank');
    }

    if (!query.forceRefresh) {
      final inFlight = _pagedInFlight[requestId];
      if (inFlight != null) {
        return inFlight;
      }
    }

    _pagedQueries[requestId] = query;
    final future = _runPagedQuery(
      connector: connector,
      miniProgramId: miniProgramId,
      query: query,
      requestId: requestId,
      generation: _generation,
      append: false,
      cursor: query.initialCursor,
      requestInterceptor: requestInterceptor,
    );
    _pagedInFlight[requestId] = future;
    future.whenComplete(() {
      if (identical(_pagedInFlight[requestId], future)) {
        _pagedInFlight.remove(requestId);
      }
    });
    return future;
  }

  Future<MiniProgramPagedBackendSnapshot> loadMore({
    required MiniProgramBackendConnector? connector,
    required String miniProgramId,
    required MiniProgramPagedBackendQuery query,
    MiniProgramBackendRequestInterceptor? requestInterceptor,
  }) {
    final requestId = query.requestId.trim();
    if (requestId.isEmpty) {
      throw ArgumentError.value(query.requestId, 'requestId', 'is blank');
    }

    final inFlight = _pagedInFlight[requestId];
    if (inFlight != null) {
      return inFlight;
    }

    final previous = pagedSnapshot(requestId);
    if (!previous.hasMore && previous.pageCount > 0) {
      return Future<MiniProgramPagedBackendSnapshot>.value(previous);
    }
    _pagedQueries[requestId] = query;
    final future = _runPagedQuery(
      connector: connector,
      miniProgramId: miniProgramId,
      query: query,
      requestId: requestId,
      generation: _generation,
      append: true,
      cursor: previous.nextCursor,
      requestInterceptor: requestInterceptor,
    );
    _pagedInFlight[requestId] = future;
    future.whenComplete(() {
      if (identical(_pagedInFlight[requestId], future)) {
        _pagedInFlight.remove(requestId);
      }
    });
    return future;
  }

  Future<MiniProgramPagedBackendSnapshot> loadMoreByRequestId({
    required MiniProgramBackendConnector? connector,
    required String miniProgramId,
    required String requestId,
    MiniProgramBackendRequestInterceptor? requestInterceptor,
  }) {
    final trimmedRequestId = requestId.trim();
    if (trimmedRequestId.isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'is blank');
    }
    final query = _pagedQueries[trimmedRequestId];
    if (query == null) {
      final snapshot = MiniProgramPagedBackendSnapshot.fromResult(
        MiniProgramBackendResult.failed(
          requestId: trimmedRequestId,
          endpoint: null,
          method: 'GET',
          message:
              'No paged backend query is registered for request "$trimmedRequestId".',
          errorCode: 'paged_backend_query_not_registered',
        ),
        requestId: trimmedRequestId,
        query: MiniProgramPagedBackendQuery(
          requestId: trimmedRequestId,
          endpoint: 'missing',
        ),
        append: true,
        previous: _pagedSnapshots[trimmedRequestId],
      );
      _pagedSnapshots[trimmedRequestId] = snapshot;
      _notifyIfActive();
      return Future<MiniProgramPagedBackendSnapshot>.value(snapshot);
    }
    return loadMore(
      connector: connector,
      miniProgramId: miniProgramId,
      query: query,
      requestInterceptor: requestInterceptor,
    );
  }

  void clear() {
    _generation += 1;
    _snapshots.clear();
    _inFlight.clear();
    _pagedSnapshots.clear();
    _pagedInFlight.clear();
    _pagedQueries.clear();
    _notifyIfActive();
  }

  Map<String, dynamic> toBindingData() {
    return <String, dynamic>{
      ..._snapshots.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toBindingData()),
      ),
      ..._pagedSnapshots.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toBindingData()),
      ),
    };
  }

  Future<MiniProgramBackendSnapshot> _runQuery({
    required MiniProgramBackendConnector? connector,
    required String miniProgramId,
    required MiniProgramBackendQuery query,
    required String requestId,
    required int generation,
    MiniProgramBackendRequestInterceptor? requestInterceptor,
  }) async {
    final previous = _snapshots[requestId];
    _snapshots[requestId] = MiniProgramBackendSnapshot.loading(
      requestId: requestId,
      endpoint: query.endpoint,
      method: query.method,
      previous: previous,
    );
    _notifyIfActive();

    if (connector == null) {
      final snapshot = MiniProgramBackendSnapshot.fromResult(
        MiniProgramBackendResult.failed(
          requestId: requestId,
          endpoint: query.endpoint,
          method: query.method,
          message:
              'Publisher backend is not configured for mini-program "$miniProgramId".',
          errorCode: 'publisher_backend_not_configured',
        ),
        requestId: requestId,
        previous: previous,
      );
      _snapshots[requestId] = snapshot;
      _notifyIfActive();
      return snapshot;
    }

    var request = query.toRequest(miniProgramId: miniProgramId);
    if (requestInterceptor != null) {
      request = await requestInterceptor(request);
    }
    final result = await connector.call(request);
    if (_disposed || generation != _generation) {
      return _snapshots[requestId] ??
          MiniProgramBackendSnapshot.idle(requestId);
    }
    final snapshot = MiniProgramBackendSnapshot.fromResult(
      result,
      requestId: requestId,
      previous: previous,
    );
    _snapshots[requestId] = snapshot;
    _notifyIfActive();
    return snapshot;
  }

  Future<MiniProgramPagedBackendSnapshot> _runPagedQuery({
    required MiniProgramBackendConnector? connector,
    required String miniProgramId,
    required MiniProgramPagedBackendQuery query,
    required String requestId,
    required int generation,
    required bool append,
    required Object? cursor,
    MiniProgramBackendRequestInterceptor? requestInterceptor,
  }) async {
    final previous = _pagedSnapshots[requestId];
    _pagedSnapshots[requestId] = MiniProgramPagedBackendSnapshot.loading(
      requestId: requestId,
      endpoint: query.endpoint,
      previous: append ? previous : null,
      loadingMore: append,
    );
    _notifyIfActive();

    if (connector == null) {
      final snapshot = MiniProgramPagedBackendSnapshot.fromResult(
        MiniProgramBackendResult.failed(
          requestId: requestId,
          endpoint: query.endpoint,
          method: 'GET',
          message:
              'Publisher backend is not configured for mini-program "$miniProgramId".',
          errorCode: 'publisher_backend_not_configured',
        ),
        requestId: requestId,
        query: query,
        append: append,
        previous: previous,
      );
      _pagedSnapshots[requestId] = snapshot;
      _notifyIfActive();
      return snapshot;
    }

    var request = query.toRequest(miniProgramId: miniProgramId, cursor: cursor);
    if (requestInterceptor != null) {
      request = await requestInterceptor(request);
    }
    final result = await connector.call(request);
    if (_disposed || generation != _generation) {
      return _pagedSnapshots[requestId] ??
          MiniProgramPagedBackendSnapshot.idle(requestId);
    }
    final snapshot = MiniProgramPagedBackendSnapshot.fromResult(
      result,
      requestId: requestId,
      query: query,
      append: append,
      previous: previous,
    );
    _pagedSnapshots[requestId] = snapshot;
    _notifyIfActive();
    return snapshot;
  }

  void _notifyIfActive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _snapshots.clear();
    _inFlight.clear();
    _pagedSnapshots.clear();
    _pagedInFlight.clear();
    _pagedQueries.clear();
    super.dispose();
  }
}
