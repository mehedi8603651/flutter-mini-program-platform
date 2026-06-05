import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:path/path.dart' as p;

typedef PublisherBackendContractHttpClientFactory = http.Client Function();

class PublisherBackendContractInitRequest {
  const PublisherBackendContractInitRequest({
    required this.miniProgramRootPath,
    required this.appId,
    required this.backendBaseUri,
    required this.accessMode,
    this.healthEndpoint =
        MiniProgramPublisherBackendContract.defaultHealthEndpoint,
    this.outputPath,
    this.allowLocalHttp = false,
  });

  final String miniProgramRootPath;
  final String appId;
  final Uri backendBaseUri;
  final String accessMode;
  final String healthEndpoint;
  final String? outputPath;
  final bool allowLocalHttp;
}

class PublisherBackendContractInitResult {
  const PublisherBackendContractInitResult({
    required this.contractPath,
    required this.contract,
  });

  final String contractPath;
  final MiniProgramPublisherBackendContract contract;
}

class PublisherBackendContractValidateResult {
  const PublisherBackendContractValidateResult({
    required this.contractPath,
    required this.contract,
  });

  final String contractPath;
  final MiniProgramPublisherBackendContract contract;
}

class PublisherBackendContractSmokeRequest {
  const PublisherBackendContractSmokeRequest({
    required this.contractPath,
    required this.contract,
    this.accessKey,
    this.authToken,
    this.timeout = const Duration(seconds: 8),
  });

  final String contractPath;
  final MiniProgramPublisherBackendContract contract;
  final String? accessKey;
  final String? authToken;
  final Duration timeout;
}

class PublisherBackendContractSmokeResult {
  const PublisherBackendContractSmokeResult({
    required this.contractPath,
    required this.contract,
    required this.accessKeyProvided,
    required this.authTokenProvided,
    required this.passed,
    required this.routes,
  });

  final String contractPath;
  final MiniProgramPublisherBackendContract contract;
  final bool accessKeyProvided;
  final bool authTokenProvided;
  final bool passed;
  final List<PublisherBackendContractSmokeRouteResult> routes;
}

class PublisherBackendContractSmokeRouteResult {
  const PublisherBackendContractSmokeRouteResult({
    required this.id,
    required this.method,
    required this.endpoint,
    required this.uri,
    required this.expectedStatus,
    required this.expectJsonObject,
    required this.passed,
    this.statusCode,
    this.errorCode,
    this.message,
  });

  final String id;
  final String method;
  final String endpoint;
  final Uri uri;
  final int expectedStatus;
  final bool expectJsonObject;
  final bool passed;
  final int? statusCode;
  final String? errorCode;
  final String? message;
}

class PublisherBackendContractController {
  const PublisherBackendContractController({
    PublisherBackendContractHttpClientFactory? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? http.Client.new;

  final PublisherBackendContractHttpClientFactory _httpClientFactory;

  Future<PublisherBackendContractInitResult> init(
    PublisherBackendContractInitRequest request,
  ) async {
    final contract = MiniProgramPublisherBackendContract(
      appId: request.appId,
      backendBaseUri: request.backendBaseUri,
      accessMode: request.accessMode,
      healthEndpoint: request.healthEndpoint,
      allowLocalHttp: request.allowLocalHttp,
    );
    final contractPath = defaultContractPath(
      request.miniProgramRootPath,
      explicitPath: request.outputPath,
    );
    await Directory(p.dirname(contractPath)).create(recursive: true);
    await File(contractPath).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(contract.toJson())}\n',
    );
    return PublisherBackendContractInitResult(
      contractPath: contractPath,
      contract: contract,
    );
  }

  Future<PublisherBackendContractValidateResult> validate({
    required String miniProgramRootPath,
    required String? explicitContractPath,
    required bool allowLocalHttp,
  }) async {
    final contractPath = defaultContractPath(
      miniProgramRootPath,
      explicitPath: explicitContractPath,
    );
    final contract = await readContract(
      contractPath: contractPath,
      allowLocalHttp: allowLocalHttp,
    );
    return PublisherBackendContractValidateResult(
      contractPath: contractPath,
      contract: contract,
    );
  }

