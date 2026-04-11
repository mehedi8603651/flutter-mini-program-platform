import 'dart:io';

import 'package:shelf/shelf.dart';

const String backendTraceIdHeader = 'x-backend-trace-id';
const String backendCorsAllowOriginHeader = 'access-control-allow-origin';
const String backendCorsAllowMethodsHeader = 'access-control-allow-methods';
const String backendCorsAllowHeadersHeader = 'access-control-allow-headers';
const String backendCorsExposeHeadersHeader = 'access-control-expose-headers';
const String backendCorsMaxAgeHeader = 'access-control-max-age';
const String backendCorsAllowPrivateNetworkHeader =
    'access-control-allow-private-network';
const String backendVaryHeader = 'vary';

const String _backendCorsAllowMethods = 'GET, POST, OPTIONS';
const String _backendCorsAllowHeaders =
    'Content-Type, Authorization, X-Host-App, X-Host-Version, '
    'X-Host-User-Id, X-Host-Tenant-Id, X-Request-Id';
const String _backendCorsExposeHeaders =
    'x-backend-trace-id, x-mini-program-id, x-mini-program-version, '
    'x-mini-program-selection-mode, x-mini-program-decision-reason, '
    'x-mini-program-matched-rule-id, x-mini-program-catalog-count, '
    'x-debug-route, x-debug-outcome';
const String _backendCorsMaxAgeSeconds = '600';
const String _backendCorsAllowPrivateNetwork = 'true';
const String _backendCorsVaryDirectives =
    'Origin, Access-Control-Request-Method, Access-Control-Request-Headers, '
    'Access-Control-Request-Private-Network';

String resolveBackendTraceId(Request request) {
  final requestedTraceId = request.headers['x-request-id']?.trim();
  if (requestedTraceId != null &&
      requestedTraceId.isNotEmpty &&
      RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(requestedTraceId)) {
    return requestedTraceId;
  }

  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  return 'lb_$timestamp';
}

Map<String, Object?> withTraceId(
  Map<String, Object?> body, {
  required String traceId,
}) {
  final responseBody = Map<String, Object?>.from(body)..['traceId'] = traceId;

  final rawDetails = responseBody['details'];
  if (rawDetails is Map<String, Object?>) {
    responseBody['details'] = Map<String, Object?>.from(rawDetails)
      ..putIfAbsent('traceId', () => traceId);
  } else if (rawDetails is Map) {
    responseBody['details'] = rawDetails.map(
      (key, value) => MapEntry(key.toString(), value),
    )..putIfAbsent('traceId', () => traceId);
  }

  return responseBody;
}

Map<String, String> withTraceHeaders(
  Map<String, String> headers, {
  required String traceId,
}) {
  return <String, String>{
    ...headers,
    backendTraceIdHeader: traceId,
    backendCorsAllowOriginHeader: '*',
    backendCorsAllowMethodsHeader: _backendCorsAllowMethods,
    backendCorsAllowHeadersHeader: _backendCorsAllowHeaders,
    backendCorsExposeHeadersHeader: _backendCorsExposeHeaders,
    backendCorsMaxAgeHeader: _backendCorsMaxAgeSeconds,
  };
}

Map<String, String> withRequestTraceHeaders(
  Request request,
  Map<String, String> headers, {
  required String traceId,
}) {
  final resolvedHeaders = <String, String>{
    ...withTraceHeaders(headers, traceId: traceId),
  };
  final origin = _resolveCorsOrigin(request);
  if (origin != null) {
    resolvedHeaders[backendCorsAllowOriginHeader] = origin;
    resolvedHeaders[backendVaryHeader] = _mergeVaryHeader(
      resolvedHeaders[backendVaryHeader],
      _backendCorsVaryDirectives,
    );
  }

  if (_requestsPrivateNetworkAccess(request)) {
    resolvedHeaders[backendCorsAllowPrivateNetworkHeader] =
        _backendCorsAllowPrivateNetwork;
    resolvedHeaders[backendVaryHeader] = _mergeVaryHeader(
      resolvedHeaders[backendVaryHeader],
      'Access-Control-Request-Private-Network',
    );
  }

  return resolvedHeaders;
}

String? _resolveCorsOrigin(Request request) {
  final origin = request.headers['origin']?.trim();
  if (origin == null || origin.isEmpty || origin == 'null') {
    return null;
  }
  return origin;
}

bool _requestsPrivateNetworkAccess(Request request) =>
    request.headers['access-control-request-private-network']
        ?.trim()
        .toLowerCase() ==
    'true';

String _mergeVaryHeader(String? currentValue, String additions) {
  final mergedValues = <String>{
    ...?currentValue
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty),
    ...additions
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty),
  };
  return mergedValues.join(', ');
}

void logBackendEvent(
  String level,
  String message, {
  Map<String, Object?> context = const <String, Object?>{},
}) {
  final normalizedLevel = level.trim().toUpperCase();
  if (context.isEmpty) {
    stdout.writeln('[local_backend_service][$normalizedLevel] $message');
    return;
  }

  stdout.writeln(
    '[local_backend_service][$normalizedLevel] $message | context=$context',
  );
}
