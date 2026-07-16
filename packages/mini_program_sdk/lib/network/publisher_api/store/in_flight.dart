part of '../../mini_program_backend_store.dart';

extension _MiniProgramBackendInFlight on MiniProgramBackendStore {
  Future<MiniProgramBackendSnapshot> _trackQueryFuture(
    String requestId,
    Future<MiniProgramBackendSnapshot> future,
  ) {
    _inFlight[requestId] = future;
    future.whenComplete(() {
      if (identical(_inFlight[requestId], future)) {
        _inFlight.remove(requestId);
      }
    });
    return future;
  }

  Future<MiniProgramPagedBackendSnapshot> _trackPagedFuture(
    String requestId,
    Future<MiniProgramPagedBackendSnapshot> future,
  ) {
    _pagedInFlight[requestId] = future;
    future.whenComplete(() {
      if (identical(_pagedInFlight[requestId], future)) {
        _pagedInFlight.remove(requestId);
      }
    });
    return future;
  }
}
