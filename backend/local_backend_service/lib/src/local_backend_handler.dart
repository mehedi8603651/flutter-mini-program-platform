import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

import 'manifest_delivery_selection.dart';

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

  return (Request request) async {
    if (request.method != 'GET') {
      return _jsonResponse(
        statusCode: HttpStatus.methodNotAllowed,
        body: <String, Object?>{
          'errorCode': 'method_not_allowed',
          'message': 'Only GET requests are supported.',
        },
      );
    }

    final segments = request.url.pathSegments;
    if (_matchesSegments(segments, const ['health'])) {
      return _jsonResponse(
        body: <String, Object?>{
          'status': 'ok',
          'service': 'local_backend_service',
        },
      );
    }

    if (segments.length == 4 &&
        segments[0] == 'api' &&
        segments[1] == 'manifests' &&
        _isLatestSegment(segments[3])) {
      return repository.readLatestManifest(
        miniProgramId: segments[2],
        context: DeliveryContext.fromQueryParameters(
          request.url.queryParameters,
        ),
        selector: manifestSelector,
      );
    }

    if (segments.length == 5 &&
        segments[0] == 'api' &&
        segments[1] == 'manifests' &&
        segments[3] == 'versions') {
      final version = _stripJsonSuffix(segments[4]);
      if (version == null) {
        return _badRequest('Manifest version path is invalid.');
      }

      return repository.readVersionedManifest(
        miniProgramId: segments[2],
        version: version,
      );
    }

    if (segments.length == 5 &&
        segments[0] == 'api' &&
        segments[1] == 'screens') {
      final screenId = _stripJsonSuffix(segments[4]);
      if (screenId == null) {
        return _badRequest('Screen path is invalid.');
      }

      return repository.readScreen(
        miniProgramId: segments[2],
        version: segments[3],
        screenId: screenId,
      );
    }

    return _jsonResponse(
      statusCode: HttpStatus.notFound,
      body: <String, Object?>{
        'errorCode': 'not_found',
        'message': 'No backend route matches "${request.url.path}".',
      },
    );
  };
}

class _PublishedArtifactRepository {
  const _PublishedArtifactRepository({required this.apiRootPath});

  final String apiRootPath;

  Future<Response> readLatestManifest({
    required String miniProgramId,
    required DeliveryContext context,
    required ManifestDeliverySelector selector,
  }) async {
    final validationError = _validateSegment(
      miniProgramId,
      label: 'miniProgramId',
    );
    if (validationError != null) {
      return validationError;
    }

    final contextValidationError = _validateContext(context);
    if (contextValidationError != null) {
      return contextValidationError;
    }

    try {
      final selection = await selector.selectLatestManifest(
        miniProgramId: miniProgramId,
        context: context,
      );

      return Response.ok(
        jsonEncode(selection.manifestJson),
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: _jsonContentType,
        },
      );
    } on ManifestSelectionException catch (error) {
      return _jsonResponse(
        statusCode: error.statusCode,
        body: <String, Object?>{
          'errorCode': error.errorCode,
          'message': error.message,
          if (error.details.isNotEmpty) 'details': error.details,
        },
      );
    }
  }

  Future<Response> readVersionedManifest({
    required String miniProgramId,
    required String version,
  }) async {
    final miniProgramError = _validateSegment(
      miniProgramId,
      label: 'miniProgramId',
    );
    if (miniProgramError != null) {
      return miniProgramError;
    }

    final versionError = _validateSegment(version, label: 'version');
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
    );
  }

  Future<Response> readScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    final miniProgramError = _validateSegment(
      miniProgramId,
      label: 'miniProgramId',
    );
    if (miniProgramError != null) {
      return miniProgramError;
    }

    final versionError = _validateSegment(version, label: 'version');
    if (versionError != null) {
      return versionError;
    }

    final screenError = _validateSegment(screenId, label: 'screenId');
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
    );
  }

  Future<Response> _readJsonFile(
    String filePath, {
    required String notFoundMessage,
  }) async {
    final normalizedPath = path.normalize(path.absolute(filePath));
    if (!_isWithinApiRoot(normalizedPath)) {
      return _badRequest('Resolved file path escapes the backend API root.');
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      return _jsonResponse(
        statusCode: HttpStatus.notFound,
        body: <String, Object?>{
          'errorCode': 'artifact_not_found',
          'message': notFoundMessage,
        },
      );
    }

    try {
      final rawJson = await file.readAsString();
      jsonDecode(rawJson);

      return Response.ok(
        rawJson,
        headers: <String, String>{
          HttpHeaders.contentTypeHeader: _jsonContentType,
        },
      );
    } on FormatException catch (error) {
      return _jsonResponse(
        statusCode: HttpStatus.internalServerError,
        body: <String, Object?>{
          'errorCode': 'invalid_backend_json',
          'message': 'Stored backend JSON is malformed.',
          'details': error.message,
        },
      );
    }
  }

  Response? _validateSegment(String value, {required String label}) {
    if (!_isSafePathSegment(value)) {
      return _badRequest('Path segment "$label" is invalid.');
    }
    return null;
  }

  Response? _validateContext(DeliveryContext context) {
    final hostApp = context.hostApp;
    if (hostApp != null) {
      final hostAppError = _validateSegment(hostApp, label: 'hostApp');
      if (hostAppError != null) {
        return hostAppError;
      }
    }

    final sdkVersion = context.sdkVersion;
    if (sdkVersion != null) {
      final sdkVersionError = _validateSegment(sdkVersion, label: 'sdkVersion');
      if (sdkVersionError != null) {
        return sdkVersionError;
      }
    }

    for (final capability in context.capabilities) {
      final capabilityError = _validateSegment(
        capability,
        label: 'capabilities',
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

Response _badRequest(String message) {
  return _jsonResponse(
    statusCode: HttpStatus.badRequest,
    body: <String, Object?>{'errorCode': 'invalid_request', 'message': message},
  );
}

Response _jsonResponse({
  int statusCode = HttpStatus.ok,
  required Map<String, Object?> body,
}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: <String, String>{HttpHeaders.contentTypeHeader: _jsonContentType},
  );
}
