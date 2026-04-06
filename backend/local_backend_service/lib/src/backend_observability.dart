import 'dart:io';

import 'package:shelf/shelf.dart';

const String backendTraceIdHeader = 'x-backend-trace-id';

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
  return <String, String>{...headers, backendTraceIdHeader: traceId};
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
