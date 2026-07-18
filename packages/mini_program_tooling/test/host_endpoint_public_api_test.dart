import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('host endpoint public API remains available from the barrel', () {
    final controller = MiniProgramHostController(
      processRunner:
          (
            String executable,
            List<String> arguments, {
            String? workingDirectory,
            Map<String, String>? environment,
          }) async => 0,
    );
    const runRequest = MiniProgramHostRunRequest(
      projectRootPath: 'host',
      deviceId: 'android',
      backendApiBaseUrl: '',
    );
    const runResult = MiniProgramHostRunResult(
      projectRootPath: 'host',
      deviceId: 'android',
      backendApiBaseUrl: '',
      invocation: <String>['run', '-d', 'android'],
      exitCode: 0,
    );
    final endpointRequest = MiniProgramHostEndpointAddRequest(
      projectRootPath: 'host',
      appId: 'calculator',
      apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
    );
    final endpointResult = MiniProgramHostEndpointAddResult(
      projectRootPath: 'host',
      filePath: 'mini_program_endpoints.dart',
      registryFilePath: 'mini_program_registry.dart',
      policyFilePath: 'mini_program_policies.json',
      policyResolverFilePath: 'mini_program_policy_resolver.dart',
      appId: 'calculator',
      title: 'Calculator',
      apiBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
      endpointCount: 1,
      registryCount: 1,
      created: true,
      updated: false,
    );
    const error = MiniProgramHostException('failure');

    expect(controller, isA<MiniProgramHostController>());
    expect(runRequest.deviceId, 'android');
    expect(runResult.invocation, <String>['run', '-d', 'android']);
    expect(endpointRequest.acceptRequestedPolicy, isFalse);
    expect(endpointResult.endpointCount, 1);
    expect(error.toString(), 'failure');
  });
}
