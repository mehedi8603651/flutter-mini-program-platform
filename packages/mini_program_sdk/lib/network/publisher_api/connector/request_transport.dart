part of '../../mini_program_backend_connector.dart';

extension _EndpointRoutingTransport
    on EndpointRoutingMiniProgramBackendConnector {
  http.Client get _resolvedClient => _client ??= _clientFactory();

  Future<http.Response> _loadResponse({
    required MiniProgramBackendEndpoint backend,
    required Uri uri,
    required String method,
    required Map<String, dynamic> body,
    required Map<String, String> headers,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final candidateUri in _candidateUris(uri, backend)) {
      try {
        return await _loadSingleResponse(
          backend: backend,
          uri: candidateUri,
          method: method,
          body: body,
          headers: headers,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw StateError('No mini-program backend request URI candidates found.');
  }

  Future<http.Response> _loadSingleResponse({
    required MiniProgramBackendEndpoint backend,
    required Uri uri,
    required String method,
    required Map<String, dynamic> body,
    required Map<String, String> headers,
  }) {
    final client = _resolvedClient;
    final effectiveHeaders = method == 'GET'
        ? headers
        : <String, String>{'content-type': 'application/json', ...headers};
    final encodedBody = method == 'GET' ? null : jsonEncode(body);

    final future = switch (method) {
      'GET' => client.get(uri, headers: effectiveHeaders),
      'POST' => client.post(uri, headers: effectiveHeaders, body: encodedBody),
      'PUT' => client.put(uri, headers: effectiveHeaders, body: encodedBody),
      'PATCH' => client.patch(
        uri,
        headers: effectiveHeaders,
        body: encodedBody,
      ),
      'DELETE' => client.delete(
        uri,
        headers: effectiveHeaders,
        body: encodedBody,
      ),
      _ => client.post(uri, headers: effectiveHeaders, body: encodedBody),
    };

    return future.timeout(backend.requestTimeout);
  }

  List<Uri> _candidateUris(Uri primaryUri, MiniProgramBackendEndpoint backend) {
    if (!backend.enableLocalLoopbackFallback || primaryUri.scheme != 'http') {
      return <Uri>[primaryUri];
    }

    final hosts = <String>[primaryUri.host];
    if (primaryUri.host == '10.0.2.2') {
      hosts.add('127.0.0.1');
    } else if (primaryUri.host == '127.0.0.1' ||
        primaryUri.host == 'localhost') {
      hosts.add('10.0.2.2');
    }

    return hosts
        .toSet()
        .map(
          (host) => host == primaryUri.host
              ? primaryUri
              : primaryUri.replace(host: host),
        )
        .toList();
  }
}
