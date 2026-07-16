part of '../../http_mini_program_source.dart';

typedef ManifestRequestQueryParametersBuilder =
    Map<String, String> Function(String miniProgramId);

/// HTTP-backed source that loads manifests and screen JSON from static
/// artifact paths.
class HttpMiniProgramSource
    implements
        DisposableMiniProgramSource,
        MiniProgramJsonAssetSource,
        MiniProgramPublisherBackendContractSource,
        MiniProgramDeliveryContextProvider {
  HttpMiniProgramSource({
    required this.apiBaseUri,
    this.manifestRequestQueryParametersBuilder,
    this.headers = const <String, String>{},
    this.requestTimeout = const Duration(seconds: 5),
    this.enableLocalLoopbackFallback = true,
    this.deliveryContext,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  factory HttpMiniProgramSource.fromDeliveryContext({
    required Uri apiBaseUri,
    required MiniProgramDeliveryContext deliveryContext,
    Map<String, String> headers = const <String, String>{},
    Duration requestTimeout = const Duration(seconds: 5),
    bool enableLocalLoopbackFallback = true,
    http.Client? client,
  }) {
    return HttpMiniProgramSource(
      apiBaseUri: apiBaseUri,
      manifestRequestQueryParametersBuilder: (_) =>
          deliveryContext.toQueryParameters(),
      headers: headers,
      requestTimeout: requestTimeout,
      enableLocalLoopbackFallback: enableLocalLoopbackFallback,
      deliveryContext: deliveryContext,
      client: client,
    );
  }

  final Uri apiBaseUri;
  final ManifestRequestQueryParametersBuilder?
  manifestRequestQueryParametersBuilder;
  final Map<String, String> headers;
  final Duration requestTimeout;
  final bool enableLocalLoopbackFallback;
  @override
  final MiniProgramDeliveryContext? deliveryContext;
  final http.Client _client;
  final bool _ownsClient;

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    final queryParameters = manifestRequestQueryParametersBuilder?.call(
      miniProgramId,
    );
    final manifestJson = await _loadJsonObject(
      _resolve(
        'artifacts/$miniProgramId/latest.json',
        queryParameters: queryParameters,
      ),
      resourceLabel: 'manifest',
    );
    return MiniProgramManifest.fromJson(manifestJson);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return _loadJsonObject(
      _resolve('artifacts/$miniProgramId/$version/screens/$screenId.json'),
      resourceLabel: 'screen',
    );
  }

  @override
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) {
    return _loadBytes(
      _resolve('artifacts/$miniProgramId/$version/assets/$assetPath'),
      resourceLabel: 'JSON data asset',
    );
  }

  @override
  Future<MiniProgramPublisherBackendContract?> loadPublisherBackendContract({
    required String miniProgramId,
    required String version,
  }) {
    return _loadPublisherBackendContract(
      miniProgramId: miniProgramId,
      version: version,
    );
  }
}
