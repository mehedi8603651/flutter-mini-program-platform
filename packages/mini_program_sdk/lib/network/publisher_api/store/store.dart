part of '../../mini_program_backend_store.dart';

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
    return _trackQueryFuture(requestId, future);
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
    return _trackPagedFuture(requestId, future);
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
    return _trackPagedFuture(requestId, future);
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
    return _buildBindingData();
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
