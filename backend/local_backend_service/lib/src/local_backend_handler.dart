import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

import 'backend_observability.dart';
import 'manifest_delivery_selection.dart';
import 'secure_feedback_handler.dart';

const String _jsonContentType = 'application/json; charset=utf-8';

/// Creates a handler for serving published mini-program artifacts from disk.
Handler createLocalBackendHandler({required Directory apiRootDirectory}) {
  final normalizedApiRootPath = path.normalize(
    path.absolute(apiRootDirectory.path),
  );
  final repository = _PublishedArtifactRepository(
    apiRootPath: normalizedApiRootPath,
  );
  final manifestSelector = ManifestDeliverySelector(
    apiRootPath: normalizedApiRootPath,
  );
  final secureFeedbackHandler = SecureFeedbackHandler(
    apiRootPath: normalizedApiRootPath,
  );

  return (Request request) async {
    final traceId = resolveBackendTraceId(request);
    final stopwatch = Stopwatch()..start();
    final segments = request.url.pathSegments;
    late final Response response;

    if (request.method == 'POST' &&
        _matchesSegments(segments, const [
          'api',
          'secure',
          'feedback',
          'submit',
        ])) {
      response = await secureFeedbackHandler.handleSubmit(
        request,
        traceId: traceId,
      );
      _logRequestCompletion(
        traceId: traceId,
        request: request,
        response: response,
        stopwatch: stopwatch,
        routeKind: 'secure_feedback_submit',
      );
      return response;
    }

    if (request.method != 'GET') {
      response = _jsonResponse(
        statusCode: HttpStatus.methodNotAllowed,
        body: <String, Object?>{
          'errorCode': 'method_not_allowed',
          'message':
              'Only GET requests and documented secure POST routes are supported.',
        },
        traceId: traceId,
      );
      _logRequestCompletion(
        traceId: traceId,
        request: request,
        response: response,
        stopwatch: stopwatch,
        routeKind: 'unsupported_method',
      );
      return response;
    }

    if (_matchesSegments(segments, const ['health'])) {
      response = _jsonResponse(
        body: <String, Object?>{
          'status': 'ok',
          'service': 'local_backend_service',
        },
        traceId: traceId,
      );
      _logRequestCompletion(
        traceId: traceId,
        request: request,
        response: response,
        stopwatch: stopwatch,
        routeKind: 'health',
      );
      return response;
    }

    if (segments.length == 4 &&
        segments[0] == 'api' &&
        segments[1] == 'manifests' &&
        _isLatestSegment(segments[3])) {
      response = await repository.readLatestManifest(
        miniProgramId: segments[2],
        context: DeliveryContext.fromQueryParameters(
          request.url.queryParameters,
        ),
        selector: manifestSelector,
        traceId: traceId,
      );
      _logRequestCompletion(
        traceId: traceId,
        request: request,
        response: response,
        stopwatch: stopwatch,
        routeKind: 'manifest_latest',
      );
      return response;
    }

    if (segments.length == 5 &&
        segments[0] == 'api' &&
        segments[1] == 'manifests' &&
        segments[3] == 'versions') {
      final version = _stripJsonSuffix(segments[4]);
      if (version == null) {
        response = _badRequest('Manifest version path is invalid.', traceId);
        _logRequestCompletion(
          traceId: traceId,
          request: request,
          response: response,
          stopwatch: stopwatch,
          routeKind: 'manifest_versioned_invalid',
        );
        return response;
      }

      response = await repository.readVersionedManifest(
        miniProgramId: segments[2],
        version: version,
        traceId: traceId,
      );
      _logRequestCompletion(
        traceId: traceId,
        request: request,
        response: response,
        stopwatch: stopwatch,
        routeKind: 'manifest_versioned',
      );
      return response;
    }

    if (segments.length == 5 &&
        segments[0] == 'api' &&
        segments[1] == 'screens') {
      final screenId = _stripJsonSuffix(segments[4]);
      if (screenId == null) {
        response = _badRequest('Screen path is invalid.', traceId);
        _logRequestCompletion(
          traceId: traceId,
          request: request,
          response: response,
          stopwatch: stopwatch,
          routeKind: 'screen_invalid',
        );
        return response;
      }

      response = await repository.readScreen(
        miniProgramId: segments[2],
        version: segments[3],
        screenId: screenId,
        traceId: traceId,
      );
      _logRequestCompletion(
        traceId: traceId,
        request: request,
        response: response,
        stopwatch: stopwatch,
        routeKind: 'screen_versioned',
      );
      return response;
    }

    response = _jsonResponse(
      statusCode: HttpStatus.notFound,
      body: <String, Object?>{
        'errorCode': 'not_found',
        'message': 'No backend route matches "${request.url.path}".',
      },
      traceId: traceId,
    );
    _logRequestCompletion(
      traceId: traceId,
      request: request,
      response: response,
      stopwatch: stopwatch,
      routeKind: 'not_found',
    );
    return response;
  };
}

class _PublishedArtifactRepository {
  const _PublishedArtifactRepository({required this.apiRootPath});

