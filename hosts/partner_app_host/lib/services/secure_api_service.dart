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
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri apiBaseUri;
  final AuthSessionService authSessionService;
  final String hostAppId;
  final String hostVersion;
  final http.Client _client;

  @override
  Future<HostActionResult> call(CallSecureApiActionPayload payload) async {
    final method = payload.method.trim().toUpperCase();
    if (payload.endpoint != 'feedback/submit') {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        message:
            'Secure API endpoint "${payload.endpoint}" is not allowlisted in partner_app_host.',
      );
    }

    if (method != 'POST') {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        message:
            'Secure API endpoint "${payload.endpoint}" only supports POST in partner_app_host.',
      );
    }

    final session = await authSessionService.getCurrentSession();
    final uri = _resolve('secure/feedback/submit');

    late final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: <String, String>{
          'accept': 'application/json',
          'content-type': 'application/json',
          'authorization': 'Bearer ${session.accessToken}',
          'x-host-app': hostAppId,
          'x-host-version': hostVersion,
          'x-host-user-id': session.userId,
          if (session.tenantId != null) 'x-host-tenant-id': session.tenantId!,
        },
        body: jsonEncode(payload.body),
      );
    } catch (error) {
      return HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        errorCode: 'backend_unreachable',
        message:
            'Failed to reach the secure backend for "${payload.endpoint}": $error',
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
            decodedBody ?? <String, dynamic>{'statusCode': response.statusCode},
      );
    }

    return HostActionResult.failed(
      actionName: ActionNames.callSecureApi,
      errorCode: decodedBody?['errorCode']?.toString(),
      message:
          decodedBody?['message']?.toString() ??
          'Secure API call failed for "${payload.endpoint}" (HTTP ${response.statusCode}).',
      data: <String, dynamic>{
        'statusCode': response.statusCode,
        if (decodedBody != null) ...decodedBody,
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
}
