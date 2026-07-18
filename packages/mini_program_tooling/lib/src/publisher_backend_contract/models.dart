import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

typedef PublisherBackendContractHttpClientFactory = http.Client Function();

class PublisherBackendContractInitRequest {
  const PublisherBackendContractInitRequest({
    required this.miniProgramRootPath,
    required this.appId,
    required this.backendBaseUri,
    this.permissionReason =
        MiniProgramPublisherBackendContract.defaultPermissionReason,
    this.healthEndpoint =
        MiniProgramPublisherBackendContract.defaultHealthEndpoint,
    this.outputPath,
    this.allowLocalHttp = false,
  });

  final String miniProgramRootPath;
  final String appId;
  final Uri backendBaseUri;
  final String permissionReason;
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
    this.authToken,
    this.timeout = const Duration(seconds: 8),
  });

  final String contractPath;
  final MiniProgramPublisherBackendContract contract;
  final String? authToken;
  final Duration timeout;
}

class PublisherBackendContractSmokeResult {
  const PublisherBackendContractSmokeResult({
    required this.contractPath,
    required this.contract,
    required this.authTokenProvided,
    required this.passed,
    required this.routes,
  });

  final String contractPath;
  final MiniProgramPublisherBackendContract contract;
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
