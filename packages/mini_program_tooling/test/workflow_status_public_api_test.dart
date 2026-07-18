import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('workflow status public API remains available from the barrel', () {
    const request = MiniProgramWorkflowStatusRequest(
      workspacePath: 'workspace',
      environmentName: 'local',
      remote: true,
    );
    const result = MiniProgramWorkflowStatusResult(<String, Object?>{
      'ready': true,
      'severity': 'ok',
    });
    const controller = MiniProgramWorkflowStatusController();
    const backendState = LocalBackendState(
      pid: 7,
      port: 8080,
      bindHost: '0.0.0.0',
      healthCheckUrl: 'http://127.0.0.1:8080/health',
      stdoutLogPath: 'stdout.log',
      stderrLogPath: 'stderr.log',
      startedAtUtc: '2026-07-18T00:00:00.000Z',
    );
    final backendJson = miniProgramWorkflowStatusBackendJson(
      const LocalBackendStatusResult(
        state: backendState,
        hasState: true,
        processAlive: true,
        healthy: true,
        healthStatusCode: 200,
      ),
    );

    expect(request.remote, isTrue);
    expect(result.ready, isTrue);
    expect(result.severity, 'ok');
    expect(controller, isA<MiniProgramWorkflowStatusController>());
    expect((backendJson['state'] as Map)['pid'], 7);
  });
}
