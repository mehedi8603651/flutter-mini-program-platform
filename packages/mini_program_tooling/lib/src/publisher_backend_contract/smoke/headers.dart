import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../models.dart';

Map<String, String> publisherBackendSmokeHeaders(
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
  final authToken = request.authToken?.trim();
  if (authToken != null && authToken.isNotEmpty) {
    headers[MiniProgramPublisherBackendHeaders.authorization] =
        authToken.toLowerCase().startsWith('bearer ')
        ? authToken
        : 'Bearer $authToken';
  }
  return headers;
}
