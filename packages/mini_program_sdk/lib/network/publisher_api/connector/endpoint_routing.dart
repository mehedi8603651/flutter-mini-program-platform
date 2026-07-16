part of '../../mini_program_backend_connector.dart';

class EndpointRoutingMiniProgramBackendConnector
    implements DisposableMiniProgramBackendConnector {
  EndpointRoutingMiniProgramBackendConnector({
    required Map<String, MiniProgramBackendEndpoint> backends,
    required MiniProgramDeliveryContext deliveryContext,
    MiniProgramBackendHttpClientFactory? clientFactory,
  }) : _backends = Map.unmodifiable(_normalizeBackends(backends)),
       _deliveryContext = deliveryContext,
       _clientFactory = clientFactory ?? http.Client.new;

  final Map<String, MiniProgramBackendEndpoint> _backends;
  final MiniProgramDeliveryContext _deliveryContext;
  final MiniProgramBackendHttpClientFactory _clientFactory;
  final Map<String, _CachedBackendResult> _cache =
      <String, _CachedBackendResult>{};

  http.Client? _client;
  bool _disposed = false;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    if (_disposed) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: request.endpoint,
        method: request.method,
        message: 'Mini-program backend connector has been disposed.',
        errorCode: 'publisher_backend_disposed',
      );
    }

    final appId = request.miniProgramId.trim();
    final backend = _backends[appId];
    if (backend == null) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: request.endpoint,
        method: request.method,
        message: 'No Publisher API is configured for mini-program "$appId".',
        errorCode: 'publisher_backend_not_configured',
      );
    }

    final method = _normalizeMethod(request.method);
    final normalizedEndpoint = _normalizeRelativeEndpoint(request.endpoint);
    if (normalizedEndpoint == null) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: request.endpoint,
        method: method,
        message:
            'Mini-program backend endpoint must be a relative path, for example "home/bootstrap".',
        errorCode: 'invalid_backend_endpoint',
      );
    }

    final uri = _resolve(backend.baseUri, normalizedEndpoint);
    final safeHeaders = _normalizeRequestHeaders(request.headers);
    final cacheKey = _cacheKey(
      appId: appId,
      method: method,
      uri: uri,
      headers: safeHeaders,
    );
    if (method == 'GET' &&
        request.cachePolicy.isEnabled &&
        !request.forceRefresh) {
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.result.copyWith(fromCache: true);
      }
    }

    late final http.Response response;
    try {
      response = await _loadResponse(
        backend: backend,
        uri: uri,
        method: method,
        body: request.body,
        headers: _requestHeaders(appId, backend, safeHeaders),
      );
    } on TimeoutException {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: normalizedEndpoint,
        method: method,
        message: 'Timed out while calling the mini-program Publisher API.',
        errorCode: 'publisher_backend_timeout',
        data: <String, dynamic>{
          'requestTimeoutMs': backend.requestTimeout.inMilliseconds,
        },
      );
    } catch (error) {
      return MiniProgramBackendResult.failed(
        requestId: request.requestId,
        endpoint: normalizedEndpoint,
        method: method,
        message: 'Failed to reach the mini-program Publisher API.',
        errorCode: 'publisher_backend_unreachable',
        data: <String, dynamic>{'transportError': error.toString()},
      );
    }

    final result = _toResult(
      request: request,
      endpoint: normalizedEndpoint,
      method: method,
      response: response,
    );

    if (result.isSuccess && method == 'GET' && request.cachePolicy.isEnabled) {
      _cache[cacheKey] = _CachedBackendResult(
        result: result,
        expiresAt: DateTime.now().add(request.cachePolicy.ttl!),
      );
    }

    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _cache.clear();
    _client?.close();
    _client = null;
  }
}
