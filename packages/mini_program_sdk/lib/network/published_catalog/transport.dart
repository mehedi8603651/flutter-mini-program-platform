part of '../published_mini_program_catalog_client.dart';

extension _PublishedCatalogTransport on PublishedMiniProgramCatalogClient {
  Uri _resolveCatalogUri(
    String relativePath, {
    Map<String, String>? queryParameters,
  }) {
    final baseUrl = apiBaseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final uri = Uri.parse(normalizedBaseUrl).resolve(relativePath);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: queryParameters);
  }

  Future<http.Response> _loadCatalogResponse(Uri uri) async {
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(requestTimeout);
    } on TimeoutException {
      throw MiniProgramSourceException(
        message:
            'Timed out while loading the mini-program discovery catalog from the backend.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': 'mini_program_catalog',
          'requestTimeoutMs': requestTimeout.inMilliseconds,
          'transportError': 'timeout',
        },
      );
    } catch (error) {
      throw MiniProgramSourceException(
        message:
            'Failed to reach the mini-program backend while loading the discovery catalog.',
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        details: <String, dynamic>{
          'uri': uri.toString(),
          'resourceLabel': 'mini_program_catalog',
          'transportError': error.toString(),
        },
      );
    }

    if (response.statusCode != 200) {
      throw _buildCatalogSourceException(uri: uri, response: response);
    }
    return response;
  }
}
