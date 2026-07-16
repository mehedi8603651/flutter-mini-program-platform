part of '../../mini_program_backend_store.dart';

extension _MiniProgramBackendExecution on MiniProgramBackendStore {
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
              'Publisher API is not configured for mini-program "$miniProgramId".',
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
              'Publisher API is not configured for mini-program "$miniProgramId".',
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
}
