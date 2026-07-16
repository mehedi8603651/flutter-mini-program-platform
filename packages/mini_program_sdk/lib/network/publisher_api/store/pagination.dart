part of '../../mini_program_backend_store.dart';

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
