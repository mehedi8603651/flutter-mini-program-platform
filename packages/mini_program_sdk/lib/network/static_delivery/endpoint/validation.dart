part of '../../mini_program_endpoint.dart';

Map<String, MiniProgramEndpoint> _normalizeEndpoints(
  Map<String, MiniProgramEndpoint> endpoints,
) {
  final normalized = <String, MiniProgramEndpoint>{};
  for (final entry in endpoints.entries) {
    final appId = _normalizeAppId(entry.key);
    if (normalized.containsKey(appId)) {
      throw ArgumentError.value(
        endpoints,
        'endpoints',
        'Duplicate mini-program endpoint for appId "$appId".',
      );
    }
    normalized[appId] = entry.value;
  }
  return normalized;
}

String _normalizeAppId(String rawAppId) {
  final appId = rawAppId.trim();
  if (appId.isEmpty) {
    throw ArgumentError.value(rawAppId, 'appId', 'appId must not be blank.');
  }
  return appId;
}
