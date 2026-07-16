part of '../../mini_program_backend_connector.dart';

abstract final class MiniProgramBackendHttpHeaders {
  static const String appId = 'x-mini-program-app-id';
  static const String hostApp = 'x-mini-program-host-app';
  static const String hostVersion = 'x-mini-program-host-version';
  static const String sdkVersion = 'x-mini-program-sdk-version';
  static const String platform = 'x-mini-program-platform';
  static const String locale = 'x-mini-program-locale';
}

extension _EndpointRoutingHeaders
    on EndpointRoutingMiniProgramBackendConnector {
  Map<String, String> _requestHeaders(
    String appId,
    MiniProgramBackendEndpoint backend,
    Map<String, String> requestHeaders,
  ) {
    final headers = <String, String>{
      'accept': 'application/json',
      MiniProgramBackendHttpHeaders.appId: appId,
      MiniProgramBackendHttpHeaders.hostApp: _deliveryContext.hostApp,
      MiniProgramBackendHttpHeaders.hostVersion: _deliveryContext.hostVersion,
      MiniProgramBackendHttpHeaders.sdkVersion: _deliveryContext.sdkVersion,
      if (_deliveryContext.platform?.trim().isNotEmpty == true)
        MiniProgramBackendHttpHeaders.platform: _deliveryContext.platform!
            .trim(),
      if (_deliveryContext.locale?.trim().isNotEmpty == true)
        MiniProgramBackendHttpHeaders.locale: _deliveryContext.locale!.trim(),
      ...backend.headers,
      ...requestHeaders,
    };
    return headers;
  }
}
