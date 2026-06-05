import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import 'backend_observability.dart';

const String backendJsonContentType = 'application/json; charset=utf-8';

Map<String, Object?> buildBackendErrorBody({
  required String responseType,
  required int statusCode,
  required String errorCode,
  required String message,
  Object? details,
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  return <String, Object?>{
    'responseType': responseType,
    'statusCode': statusCode,
    'errorCode': errorCode,
    'message': message,
    if (details != null) 'details': details,
    'error': <String, Object?>{
      'code': errorCode,
      'message': message,
      if (details != null) 'details': details,
    },
    ...extra,
  };
}

Map<String, Object?> buildSecureApiSuccessBody({
  required int statusCode,
  required String endpoint,
  required String message,
  required Map<String, Object?> result,
}) {
  return <String, Object?>{
    'responseType': 'secure_api_result',
    'statusCode': statusCode,
    'endpoint': endpoint,
    'message': message,
    ...result,
    'result': result,
  };
}

Map<String, Object?> buildHealthBody() => <String, Object?>{
  'responseType': 'health',
  'statusCode': HttpStatus.ok,
  'status': 'ok',
  'service': 'local_backend_service',
};

Map<String, Object?> buildInspectionBody({required Map<String, Object?> body}) {
  return <String, Object?>{
    'responseType': 'manifest_decision_inspection',
    'statusCode': HttpStatus.ok,
    ...body,
  };
}

Map<String, Object?> buildManifestDeliveryMetadata({
  required Map<String, Object?> metadata,
}) {
  return <String, Object?>{
    'responseType': 'manifest_delivery_metadata',
    'statusCode': HttpStatus.ok,
    ...metadata,
  };
}

Map<String, Object?> buildMiniProgramCatalogBody({
  required List<Map<String, Object?>> entries,
}) {
  return <String, Object?>{
    'responseType': 'mini_program_catalog',
    'statusCode': HttpStatus.ok,
    'entryCount': entries.length,
    'entries': entries,
  };
}

Response buildJsonResponse({
  required Map<String, Object?> body,
  required String traceId,
  int statusCode = HttpStatus.ok,
  Map<String, String> extraHeaders = const <String, String>{},
}) {
  return Response(
    statusCode,
    body: jsonEncode(withTraceId(body, traceId: traceId)),
    headers: withTraceHeaders(<String, String>{
      HttpHeaders.contentTypeHeader: backendJsonContentType,
      ...extraHeaders,
    }, traceId: traceId),
  );
}