  final String apiRootPath;

  Future<Response> readLatestManifest({
    required String miniProgramId,
    required DeliveryContext context,
    required ManifestDeliverySelector selector,
    required String traceId,
  }) async {
    final validationError = _validateSegment(
      miniProgramId,
      label: 'miniProgramId',
      traceId: traceId,
    );
    if (validationError != null) {
      return validationError;
    }

    final contextValidationError = _validateContext(context, traceId: traceId);
    if (contextValidationError != null) {
      return contextValidationError;
    }

    try {
      final selection = await selector.selectLatestManifest(
        miniProgramId: miniProgramId,
        context: context,
      );
      final responseBody = Map<String, Object?>.from(selection.manifestJson)
        ..['deliveryMetadata'] = <String, Object?>{
          ...selection.decision.toJson(),
          'traceId': traceId,
        };
      final headers = <String, String>{
        HttpHeaders.contentTypeHeader: _jsonContentType,
        'x-mini-program-id': miniProgramId,
        'x-mini-program-version': selection.version,
        'x-mini-program-selection-mode': selection.decision.selectionMode,
        'x-mini-program-decision-reason': selection.decision.decisionReason,
      };
      final matchedRuleId = selection.decision.matchedRuleId;
      if (matchedRuleId != null) {
        headers['x-mini-program-matched-rule-id'] = matchedRuleId;
      }

      logBackendEvent(
        'INFO',
        'Resolved latest manifest request.',
        context: <String, Object?>{
          'traceId': traceId,
          'miniProgramId': miniProgramId,
          'resolvedVersion': selection.version,
          'selectionMode': selection.decision.selectionMode,
          'decisionReason': selection.decision.decisionReason,
          if (matchedRuleId != null) 'matchedRuleId': matchedRuleId,
          'deliveryContext': context.toJson(),
        },
      );

      return Response.ok(
        jsonEncode(responseBody),
        headers: withTraceHeaders(headers, traceId: traceId),
      );
    } on ManifestSelectionException catch (error) {
      logBackendEvent(
        'WARN',
        'Rejected latest manifest request.',
        context: <String, Object?>{
          'traceId': traceId,
          'miniProgramId': miniProgramId,
          'statusCode': error.statusCode,
          'errorCode': error.errorCode,
          'deliveryContext': context.toJson(),
          if (error.details.isNotEmpty) 'details': error.details,
        },
      );

      return _jsonResponse(
        statusCode: error.statusCode,
        body: <String, Object?>{
          'errorCode': error.errorCode,
          'message': error.message,
          if (error.details.isNotEmpty) 'details': error.details,
        },
        traceId: traceId,
      );
    }
  }

  Future<Response> readVersionedManifest({
    required String miniProgramId,
    required String version,
    required String traceId,
  }) async {
    final miniProgramError = _validateSegment(
      miniProgramId,
      label: 'miniProgramId',
      traceId: traceId,
    );
    if (miniProgramError != null) {
      return miniProgramError;
    }

    final versionError = _validateSegment(
      version,
      label: 'version',
      traceId: traceId,
    );
    if (versionError != null) {
      return versionError;
    }

    return _readJsonFile(
      path.join(
        apiRootPath,
        'manifests',
        miniProgramId,
        'versions',
        '$version.json',
      ),
      notFoundMessage:
          'Manifest version "$version" for mini-program "$miniProgramId" was not found.',
      traceId: traceId,
      extraHeaders: <String, String>{'x-mini-program-id': miniProgramId},
    );
  }

