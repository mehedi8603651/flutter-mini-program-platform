import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

import 'backend_observability.dart';
import 'backend_response_contracts.dart';
import 'manifest_delivery_selection.dart';
import 'secure_feedback_handler.dart';

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
      response = buildJsonResponse(
        statusCode: HttpStatus.methodNotAllowed,
        body: buildBackendErrorBody(
          responseType: 'backend_route_error',
          statusCode: HttpStatus.methodNotAllowed,
          errorCode: 'method_not_allowed',
          message:
              'Only GET requests and documented secure POST routes are supported.',
        ),
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
      response = buildJsonResponse(
        body: buildHealthBody(),
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

    if (segments.length == 3 &&
        segments[0] == 'api' &&
        segments[1] == 'discovery' &&
        _isCatalogSegment(segments[2])) {
      response = await repository.listAvailableMiniPrograms(
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
        routeKind: 'mini_program_catalog',
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
        segments[1] == 'debug' &&
        segments[2] == 'manifests' &&
        _isDecisionSegment(segments[4])) {
      response = await repository.inspectLatestManifestDecision(
        miniProgramId: segments[3],
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
        routeKind: 'manifest_decision_inspect',
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

    response = buildJsonResponse(
      statusCode: HttpStatus.notFound,
      body: buildBackendErrorBody(
        responseType: 'backend_route_error',
        statusCode: HttpStatus.notFound,
        errorCode: 'not_found',
        message: 'No backend route matches "${request.url.path}".',
      ),
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

  Future<Response> listAvailableMiniPrograms({
    required DeliveryContext context,
    required ManifestDeliverySelector selector,
    required String traceId,
  }) async {
    final contextValidationError = _validateContext(context, traceId: traceId);
    if (contextValidationError != null) {
      return contextValidationError;
    }

    final manifestsDirectory = Directory(path.join(apiRootPath, 'manifests'));
    if (!await manifestsDirectory.exists()) {
      return buildJsonResponse(
        body: buildMiniProgramCatalogBody(entries: const <Map<String, Object?>>[]),
        traceId: traceId,
      );
    }

    final miniProgramIds = await _listPublishedMiniProgramIds(manifestsDirectory);
    final entries = <Map<String, Object?>>[];

    for (final miniProgramId in miniProgramIds) {
      try {
        final selection = await selector.selectLatestManifest(
          miniProgramId: miniProgramId,
          context: context,
        );
        entries.add(_buildCatalogEntry(selection));
      } on ManifestSelectionException catch (error) {
        if (_shouldSkipCatalogEntry(error)) {
          logBackendEvent(
            'INFO',
            'Skipped mini-program from discovery catalog.',
            context: <String, Object?>{
              'traceId': traceId,
              'miniProgramId': miniProgramId,
              'errorCode': error.errorCode,
              'statusCode': error.statusCode,
            },
          );
          continue;
        }

        return buildJsonResponse(
          statusCode: error.statusCode,
          body: buildBackendErrorBody(
            responseType: 'mini_program_catalog_error',
            statusCode: error.statusCode,
            errorCode: error.errorCode,
            message: error.message,
            details: error.details.isNotEmpty ? error.details : null,
          ),
          traceId: traceId,
        );
      }
    }

    entries.sort(
      (left, right) => (left['title'] as String).compareTo(right['title'] as String),
    );

    logBackendEvent(
      'INFO',
      'Resolved mini-program discovery catalog.',
      context: <String, Object?>{
        'traceId': traceId,
        'entryCount': entries.length,
        'deliveryContext': context.toJson(),
      },
    );

    return buildJsonResponse(
      body: buildMiniProgramCatalogBody(entries: entries),
      traceId: traceId,
      extraHeaders: <String, String>{'x-mini-program-catalog-count': '${entries.length}'},
    );
  }

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
        ..['deliveryMetadata'] = buildManifestDeliveryMetadata(
          metadata: <String, Object?>{
            ...selection.decision.toJson(),
            'traceId': traceId,
          },
      );
      final headers = <String, String>{
        HttpHeaders.contentTypeHeader: backendJsonContentType,
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

      return buildJsonResponse(
        statusCode: error.statusCode,
        body: buildBackendErrorBody(
          responseType: 'manifest_delivery_error',
          statusCode: error.statusCode,
          errorCode: error.errorCode,
          message: error.message,
          details: error.details.isNotEmpty ? error.details : null,
        ),
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

  Future<Response> inspectLatestManifestDecision({
    required String miniProgramId,
    required DeliveryContext context,
    required ManifestDeliverySelector selector,
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

    final contextValidationError = _validateContext(context, traceId: traceId);
    if (contextValidationError != null) {
      return contextValidationError;
    }

    final report = await selector.inspectLatestManifestDecision(
      miniProgramId: miniProgramId,
      context: context,
    );

    logBackendEvent(
      'INFO',
      'Inspected manifest delivery decision.',
      context: <String, Object?>{
        'traceId': traceId,
        'miniProgramId': miniProgramId,
        'outcome': report.outcome,
        'simulatedStatusCode': report.simulatedStatusCode,
        'deliveryContext': context.toJson(),
      },
    );

    return buildJsonResponse(
      body: buildInspectionBody(
        body: report.toJson()
          ..['traceId'] = traceId,
      ),
      traceId: traceId,
      extraHeaders: <String, String>{
        'x-debug-route': 'manifest_decision_inspect',
        'x-debug-outcome': report.outcome,
      },
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
      return buildJsonResponse(
        statusCode: HttpStatus.notFound,
        body: buildBackendErrorBody(
          responseType: 'artifact_error',
          statusCode: HttpStatus.notFound,
          errorCode: 'artifact_not_found',
          message: notFoundMessage,
        ),
        traceId: traceId,
      );
    }

    try {
      final rawJson = await file.readAsString();
      jsonDecode(rawJson);

      return Response.ok(
        rawJson,
        headers: withTraceHeaders(<String, String>{
          HttpHeaders.contentTypeHeader: backendJsonContentType,
          ...extraHeaders,
        }, traceId: traceId),
      );
    } on FormatException catch (error) {
      return buildJsonResponse(
        statusCode: HttpStatus.internalServerError,
        body: buildBackendErrorBody(
          responseType: 'artifact_error',
          statusCode: HttpStatus.internalServerError,
          errorCode: 'invalid_backend_json',
          message: 'Stored backend JSON is malformed.',
          details: <String, Object?>{'reason': error.message},
        ),
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

  Future<List<String>> _listPublishedMiniProgramIds(
    Directory manifestsDirectory,
  ) async {
    final ids = <String>[];
    await for (final entity in manifestsDirectory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }

      final miniProgramId = path.basename(entity.path);
      if (!_isSafePathSegment(miniProgramId)) {
        continue;
      }

      ids.add(miniProgramId);
    }

    ids.sort();
    return ids;
  }

  Map<String, Object?> _buildCatalogEntry(ManifestSelectionResult selection) {
    final manifestJson = selection.manifestJson;
    final miniProgramId = manifestJson['id']?.toString() ?? '';
    final title = _humanizeMiniProgramId(miniProgramId);
    final rawRequiredCapabilities =
        manifestJson['requiredCapabilities'] as List<dynamic>? ?? const [];

    return <String, Object?>{
      'id': miniProgramId,
      'title': title,
      'description':
          '$title is a backend-discovered portable mini-program delivered through the shared SDK.',
      'entry': manifestJson['entry']?.toString() ?? '',
      'resolvedVersion': selection.version,
      'requiredCapabilities': rawRequiredCapabilities
          .map((value) => value.toString())
          .toList(),
      'selectionMode': selection.decision.selectionMode,
      'decisionReason': selection.decision.decisionReason,
      if (selection.decision.matchedRuleId != null)
        'matchedRuleId': selection.decision.matchedRuleId,
    };
  }

  bool _shouldSkipCatalogEntry(ManifestSelectionException error) {
    if (error.statusCode == HttpStatus.preconditionFailed ||
        error.statusCode == HttpStatus.notFound) {
      return true;
    }

    return false;
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

bool _isCatalogSegment(String value) =>
    value == 'mini-programs' || value == 'mini-programs.json';

bool _isDecisionSegment(String value) =>
    value == 'decision' || value == 'decision.json';

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

String _humanizeMiniProgramId(String miniProgramId) {
  return miniProgramId
      .split(RegExp(r'[_-]+'))
      .where((segment) => segment.isNotEmpty)
      .map(
        (segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
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
  return buildJsonResponse(
    statusCode: HttpStatus.badRequest,
    body: buildBackendErrorBody(
      responseType: 'request_error',
      statusCode: HttpStatus.badRequest,
      errorCode: 'invalid_request',
      message: message,
    ),
    traceId: traceId,
  );
}
