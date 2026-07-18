import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('MiniProgramWorkflowStatusController parity', () {
    late Directory tempDirectory;
    late LocalCliStateStore stateStore;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_workflow_status_parity_',
      );
      stateStore = LocalCliStateStore(
        homeDirectoryPath: path.join(tempDirectory.path, 'home'),
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('preserves unknown workspace JSON order and assessment', () async {
      final workspacePath = path.join(tempDirectory.path, 'missing');
      final result = await MiniProgramWorkflowStatusController(
        stateStore: stateStore,
      ).inspect(MiniProgramWorkflowStatusRequest(workspacePath: workspacePath));

      expect(result.json.keys.toList(), <String>[
        'schemaVersion',
        'command',
        'generatedAtUtc',
        'workspace',
        'environment',
        'miniProgram',
        'hostApp',
        'backend',
        'remote',
        'ready',
        'severity',
        'nextActions',
      ]);
      expect(result.ready, isFalse);
      expect(result.severity, 'warning');
      expect(result.json['workspace'], <String, Object?>{
        'path': path.normalize(path.absolute(workspacePath)),
        'exists': false,
        'type': 'unknown',
      });
      expect(result.json['environment'], <String, Object?>{
        'configured': false,
      });
      expect(result.json['backend'], <String, Object?>{
        'configured': false,
        'statusChecked': false,
      });
      expect(result.json['remote'], <String, Object?>{'checked': false});
      expect(result.json['nextActions'], <String>[
        'Open a mini-program or Flutter host app workspace.',
      ]);
    });

    test('preserves backend status JSON order and state projection', () {
      const state = LocalBackendState(
        pid: 19,
        port: 9090,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:9090/health',
        stdoutLogPath: 'out.log',
        stderrLogPath: 'err.log',
        startedAtUtc: '2026-07-18T12:00:00.000Z',
      );
      final json = miniProgramWorkflowStatusBackendJson(
        const LocalBackendStatusResult(
          state: state,
          hasState: true,
          processAlive: true,
          healthy: false,
          healthStatusCode: 503,
          healthError: 'Health endpoint returned 503.',
        ),
      );

      expect(json.keys.toList(), <String>[
        'hasState',
        'processAlive',
        'healthy',
        'healthStatusCode',
        'healthError',
        'state',
      ]);
      expect((json['state'] as Map).keys.toList(), <String>[
        'pid',
        'port',
        'bindHost',
        'healthCheckUrl',
        'stdoutLogPath',
        'stderrLogPath',
        'startedAtUtc',
      ]);
    });
  });
}
