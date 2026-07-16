part of '../../mini_program_endpoint.dart';

/// Routes manifest and screen requests to per-app delivery endpoints.
class EndpointRoutingMiniProgramSource
    implements
        DisposableMiniProgramSource,
        MiniProgramCachePolicyProvider,
        MiniProgramLiveStatePolicyProvider,
        MiniProgramPublisherApiPolicyProvider,
        MiniProgramLocationPolicyProvider,
        MiniProgramDeliveryContextProvider,
        MiniProgramPublisherBackendContractSource,
        MiniProgramJsonAssetSource {
  EndpointRoutingMiniProgramSource({
    required Map<String, MiniProgramEndpoint> endpoints,
    required MiniProgramDeliveryContext deliveryContext,
    MiniProgramEndpointSourceFactory? sourceFactory,
  }) : _endpoints = Map.unmodifiable(_normalizeEndpoints(endpoints)),
       _deliveryContext = deliveryContext,
       _sourceFactory = sourceFactory ?? _defaultSourceFactory {
    if (_endpoints.isEmpty) {
      throw ArgumentError.value(
        endpoints,
        'endpoints',
        'At least one mini-program endpoint must be configured.',
      );
    }
  }

  final Map<String, MiniProgramEndpoint> _endpoints;
  final MiniProgramDeliveryContext _deliveryContext;
  final MiniProgramEndpointSourceFactory _sourceFactory;
  final Map<String, MiniProgramSource> _sources = <String, MiniProgramSource>{};

  @override
  MiniProgramDeliveryContext get deliveryContext => _deliveryContext;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) {
    return _sourceFor(miniProgramId).loadManifest(miniProgramId);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    return _sourceFor(miniProgramId).loadScreen(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    );
  }

  @override
  Future<List<int>> loadJsonAsset({
    required String miniProgramId,
    required String version,
    required String assetPath,
  }) {
    return _loadRoutedJsonAsset(
      miniProgramId: miniProgramId,
      version: version,
      assetPath: assetPath,
    );
  }

  @override
  Future<MiniProgramPublisherBackendContract?> loadPublisherBackendContract({
    required String miniProgramId,
    required String version,
  }) {
    return _loadRoutedPublisherBackendContract(
      miniProgramId: miniProgramId,
      version: version,
    );
  }

  @override
  void dispose() {
    for (final source in _sources.values) {
      if (source is DisposableMiniProgramSource) {
        source.dispose();
      }
    }
    _sources.clear();
  }

  @override
  MiniProgramCachePolicy cachePolicyFor(String miniProgramId) {
    return _endpointFor(miniProgramId).cachePolicy;
  }

  @override
  MiniProgramLiveStatePolicy liveStatePolicyFor(String miniProgramId) {
    return _endpointFor(miniProgramId).liveStatePolicy;
  }

  @override
  MiniProgramPublisherApiPolicy publisherApiPolicyFor(String miniProgramId) {
    return _endpointFor(miniProgramId).publisherApiPolicy;
  }

  @override
  MiniProgramLocationPolicy locationPolicyFor(String miniProgramId) {
    return _endpointFor(miniProgramId).locationPolicy;
  }
}
