import 'package:mini_program_contracts/mini_program_contracts.dart';

import 'files.dart';
import 'models.dart';
import 'paths.dart';

Future<PublisherBackendContractInitResult> initializePublisherBackendContract(
  PublisherBackendContractInitRequest request,
) async {
  final contract = MiniProgramPublisherBackendContract(
    appId: request.appId,
    backendBaseUri: request.backendBaseUri,
    permissionReason: request.permissionReason,
    healthEndpoint: request.healthEndpoint,
    allowLocalHttp: request.allowLocalHttp,
  );
  final contractPath = resolvePublisherBackendContractPath(
    request.miniProgramRootPath,
    explicitPath: request.outputPath,
  );
  await writePublisherBackendContract(contractPath, contract);
  return PublisherBackendContractInitResult(
    contractPath: contractPath,
    contract: contract,
  );
}

Future<PublisherBackendContractValidateResult>
validatePublisherBackendContract({
  required String miniProgramRootPath,
  required String? explicitContractPath,
  required bool allowLocalHttp,
}) async {
  final contractPath = resolvePublisherBackendContractPath(
    miniProgramRootPath,
    explicitPath: explicitContractPath,
  );
  final contract = await readPublisherBackendContract(
    contractPath: contractPath,
    allowLocalHttp: allowLocalHttp,
  );
  return PublisherBackendContractValidateResult(
    contractPath: contractPath,
    contract: contract,
  );
}
