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

class MiniProgramBackendStore extends ChangeNotifier {
  final Map<String, MiniProgramBackendSnapshot> _snapshots =
      <String, MiniProgramBackendSnapshot>{};
  final Map<String, Future<MiniProgramBackendSnapshot>> _inFlight =
      <String, Future<MiniProgramBackendSnapshot>>{};
  int _generation = 0;
  bool _disposed = false;

  MiniProgramBackendSnapshot snapshot(String requestId) {
    return _snapshots[requestId] ?? MiniProgramBackendSnapshot.idle(requestId);
  }

  bool hasTerminalSnapshot(String requestId) {
    final snapshot = _snapshots[requestId];
    return snapshot != null && (snapshot.isSuccess || snapshot.isFailure);
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

  void clear() {
    _generation += 1;
    _snapshots.clear();
    _inFlight.clear();
    _notifyIfActive();
  }

  Map<String, dynamic> toBindingData() {
    return _snapshots.map(
      (key, value) => MapEntry<String, dynamic>(key, value.toBindingData()),
    );
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
    super.dispose();
  }
}
