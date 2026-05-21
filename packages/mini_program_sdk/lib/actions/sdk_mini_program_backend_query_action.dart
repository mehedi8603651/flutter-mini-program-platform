import '../network/mini_program_backend_store.dart';

/// SDK-local Stac action model for querying publisher-owned backend data into
/// mini-program state.
class SdkMiniProgramBackendQueryAction {
  const SdkMiniProgramBackendQueryAction({
    required this.requestId,
    required this.endpoint,
    this.method = 'GET',
    this.body = const <String, dynamic>{},
    this.cacheTtlSeconds,
    this.forceRefresh = false,
  });

  static const String stacActionType = 'miniProgramBackendQuery';

  final String requestId;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final int? cacheTtlSeconds;
  final bool forceRefresh;

  factory SdkMiniProgramBackendQueryAction.fromJson(Map<String, dynamic> json) {
    final actionType = json['actionType'];
    if (actionType != stacActionType) {
      throw FormatException(
        'Expected actionType "$stacActionType", got "$actionType".',
      );
    }

    final requestId = json['requestId'];
    if (requestId is! String || requestId.trim().isEmpty) {
      throw const FormatException(
        'Mini-program backend query JSON must contain a non-empty "requestId" string.',
      );
    }

    final endpoint = json['endpoint'];
    if (endpoint is! String || endpoint.trim().isEmpty) {
      throw const FormatException(
        'Mini-program backend query JSON must contain a non-empty "endpoint" string.',
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

    final forceRefresh = json['forceRefresh'];
    if (forceRefresh != null && forceRefresh is! bool) {
      throw const FormatException(
        '"forceRefresh" must be a boolean when provided.',
      );
    }

    return SdkMiniProgramBackendQueryAction(
      requestId: requestId,
      endpoint: endpoint,
      method: method as String? ?? 'GET',
      body: body == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(body as Map),
      cacheTtlSeconds: cacheTtlSeconds as int?,
      forceRefresh: forceRefresh as bool? ?? false,
    );
  }

  MiniProgramBackendQuery toQuery() {
    final ttl = cacheTtlSeconds;
    return MiniProgramBackendQuery(
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      body: body,
      cacheTtl: ttl == null ? null : Duration(seconds: ttl),
      forceRefresh: forceRefresh,
    );
  }
}