  Future<Response> readScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
    required String traceId,
  }) async {
    final miniProgramError = _validateSegment(
      miniProgramId,
      label: 'miniProgramId',
      traceId: traceId,
    );
    if (miniProgramError != null) {
      return miniProgramError;
    }

    final versionError = _validateSegment(
      version,
      label: 'version',
      traceId: traceId,
    );
    if (versionError != null) {
      return versionError;
    }

    final screenError = _validateSegment(
      screenId,
      label: 'screenId',
      traceId: traceId,
    );
    if (screenError != null) {
      return screenError;
    }

    return _readJsonFile(
      path.join(
        apiRootPath,
        'screens',
        miniProgramId,
        version,
        '$screenId.json',
      ),
      notFoundMessage:
          'Screen "$screenId" for mini-program "$miniProgramId" version "$version" was not found.',
      traceId: traceId,
      extraHeaders: <String, String>{'x-mini-program-id': miniProgramId},
    );
  }

  Future<Response> _readJsonFile(
    String filePath, {
    required String notFoundMessage,
    required String traceId,
    Map<String, String> extraHeaders = const <String, String>{},
  }) async {
    final normalizedPath = path.normalize(path.absolute(filePath));
    if (!_isWithinApiRoot(normalizedPath)) {
      return _badRequest(
        'Resolved file path escapes the backend API root.',
        traceId,
      );
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      return _jsonResponse(
        statusCode: HttpStatus.notFound,
        body: <String, Object?>{
          'errorCode': 'artifact_not_found',
          'message': notFoundMessage,
        },
        traceId: traceId,
      );
    }

    try {
      final rawJson = await file.readAsString();
      jsonDecode(rawJson);

      return Response.ok(
        rawJson,
        headers: withTraceHeaders(<String, String>{
          HttpHeaders.contentTypeHeader: _jsonContentType,
          ...extraHeaders,
        }, traceId: traceId),
      );
    } on FormatException catch (error) {
      return _jsonResponse(
        statusCode: HttpStatus.internalServerError,
        body: <String, Object?>{
          'errorCode': 'invalid_backend_json',
          'message': 'Stored backend JSON is malformed.',
          'details': error.message,
        },
        traceId: traceId,
      );
    }
  }

  Response? _validateSegment(
    String value, {
    required String label,
    required String traceId,
  }) {
    if (!_isSafePathSegment(value)) {
      return _badRequest('Path segment "$label" is invalid.', traceId);
    }
    return null;
  }

  Response? _validateContext(
    DeliveryContext context, {
    required String traceId,
  }) {
    final hostApp = context.hostApp;
    if (hostApp != null) {
      final hostAppError = _validateSegment(
        hostApp,
        label: 'hostApp',
        traceId: traceId,
      );
      if (hostAppError != null) {
        return hostAppError;
      }
    }

    final sdkVersion = context.sdkVersion;
    if (sdkVersion != null) {
      final sdkVersionError = _validateSegment(
        sdkVersion,
        label: 'sdkVersion',
        traceId: traceId,
      );
      if (sdkVersionError != null) {
        return sdkVersionError;
      }
    }

    final hostVersion = context.hostVersion;
    if (hostVersion != null) {
      final hostVersionError = _validateSegment(
        hostVersion,
        label: 'hostVersion',
        traceId: traceId,
      );
      if (hostVersionError != null) {
        return hostVersionError;
      }
    }

    final platform = context.platform;
    if (platform != null) {
      final platformError = _validateSegment(
        platform,
        label: 'platform',
        traceId: traceId,
      );
      if (platformError != null) {
        return platformError;
      }
    }

    final locale = context.locale;
    if (locale != null) {
      final localeError = _validateSegment(
        locale,
        label: 'locale',
        traceId: traceId,
      );
      if (localeError != null) {
        return localeError;
      }
    }

    final tenantId = context.tenantId;
    if (tenantId != null) {
      final tenantIdError = _validateSegment(
        tenantId,
        label: 'tenantId',
        traceId: traceId,
      );
      if (tenantIdError != null) {
        return tenantIdError;
      }
    }

    final pinnedVersion = context.pinnedVersion;
    if (pinnedVersion != null) {
      final pinnedVersionError = _validateSegment(
        pinnedVersion,
        label: 'pinnedVersion',
        traceId: traceId,
      );
      if (pinnedVersionError != null) {
        return pinnedVersionError;
      }
    }

    for (final capability in context.capabilities) {
      final capabilityError = _validateSegment(
        capability,
        label: 'capabilities',
        traceId: traceId,
      );
      if (capabilityError != null) {
        return capabilityError;
      }
    }

    return null;
  }

  bool _isWithinApiRoot(String normalizedPath) {
    return normalizedPath == apiRootPath ||
        normalizedPath.startsWith('$apiRootPath${path.separator}');
  }
}

bool _matchesSegments(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) {
    return false;
  }

  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) {
      return false;
    }
  }

  return true;
}

bool _isLatestSegment(String value) =>
    value == 'latest' || value == 'latest.json';

String? _stripJsonSuffix(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized.endsWith('.json')) {
    final withoutExtension = normalized.substring(0, normalized.length - 5);
    return withoutExtension.isEmpty ? null : withoutExtension;
  }

  return normalized;
}

bool _isSafePathSegment(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized == '.' || normalized == '..') {
    return false;
  }

  return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalized);
}

void _logRequestCompletion({
  required String traceId,
  required Request request,
  required Response response,
  required Stopwatch stopwatch,
  required String routeKind,
}) {
  logBackendEvent(
    response.statusCode >= HttpStatus.badRequest ? 'WARN' : 'INFO',
    'Completed backend request.',
    context: <String, Object?>{
      'traceId': traceId,
      'routeKind': routeKind,
      'method': request.method,
      'path': request.url.path,
      'statusCode': response.statusCode,
      'durationMs': stopwatch.elapsedMilliseconds,
    },
  );
}

Response _badRequest(String message, String traceId) {
  return _jsonResponse(
    statusCode: HttpStatus.badRequest,
    body: <String, Object?>{'errorCode': 'invalid_request', 'message': message},
    traceId: traceId,
  );
}

Response _jsonResponse({
  int statusCode = HttpStatus.ok,
  required Map<String, Object?> body,
  required String traceId,
  Map<String, String> extraHeaders = const <String, String>{},
}) {
  return Response(
    statusCode,
    body: jsonEncode(withTraceId(body, traceId: traceId)),
    headers: withTraceHeaders(<String, String>{
      HttpHeaders.contentTypeHeader: _jsonContentType,
      ...extraHeaders,
    }, traceId: traceId),
  );
}
