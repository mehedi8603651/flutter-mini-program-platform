import 'package:http/http.dart' as http;
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_tooling/src/publisher_backend_contract_controller.dart';
import 'package:test/test.dart';

void main() {
  test('Publisher API contract controller API remains available', () {
    final contract = MiniProgramPublisherBackendContract(
      appId: 'weather',
      backendBaseUri: Uri.parse('https://api.example.com'),
    );
    final request = PublisherBackendContractInitRequest(
      miniProgramRootPath: 'weather',
      appId: 'weather',
      backendBaseUri: Uri.parse('https://api.example.com'),
    );
    final smokeRequest = PublisherBackendContractSmokeRequest(
      contractPath: 'publisher_backend.json',
      contract: contract,
    );
    final route = PublisherBackendContractSmokeRouteResult(
      id: 'health',
      method: 'GET',
      endpoint: 'health',
      uri: Uri.parse('https://api.example.com/health'),
      expectedStatus: 200,
      expectJsonObject: true,
      passed: true,
      statusCode: 200,
    );
    final smokeResult = PublisherBackendContractSmokeResult(
      contractPath: smokeRequest.contractPath,
      contract: contract,
      authTokenProvided: false,
      passed: true,
      routes: <PublisherBackendContractSmokeRouteResult>[route],
    );
    final initResult = PublisherBackendContractInitResult(
      contractPath: smokeRequest.contractPath,
      contract: contract,
    );
    final validateResult = PublisherBackendContractValidateResult(
      contractPath: smokeRequest.contractPath,
      contract: contract,
    );
    PublisherBackendContractHttpClientFactory factory = http.Client.new;
    final controller = PublisherBackendContractController(
      httpClientFactory: factory,
    );

    expect(request.appId, 'weather');
    expect(initResult.contract, same(contract));
    expect(validateResult.contract, same(contract));
    expect(smokeResult.routes.single, same(route));
    expect(controller, isA<PublisherBackendContractController>());
  });
}
