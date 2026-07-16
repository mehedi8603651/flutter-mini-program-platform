part of '../../mini_program_backend_connector.dart';

extension _EndpointRoutingValidation
    on EndpointRoutingMiniProgramBackendConnector {
  String _normalizeMethod(String rawMethod) {
    final method = rawMethod.trim().toUpperCase();
    return method.isEmpty ? 'GET' : method;
  }

  String? _normalizeRelativeEndpoint(String rawEndpoint) {
    final endpoint = rawEndpoint.trim();
    if (endpoint.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(endpoint);
    if (parsed == null || parsed.hasScheme || parsed.hasAuthority) {
      return null;
    }
    final normalized = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final segments = Uri.parse(normalized).pathSegments;
    if (segments.any((segment) => segment == '..')) {
      return null;
    }
    return normalized;
  }

  Uri _resolve(Uri baseUri, String relativeEndpoint) {
    final baseUrl = baseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBaseUrl).resolve(relativeEndpoint);
  }

  Map<String, String> _normalizeRequestHeaders(Map<String, String> headers) {
    final normalized = <String, String>{};
    for (final entry in headers.entries) {
      final name = entry.key.trim();
      final value = entry.value.trim();
      if (name.isEmpty || value.isEmpty) {
        continue;
      }
      normalized[name] = value;
    }
    return normalized;
  }
}

Map<String, MiniProgramBackendEndpoint> _normalizeBackends(
  Map<String, MiniProgramBackendEndpoint> backends,
) {
  final normalized = <String, MiniProgramBackendEndpoint>{};
  for (final entry in backends.entries) {
    final appId = entry.key.trim();
    if (appId.isEmpty) {
      throw ArgumentError.value(entry.key, 'backends', 'appId is blank.');
    }
    if (!entry.value.baseUri.hasScheme || entry.value.baseUri.host.isEmpty) {
      throw ArgumentError.value(
        entry.value.baseUri,
        'baseUri',
        'Mini-program backend baseUri must be absolute.',
      );
    }
    normalized[appId] = entry.value;
  }
  return normalized;
}
