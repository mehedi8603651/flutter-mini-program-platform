import 'dart:convert';
import 'dart:io';

import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

import 'backend_observability.dart';
import 'backend_response_contracts.dart';

class SecureFeedbackHandler {
  const SecureFeedbackHandler({required this.apiRootPath});

  final String apiRootPath;

  Future<Response> handleSubmit(
    Request request, {
    required String traceId,
  }) async {
    final policy = await _loadPolicy();

    if (!policy.allowedMethods.contains(request.method.toUpperCase())) {
      return buildJsonResponse(
        statusCode: HttpStatus.methodNotAllowed,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.methodNotAllowed,
          errorCode: 'method_not_allowed',
          message:
              'Secure feedback submission only supports ${policy.allowedMethods.join(', ')}.',
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    final hostApp = _headerValue(request, 'x-host-app');
    final hostVersion = _headerValue(request, 'x-host-version');
    final hostUserId = _headerValue(request, 'x-host-user-id');
    final tenantId = _headerValue(request, 'x-host-tenant-id');
    final authorization = _headerValue(request, 'authorization');

    final missingHeaders = <String>[
      if (hostApp == null) 'x-host-app',
      if (hostVersion == null) 'x-host-version',
      if (hostUserId == null) 'x-host-user-id',
      if (authorization == null) 'authorization',
    ];

    if (missingHeaders.isNotEmpty) {
      return buildJsonResponse(
        statusCode: HttpStatus.unauthorized,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.unauthorized,
          errorCode: MiniProgramErrorCodes.secureApiUnauthorized,
          message:
              'Missing required secure API headers: ${missingHeaders.join(', ')}.',
          details: <String, Object?>{'missingHeaders': missingHeaders},
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    if (!authorization!.startsWith('Bearer ')) {
      return buildJsonResponse(
        statusCode: HttpStatus.unauthorized,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.unauthorized,
          errorCode: MiniProgramErrorCodes.secureApiUnauthorized,
          message: 'Authorization header must use the Bearer scheme.',
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    final accessToken = authorization.substring('Bearer '.length).trim();
    if (accessToken.isEmpty) {
      return buildJsonResponse(
        statusCode: HttpStatus.unauthorized,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.unauthorized,
          errorCode: MiniProgramErrorCodes.secureApiUnauthorized,
          message: 'Authorization header must include a bearer token.',
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    if (_isExpiredToken(accessToken, policy)) {
      return buildJsonResponse(
        statusCode: HttpStatus.unauthorized,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.unauthorized,
          errorCode: MiniProgramErrorCodes.secureApiSessionExpired,
          message:
              'The host session has expired for secure feedback submission.',
          details: <String, Object?>{
            'hostApp': hostApp,
            'hostUserId': hostUserId,
          },
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    if (!policy.allowedHosts.contains(hostApp)) {
      return buildJsonResponse(
        statusCode: HttpStatus.forbidden,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.forbidden,
          errorCode: MiniProgramErrorCodes.secureApiForbidden,
          message:
              'Host "$hostApp" is not allowlisted for secure feedback submission.',
          details: <String, Object?>{
            'hostApp': hostApp,
            'reason': 'host_not_allowlisted',
            'allowedHosts': policy.allowedHosts,
          },
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    if (policy.blockedUserIds.contains(hostUserId)) {
      return buildJsonResponse(
        statusCode: HttpStatus.forbidden,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.forbidden,
          errorCode: MiniProgramErrorCodes.secureApiForbidden,
          message:
              'User "$hostUserId" is not allowed to submit secure feedback.',
          details: <String, Object?>{
            'hostApp': hostApp,
            'hostUserId': hostUserId,
            'reason': 'user_blocked',
          },
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    final requestBodyOrResponse = await _readJsonObject(
      request,
      traceId: traceId,
      endpoint: policy.endpoint,
    );
    if (requestBodyOrResponse is Response) {
      return requestBodyOrResponse;
    }
    final requestBody = requestBodyOrResponse as Map<String, dynamic>;

    final source = _stringField(requestBody, 'source');
    final message = _stringField(requestBody, 'message');
    final flow = _stringField(requestBody, 'flow');

    final missingFields = <String>[
      if (source == null) 'source',
      if (message == null) 'message',
    ];
    if (missingFields.isNotEmpty) {
      return buildJsonResponse(
        statusCode: HttpStatus.badRequest,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.badRequest,
          errorCode: MiniProgramErrorCodes.secureApiInvalidPayload,
          message:
              'Secure feedback submission requires: ${missingFields.join(', ')}.',
          details: <String, Object?>{'missingFields': missingFields},
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    if (!policy.allowedSources.contains(source)) {
      return buildJsonResponse(
        statusCode: HttpStatus.forbidden,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.forbidden,
          errorCode: MiniProgramErrorCodes.secureApiForbidden,
          message:
              'Source "$source" is not allowlisted for secure feedback submission.',
          details: <String, Object?>{
            'source': source,
            'reason': 'source_not_allowlisted',
            'allowedSources': policy.allowedSources,
          },
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    if (message!.length < policy.minimumMessageLength) {
      return buildJsonResponse(
        statusCode: HttpStatus.badRequest,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.badRequest,
          errorCode: MiniProgramErrorCodes.secureApiValidationFailed,
          message:
              'Feedback message must be at least ${policy.minimumMessageLength} characters.',
          details: <String, Object?>{
            'field': 'message',
            'minimumLength': policy.minimumMessageLength,
          },
          extra: <String, Object?>{'endpoint': policy.endpoint},
        ),
        traceId: traceId,
      );
    }

    final status = hostApp == 'super_app_host' ? 'accepted' : 'queued';
    final submissionId =
        '${hostApp}_${DateTime.now().millisecondsSinceEpoch.toString()}';

    logBackendEvent(
      'INFO',
      'Accepted secure feedback submission.',
      context: <String, Object?>{
        'traceId': traceId,
        'hostApp': hostApp,
        'hostVersion': hostVersion,
        'hostUserId': hostUserId,
        if (tenantId != null) 'tenantId': tenantId,
        'source': source,
        if (flow != null) 'flow': flow,
        'submissionId': submissionId,
        'status': status,
      },
    );

    return buildJsonResponse(
      statusCode: HttpStatus.created,
      body: buildSecureApiSuccessBody(
        statusCode: HttpStatus.created,
        endpoint: policy.endpoint,
        message: 'Secure feedback submission recorded.',
        result: <String, Object?>{
          'submissionId': submissionId,
          'status': status,
          'hostApp': hostApp,
          'hostVersion': hostVersion,
          'userId': hostUserId,
          if (tenantId != null) 'tenantId': tenantId,
          'source': source,
          if (flow != null) 'flow': flow,
          'messagePreview': message.substring(
            0,
            message.length > 80 ? 80 : message.length,
          ),
        },
      ),
      traceId: traceId,
      extraHeaders: <String, String>{'x-secure-endpoint': policy.endpoint},
    );
  }

  Future<_SecureFeedbackPolicy> _loadPolicy() async {
    final file = File(
      path.join(apiRootPath, 'secure-api-policies', 'feedback_submit.json'),
    );
    if (!await file.exists()) {
      throw StateError(
        'Secure API policy not found at ${file.path}. Publish backend policy files before running secure_api flows.',
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'Secure API policy at ${file.path} does not contain a JSON object.',
      );
    }

    return _SecureFeedbackPolicy.fromJson(decoded);
  }

  Future<Object> _readJsonObject(
    Request request, {
    required String traceId,
    required String endpoint,
  }) async {
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return buildJsonResponse(
        statusCode: HttpStatus.badRequest,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.badRequest,
          errorCode: MiniProgramErrorCodes.secureApiInvalidPayload,
          message: 'Secure feedback submission body must be a JSON object.',
          extra: <String, Object?>{'endpoint': endpoint},
        ),
        traceId: traceId,
      );
    } on FormatException catch (error) {
      return buildJsonResponse(
        statusCode: HttpStatus.badRequest,
        body: buildBackendErrorBody(
          responseType: 'secure_api_error',
          statusCode: HttpStatus.badRequest,
          errorCode: MiniProgramErrorCodes.secureApiInvalidPayload,
          message: 'Secure feedback submission body is not valid JSON.',
          details: <String, Object?>{'reason': error.message},
          extra: <String, Object?>{'endpoint': endpoint},
        ),
        traceId: traceId,
      );
    }
  }

  bool _isExpiredToken(String accessToken, _SecureFeedbackPolicy policy) {
    return policy.expiredAccessTokenPrefixes.any(accessToken.startsWith);
  }
}

class _SecureFeedbackPolicy {
  const _SecureFeedbackPolicy({
    required this.endpoint,
    required this.allowedMethods,
    required this.allowedHosts,
    required this.allowedSources,
    required this.minimumMessageLength,
    required this.blockedUserIds,
    required this.expiredAccessTokenPrefixes,
  });

  factory _SecureFeedbackPolicy.fromJson(Map<String, dynamic> json) {
    return _SecureFeedbackPolicy(
      endpoint: json['endpoint'] as String,
      allowedMethods:
          (json['allowedMethods'] as List<dynamic>? ?? const ['POST'])
              .map((value) => value.toString().trim().toUpperCase())
              .where((value) => value.isNotEmpty)
              .toList(),
      allowedHosts: (json['allowedHosts'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      allowedSources: (json['allowedSources'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      minimumMessageLength: json['minimumMessageLength'] as int? ?? 12,
      blockedUserIds: (json['blockedUserIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      expiredAccessTokenPrefixes:
          (json['expiredAccessTokenPrefixes'] as List<dynamic>? ??
                  const <String>['expired-'])
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(),
    );
  }

  final String endpoint;
  final List<String> allowedMethods;
  final List<String> allowedHosts;
  final List<String> allowedSources;
  final int minimumMessageLength;
  final List<String> blockedUserIds;
  final List<String> expiredAccessTokenPrefixes;
}

String? _headerValue(Request request, String key) {
  final value = request.headers[key];
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _stringField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
