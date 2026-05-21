import '../network/mini_program_backend_connector.dart';

/// SDK-local Stac action model for publisher-owned backend calls.
class SdkMiniProgramBackendAction {
  const SdkMiniProgramBackendAction({
    required this.endpoint,
    this.requestId,
    this.method = 'GET',
    this.body = const <String, dynamic>{},
    this.cacheTtlSeconds,
  });

  static const String stacActionType = 'miniProgramBackend';

  final String endpoint;
  final String? requestId;
  final String method;
  final Map<String, dynamic> body;
  final int? cacheTtlSeconds;

  factory SdkMiniProgramBackendAction.fromJson(Map<String, dynamic> json) {
    final actionType = json['actionType'];
    if (actionType != stacActionType) {
      throw FormatException(
        'Expected actionType "$stacActionType", got "$actionType".',
      );
    }

    final endpoint = json['endpoint'];
    if (endpoint is! String || endpoint.trim().isEmpty) {
      throw const FormatException(
        'Mini-program backend action JSON must contain a non-empty "endpoint" string.',
      );
    }

    final requestId = json['requestId'];
    if (requestId != null && requestId is! String) {
      throw const FormatException(
        '"requestId" must be a string when provided.',
      );
    }

    final method = json['method'];
    if (method != null && method is! String) {
      throw const FormatException('"method" must be a string when provided.');
    }

    final body = json['body'];
    if (body != null && body is! Map) {
      throw const FormatException('"body" must be a JSON object.');
    }

    final cacheTtlSeconds = json['cacheTtlSeconds'];
    if (cacheTtlSeconds != null && cacheTtlSeconds is! int) {
      throw const FormatException(
        '"cacheTtlSeconds" must be an integer when provided.',
      );
    }

    return SdkMiniProgramBackendAction(
      endpoint: endpoint,
      requestId: requestId as String?,
      method: method as String? ?? 'GET',
      body: body == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(body as Map),
      cacheTtlSeconds: cacheTtlSeconds as int?,
    );
  }

  MiniProgramBackendRequest toRequest({required String miniProgramId}) {
    final ttl = cacheTtlSeconds;
    return MiniProgramBackendRequest(
      miniProgramId: miniProgramId,
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      body: body,
      cachePolicy: ttl == null
          ? const MiniProgramBackendCachePolicy.noCache()
          : MiniProgramBackendCachePolicy(ttl: Duration(seconds: ttl)),
    );
  }
}
