part of '../published_mini_program_catalog_client.dart';

extension _PublishedCatalogErrors on PublishedMiniProgramCatalogClient {
  MiniProgramSourceException _buildCatalogSourceException({
    required Uri uri,
    required http.Response response,
  }) {
    final decodedBody = _tryDecodeCatalogJsonObject(response.body);
    final nestedError = _tryReadCatalogNestedError(decodedBody);
    final errorCode =
        decodedBody?['errorCode']?.toString() ??
        nestedError?['code']?.toString();
    final message =
        decodedBody?['message']?.toString() ??
        nestedError?['message']?.toString() ??
        'Failed to load mini-program catalog from "$uri" (HTTP ${response.statusCode}).';

    return MiniProgramSourceException(
      message: message,
      errorCode: errorCode,
      statusCode: response.statusCode,
      details: <String, dynamic>{
        'uri': uri.toString(),
        'resourceLabel': 'mini_program_catalog',
        'statusCode': response.statusCode,
        ..._extractCatalogBackendDetails(decodedBody, response.headers),
      },
    );
  }

  Map<String, dynamic>? _tryDecodeCatalogJsonObject(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall back to a generic error when the backend body is malformed.
    }

    return null;
  }

  Map<String, dynamic> _extractCatalogBackendDetails(
    Map<String, dynamic>? decodedBody,
    Map<String, String> responseHeaders,
  ) {
    final details = <String, dynamic>{};

    final responseType = decodedBody?['responseType']?.toString();
    if (responseType != null && responseType.isNotEmpty) {
      details['responseType'] = responseType;
    }

    final traceId =
        decodedBody?['traceId']?.toString() ??
        responseHeaders['x-backend-trace-id'];
    if (traceId != null && traceId.isNotEmpty) {
      details['traceId'] = traceId;
    }

    final rawDetails =
        decodedBody?['details'] ??
        _tryReadCatalogNestedError(decodedBody)?['details'];
    if (rawDetails is Map<String, dynamic>) {
      details.addAll(rawDetails);
      return details;
    }

    if (rawDetails is Map) {
      details.addAll(
        rawDetails.map((key, value) => MapEntry(key.toString(), value)),
      );
      return details;
    }

    if (rawDetails != null) {
      details['backendDetails'] = rawDetails;
    }

    return details;
  }

  Map<String, dynamic>? _tryReadCatalogNestedError(
    Map<String, dynamic>? decodedBody,
  ) {
    if (decodedBody == null) {
      return null;
    }

    final rawError = decodedBody['error'];
    if (rawError is Map<String, dynamic>) {
      return rawError;
    }
    if (rawError is Map) {
      return rawError.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }
}
