part of '../../http_mini_program_source.dart';

extension _HttpMiniProgramSourceTransport on HttpMiniProgramSource {
  Future<List<int>> _loadSingleBytes(
    Uri uri, {
    required String resourceLabel,
    required List<Uri> attemptedUris,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: _requestHeaders())
          .timeout(requestTimeout);
    } on TimeoutException {
      throw _TransportSourceException(
        MiniProgramSourceException(
          message:
              'Timed out while loading $resourceLabel from the mini-program backend.',
          errorCode: MiniProgramErrorCodes.backendUnreachable,
          details: <String, dynamic>{
            'uri': uri.toString(),
            'resourceLabel': resourceLabel,
            'requestTimeoutMs': requestTimeout.inMilliseconds,
            'transportError': 'timeout',
            if (attemptedUris.length > 1)
              'attemptedUris': attemptedUris
                  .map((candidateUri) => candidateUri.toString())
                  .toList(),
          },
        ),
      );
    } catch (error) {
      throw _TransportSourceException(
        MiniProgramSourceException(
          message:
              'Failed to reach the mini-program backend while loading $resourceLabel.',
          errorCode: MiniProgramErrorCodes.backendUnreachable,
          details: <String, dynamic>{
            'uri': uri.toString(),
            'resourceLabel': resourceLabel,
            'transportError': error.toString(),
            if (attemptedUris.length > 1)
              'attemptedUris': attemptedUris
                  .map((candidateUri) => candidateUri.toString())
                  .toList(),
          },
        ),
      );
    }

    if (response.statusCode != 200) {
      throw _buildSourceException(
        uri: uri,
        resourceLabel: resourceLabel,
        response: response,
      );
    }

    return response.bodyBytes;
  }

  Map<String, String> _requestHeaders() {
    return <String, String>{...headers};
  }
}
