import '../models.dart';
import 'response.dart';

Future<PublisherBackendContractSmokeResult> smokePublisherBackendContract(
  PublisherBackendContractHttpClientFactory httpClientFactory,
  PublisherBackendContractSmokeRequest request,
) async {
  final client = httpClientFactory();
  final routes = <PublisherBackendContractSmokeRouteResult>[];
  try {
    for (final test in request.contract.smokeTests) {
      routes.add(
        await runPublisherBackendSmokeCase(
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
    authTokenProvided: request.authToken?.trim().isNotEmpty == true,
    passed: routes.every((route) => route.passed),
    routes: List.unmodifiable(routes),
  );
}