  Future<MiniProgramPublisherBackendContract> readContract({
    required String contractPath,
    required bool allowLocalHttp,
  }) async {
    final normalizedPath = p.normalize(p.absolute(contractPath));
    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw FormatException(
        'Publisher backend contract file does not exist: $normalizedPath',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    return MiniProgramPublisherBackendContract.fromJson(
      decoded,
      allowLocalHttp: allowLocalHttp,
    );
  }

  Future<PublisherBackendContractSmokeResult> smoke(
    PublisherBackendContractSmokeRequest request,
  ) async {
    final client = _httpClientFactory();
    final routes = <PublisherBackendContractSmokeRouteResult>[];
    try {
      for (final test in request.contract.smokeTests) {
        routes.add(
          await _runSmokeCase(
            client: client,
            request: request,
            smokeCase: test,
          ),
        );
      }
    } finally {
      client.close();
    }
    return PublisherBackendContractSmokeResult(
      contractPath: request.contractPath,
      contract: request.contract,
      accessKeyProvided: request.accessKey?.trim().isNotEmpty == true,
      authTokenProvided: request.authToken?.trim().isNotEmpty == true,
      passed: routes.every((route) => route.passed),
      routes: List.unmodifiable(routes),
    );
  }

  String defaultContractPath(
    String miniProgramRootPath, {
    String? explicitPath,
  }) {
    final explicit = explicitPath?.trim();
    return p.normalize(
      p.absolute(
        explicit != null && explicit.isNotEmpty
            ? explicit
            : p.join(miniProgramRootPath, 'publisher_backend.json'),
      ),
    );
  }

  Future<PublisherBackendContractSmokeRouteResult> _runSmokeCase({
    required http.Client client,
    required PublisherBackendContractSmokeRequest request,
    required MiniProgramPublisherBackendSmokeCase smokeCase,
  }) async {
    final uri = _resolve(request.contract.backendBaseUri, smokeCase.endpoint);
    try {
      final response = await _send(
        client: client,
        request: request,
        smokeCase: smokeCase,
        uri: uri,
      ).timeout(request.timeout);
      final expectation = smokeCase.expectation;
      final statusMatches = response.statusCode == expectation.expectedStatus;
      final jsonMatches =
          !expectation.expectJsonObject || _decodesToJsonObject(response.body);
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
        message: 'Timed out while calling publisher backend route.',
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
        message: 'Failed to reach publisher backend route: $error',
      );
    }
  }

  Future<http.Response> _send({
    required http.Client client,
    required PublisherBackendContractSmokeRequest request,
    required MiniProgramPublisherBackendSmokeCase smokeCase,
    required Uri uri,
  }) {
    final headers = _headers(request, smokeCase);
    final body = smokeCase.body.isEmpty ? null : jsonEncode(smokeCase.body);
    final effectiveHeaders = smokeCase.method == 'GET'
        ? headers
        : <String, String>{'content-type': 'application/json', ...headers};
    return switch (smokeCase.method) {
      'GET' => client.get(uri, headers: effectiveHeaders),
      'POST' => client.post(uri, headers: effectiveHeaders, body: body),
      'PUT' => client.put(uri, headers: effectiveHeaders, body: body),
      'PATCH' => client.patch(uri, headers: effectiveHeaders, body: body),
      'DELETE' => client.delete(uri, headers: effectiveHeaders, body: body),
      _ => client.get(uri, headers: effectiveHeaders),
    };
  }

  Map<String, String> _headers(
    PublisherBackendContractSmokeRequest request,
    MiniProgramPublisherBackendSmokeCase smokeCase,
  ) {
    final headers = <String, String>{
      'accept': 'application/json',
      MiniProgramPublisherBackendHeaders.appId: request.contract.appId,
      MiniProgramPublisherBackendHeaders.hostApp: 'miniprogram-tooling',
      MiniProgramPublisherBackendHeaders.hostVersion: 'local',
      MiniProgramPublisherBackendHeaders.sdkVersion: 'local',
      MiniProgramPublisherBackendHeaders.platform: 'cli',
      MiniProgramPublisherBackendHeaders.requestId: smokeCase.id,
      MiniProgramPublisherBackendHeaders.contractVersion:
          request.contract.contractVersion,
    };
    final accessKey = request.accessKey?.trim();
    if (accessKey != null && accessKey.isNotEmpty) {
      headers[MiniProgramPublisherBackendHeaders.accessKey] = accessKey;
    }
    final authToken = request.authToken?.trim();
    if (authToken != null && authToken.isNotEmpty) {
      headers[MiniProgramPublisherBackendHeaders.authorization] =
          authToken.toLowerCase().startsWith('bearer ')
          ? authToken
          : 'Bearer $authToken';
    }
    return headers;
  }

  Uri _resolve(Uri baseUri, String relativeEndpoint) {
    final baseUrl = baseUri.toString();
    final normalizedBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBaseUrl).resolve(relativeEndpoint);
  }

  bool _decodesToJsonObject(String body) {
    if (body.trim().isEmpty) {
      return true;
    }
    try {
      return jsonDecode(body) is Map;
    } catch (_) {
      return false;
    }
  }
}
