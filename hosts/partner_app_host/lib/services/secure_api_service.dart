import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'auth_session_service.dart';

abstract interface class SecureApiService {
  Future<HostActionResult> call(CallSecureApiActionPayload payload);
}

class BackendSecureApiService implements SecureApiService {
  BackendSecureApiService({
    required this.apiBaseUri,
    required this.authSessionService,
    required this.hostAppId,
    required this.hostVersion,
    this.requestTimeout = const Duration(seconds: 8),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri apiBaseUri;
  final AuthSessionService authSessionService;
  final String hostAppId;
  final String hostVersion;
  final Duration requestTimeout;
  final http.Client _client;

  @override
  Future<HostActionResult> call(CallSecureApiActionPayload payload) async {
    final method = payload.method.trim().toUpperCase();
    if (payload.endpoint != 'feedback/submit' || method != 'POST') {
      return _policyFailure(
        payload: payload,
        message:
            'Secure API request "${payload.endpoint}" ($method) is not allowlisted in $hostAppId.',
      );
    }

    final HostSession session;
    try {
      session = await authSessionService.getCurrentSession();
    } on AuthSessionException catch (error) {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        errorCode: error.errorCode,
        message: error.message,
        data: <String, dynamic>{
          'failureCategory': 'auth',
          'retryable': false,
          ...error.details,
        },
      );
    }

    final uri = _resolve('secure/feedback/submit');

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'accept': 'application/json',
              'content-type': 'application/json',
              'authorization': 'Bearer ${session.accessToken}',
              'x-host-app': hostAppId,
              'x-host-version': hostVersion,
              'x-host-user-id': session.userId,
              if (session.tenantId != null)
                'x-host-tenant-id': session.tenantId!,
            },
            body: jsonEncode(payload.body),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        errorCode: MiniProgramErrorCodes.backendTimeout,
        message:
            'Secure API request "${payload.endpoint}" timed out after ${requestTimeout.inSeconds} seconds.',
        data: <String, dynamic>{
          'failureCategory': 'transport',
          'retryable': true,
          'timeoutMs': requestTimeout.inMilliseconds,
          'endpoint': payload.endpoint,
        },
      );
    } catch (error) {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        errorCode: MiniProgramErrorCodes.backendUnreachable,
        message:
            'Failed to reach the secure backend for "${payload.endpoint}": $error',
        data: <String, dynamic>{
          'failureCategory': 'transport',
          'retryable': true,
          'endpoint': payload.endpoint,
          'transportError': error.toString(),
        },
      );
    }

    final decodedBody = _tryDecodeJsonObject(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return HostActionResult.success(
        actionName: ActionNames.callSecureApi,
        message:
            decodedBody?['message']?.toString() ??
            'Secure API call succeeded for "${payload.endpoint}".',
        data:
            decodedBody ??
            <String, dynamic>{
              'statusCode': response.statusCode,
              'retryable': false,
            },
      );
    }

    final errorCode = decodedBody?['errorCode']?.toString();
    return HostActionResult.failed(
      actionName: ActionNames.callSecureApi,
      errorCode: errorCode,
      message:
          decodedBody?['message']?.toString() ??
          'Secure API call failed for "${payload.endpoint}" (HTTP ${response.statusCode}).',
      data: <String, dynamic>{
        'statusCode': response.statusCode,
        'failureCategory': _classifyFailure(errorCode, response.statusCode),
        'retryable': _isRetryable(errorCode, response.statusCode),
        if (decodedBody != null) ...decodedBody,
      },
    );
  }

  HostActionResult _policyFailure({
    required CallSecureApiActionPayload payload,
    required String message,
  }) {
    return HostActionResult.failed(
      actionName: ActionNames.callSecureApi,
      errorCode: MiniProgramErrorCodes.secureApiNotAllowlisted,
      message: message,
      data: <String, dynamic>{
        'failureCategory': 'policy',
        'retryable': false,
        'endpoint': payload.endpoint,
        'method': payload.method.trim().toUpperCase(),
      },
    );
  }

  Uri _resolve(String relativePath) {
    final baseUrl = apiBaseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBaseUrl).resolve(relativePath);
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Keep non-JSON backend responses as generic failures.
    }

    return null;
  }

  String _classifyFailure(String? errorCode, int statusCode) {
    switch (errorCode) {
      case MiniProgramErrorCodes.secureApiSessionMissing:
      case MiniProgramErrorCodes.secureApiSessionExpired:
      case MiniProgramErrorCodes.secureApiUnauthorized:
        return 'auth';
      case MiniProgramErrorCodes.secureApiForbidden:
      case MiniProgramErrorCodes.secureApiNotAllowlisted:
        return 'policy';
      case MiniProgramErrorCodes.secureApiInvalidPayload:
      case MiniProgramErrorCodes.secureApiValidationFailed:
        return 'validation';
      case MiniProgramErrorCodes.backendTimeout:
      case MiniProgramErrorCodes.backendUnreachable:
        return 'transport';
    }

    if (statusCode >= 500) {
      return 'transport';
    }

    return 'unknown';
  }

  bool _isRetryable(String? errorCode, int statusCode) {
    switch (errorCode) {
      case MiniProgramErrorCodes.backendTimeout:
      case MiniProgramErrorCodes.backendUnreachable:
        return true;
      case MiniProgramErrorCodes.secureApiSessionMissing:
      case MiniProgramErrorCodes.secureApiSessionExpired:
      case MiniProgramErrorCodes.secureApiUnauthorized:
      case MiniProgramErrorCodes.secureApiForbidden:
      case MiniProgramErrorCodes.secureApiInvalidPayload:
      case MiniProgramErrorCodes.secureApiValidationFailed:
      case MiniProgramErrorCodes.secureApiNotAllowlisted:
        return false;
    }

    return statusCode >= 500 || statusCode == 408 || statusCode == 429;
  }
}
