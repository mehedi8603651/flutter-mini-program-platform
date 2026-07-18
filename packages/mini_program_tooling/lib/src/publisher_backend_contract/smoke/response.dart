import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../models.dart';
import 'transport.dart';

Future<PublisherBackendContractSmokeRouteResult> runPublisherBackendSmokeCase({
  required http.Client client,
  required PublisherBackendContractSmokeRequest request,
  required MiniProgramPublisherBackendSmokeCase smokeCase,
}) async {
  final uri = resolvePublisherBackendSmokeUri(
    request.contract.backendBaseUri,
    smokeCase.endpoint,
  );
  try {
    final response = await sendPublisherBackendSmokeRequest(
      client: client,
      request: request,
      smokeCase: smokeCase,
      uri: uri,
    ).timeout(request.timeout);
    final expectation = smokeCase.expectation;
    final statusMatches = response.statusCode == expectation.expectedStatus;
    final jsonMatches =
        !expectation.expectJsonObject ||
        publisherBackendResponseDecodesToJsonObject(response.body);
    final passed = statusMatches && jsonMatches;
    return PublisherBackendContractSmokeRouteResult(
      id: smokeCase.id,
      method: smokeCase.method,
      endpoint: smokeCase.endpoint,
      uri: uri,
      expectedStatus: expectation.expectedStatus,
      expectJsonObject: expectation.expectJsonObject,
      statusCode: response.statusCode,
      passed: passed,
      errorCode: passed
          ? null
          : !statusMatches
          ? MiniProgramPublisherBackendErrorCodes.unexpectedStatus
          : MiniProgramPublisherBackendErrorCodes.invalidJson,
      message: passed
          ? null
          : !statusMatches
          ? 'Expected HTTP ${expectation.expectedStatus}, got HTTP ${response.statusCode}.'
          : 'Expected a JSON object response.',
    );
  } on TimeoutException {
    return PublisherBackendContractSmokeRouteResult(
      id: smokeCase.id,
      method: smokeCase.method,
      endpoint: smokeCase.endpoint,
      uri: uri,
      expectedStatus: smokeCase.expectation.expectedStatus,
      expectJsonObject: smokeCase.expectation.expectJsonObject,
      passed: false,
      errorCode: MiniProgramPublisherBackendErrorCodes.timeout,
      message: 'Timed out while calling Publisher API route.',
    );
  } catch (error) {
    return PublisherBackendContractSmokeRouteResult(
      id: smokeCase.id,
      method: smokeCase.method,
      endpoint: smokeCase.endpoint,
      uri: uri,
      expectedStatus: smokeCase.expectation.expectedStatus,
      expectJsonObject: smokeCase.expectation.expectJsonObject,
      passed: false,
      errorCode: MiniProgramPublisherBackendErrorCodes.unreachable,
      message: 'Failed to reach Publisher API route: $error',
    );
  }
}

bool publisherBackendResponseDecodesToJsonObject(String body) {
  if (body.trim().isEmpty) {
    return true;
  }
  try {
    return jsonDecode(body) is Map;
  } catch (_) {
    return false;
  }
}
