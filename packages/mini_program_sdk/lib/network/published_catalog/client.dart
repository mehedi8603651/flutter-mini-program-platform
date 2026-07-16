part of '../published_mini_program_catalog_client.dart';

/// HTTP-backed client for the backend discovery catalog.
class PublishedMiniProgramCatalogClient {
  PublishedMiniProgramCatalogClient({
    required this.apiBaseUri,
    this.queryParameters = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 5),
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory PublishedMiniProgramCatalogClient.fromDeliveryContext({
    required Uri apiBaseUri,
    required MiniProgramDeliveryContext deliveryContext,
    Duration requestTimeout = const Duration(seconds: 5),
    http.Client? client,
  }) {
    return PublishedMiniProgramCatalogClient(
      apiBaseUri: apiBaseUri,
      queryParameters: deliveryContext.toQueryParameters(),
      requestTimeout: requestTimeout,
      client: client,
    );
  }

  final Uri apiBaseUri;
  final Map<String, String> queryParameters;
  final Duration requestTimeout;
  final http.Client _client;

  Future<PublishedMiniProgramCatalog> listAvailableMiniPrograms() async {
    final uri = _resolveCatalogUri(
      'discovery/mini-programs.json',
      queryParameters: queryParameters,
    );
    final response = await _loadCatalogResponse(uri);
    return _parseCatalogResponse(uri: uri, response: response);
  }
}
