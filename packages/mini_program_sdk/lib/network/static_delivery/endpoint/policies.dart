part of '../../mini_program_endpoint.dart';

extension _EndpointRoutingPolicies on EndpointRoutingMiniProgramSource {
  MiniProgramEndpoint _endpointFor(String miniProgramId) {
    final normalizedAppId = _normalizeAppId(miniProgramId);
    final endpoint = _endpoints[normalizedAppId];
    if (endpoint == null) {
      throw MiniProgramSourceException(
        message:
            'No MiniProgramEndpoint is configured for appId "$normalizedAppId".',
        errorCode: MiniProgramErrorCodes.endpointNotConfigured,
        details: <String, dynamic>{'miniProgramId': normalizedAppId},
      );
    }
    return endpoint;
  }
}
