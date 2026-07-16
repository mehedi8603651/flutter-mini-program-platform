part of '../../mini_program_backend_connector.dart';

extension _EndpointRoutingMemoryCache
    on EndpointRoutingMiniProgramBackendConnector {
  String _cacheKey({
    required String appId,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
  }) {
    String? authHeader;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        authHeader = entry.value;
        break;
      }
    }
    return '$appId::$method::${uri.toString()}::auth=${authHeader ?? ''}';
  }
}

extension on MiniProgramBackendResult {
  MiniProgramBackendResult copyWith({bool? fromCache}) {
    return MiniProgramBackendResult(
      status: status,
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      statusCode: statusCode,
      message: message,
      errorCode: errorCode,
      data: data,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class _CachedBackendResult {
  const _CachedBackendResult({required this.result, required this.expiresAt});

  final MiniProgramBackendResult result;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
