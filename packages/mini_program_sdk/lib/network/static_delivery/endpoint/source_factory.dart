part of '../../mini_program_endpoint.dart';

extension _EndpointRoutingSourceFactory on EndpointRoutingMiniProgramSource {
  MiniProgramSource _sourceFor(String miniProgramId) {
    final normalizedAppId = _normalizeAppId(miniProgramId);
    final endpoint = _endpointFor(normalizedAppId);
    return _sources.putIfAbsent(
      normalizedAppId,
      () => _sourceFactory(
        appId: normalizedAppId,
        endpoint: endpoint,
        deliveryContext: _deliveryContext,
      ),
    );
  }
}

MiniProgramSource _defaultSourceFactory({
  required String appId,
  required MiniProgramEndpoint endpoint,
  required MiniProgramDeliveryContext deliveryContext,
}) {
  return HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: endpoint.apiBaseUri,
    deliveryContext: deliveryContext,
    headers: endpoint.headers,
    requestTimeout: endpoint.requestTimeout,
    enableLocalLoopbackFallback: endpoint.enableLocalLoopbackFallback,
  );
}
