import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'publisher_backend_contract/files.dart';
import 'publisher_backend_contract/models.dart';
import 'publisher_backend_contract/operations.dart';
import 'publisher_backend_contract/paths.dart';
import 'publisher_backend_contract/smoke/coordinator.dart';

export 'publisher_backend_contract/models.dart'
    show
        PublisherBackendContractHttpClientFactory,
        PublisherBackendContractInitRequest,
        PublisherBackendContractInitResult,
        PublisherBackendContractSmokeRequest,
        PublisherBackendContractSmokeResult,
        PublisherBackendContractSmokeRouteResult,
        PublisherBackendContractValidateResult;

/// Public compatibility facade for Publisher API contract workflows.
class PublisherBackendContractController {
  const PublisherBackendContractController({
    PublisherBackendContractHttpClientFactory? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? http.Client.new;

  final PublisherBackendContractHttpClientFactory _httpClientFactory;

  Future<PublisherBackendContractInitResult> init(
    PublisherBackendContractInitRequest request,
  ) => initializePublisherBackendContract(request);

  Future<PublisherBackendContractValidateResult> validate({
    required String miniProgramRootPath,
    required String? explicitContractPath,
    required bool allowLocalHttp,
  }) => validatePublisherBackendContract(
    miniProgramRootPath: miniProgramRootPath,
    explicitContractPath: explicitContractPath,
    allowLocalHttp: allowLocalHttp,
  );

  Future<MiniProgramPublisherBackendContract> readContract({
    required String contractPath,
    required bool allowLocalHttp,
  }) => readPublisherBackendContract(
    contractPath: contractPath,
    allowLocalHttp: allowLocalHttp,
  );

  Future<PublisherBackendContractSmokeResult> smoke(
    PublisherBackendContractSmokeRequest request,
  ) => smokePublisherBackendContract(_httpClientFactory, request);

  String defaultContractPath(
    String miniProgramRootPath, {
    String? explicitPath,
  }) => resolvePublisherBackendContractPath(
    miniProgramRootPath,
    explicitPath: explicitPath,
  );
}
