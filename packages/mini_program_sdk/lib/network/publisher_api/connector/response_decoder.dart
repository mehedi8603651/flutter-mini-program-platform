part of '../../mini_program_backend_connector.dart';

extension _EndpointRoutingResponseDecoder
    on EndpointRoutingMiniProgramBackendConnector {
  MiniProgramBackendResult _toResult({
    required MiniProgramBackendRequest request,
    required String endpoint,
    required String method,
    required http.Response response,
  }) {
    final decoded = _decodeBody(response.body);
    final data = _normalizeData(decoded);
    final message = data['message']?.toString();
    final errorCode = data['errorCode']?.toString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return MiniProgramBackendResult.success(
        requestId: request.requestId,
        endpoint: endpoint,
        method: method,
        statusCode: response.statusCode,
        message: message,
        data: data,
      );
    }

    return MiniProgramBackendResult.failed(
      requestId: request.requestId,
      endpoint: endpoint,
      method: method,
      statusCode: response.statusCode,
      message:
          message ??
          'Mini-program Publisher API returned HTTP ${response.statusCode}.',
      errorCode: errorCode ?? 'publisher_backend_error',
      data: data,
    );
  }

  Object? _decodeBody(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return <String, dynamic>{'rawBody': rawBody};
    }
  }

  Map<String, dynamic> _normalizeData(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is List) {
      return <String, dynamic>{'items': decoded};
    }
    if (decoded == null) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{'value': decoded};
  }
}
