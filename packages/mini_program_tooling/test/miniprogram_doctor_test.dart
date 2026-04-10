import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniprogramDoctor', () {
    late Directory tempDir;
    late Directory repoRoot;
    late LocalCliStateStore stateStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_doctor_',
      );
      repoRoot = Directory(p.join(tempDir.path, 'repo'));
      await Directory(
        p.join(repoRoot.path, 'backend', 'api'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'mini_programs'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'backend', 'local_backend_service', 'bin'),
      ).create(recursive: true);
      await File(
        p.join(
          repoRoot.path,
          'backend',
          'local_backend_service',
          'bin',
          'server.dart',
        ),
      ).writeAsString('void main() {}');
      await Directory(
        p.join(repoRoot.path, 'packages', 'mini_program_tooling'),
      ).create(recursive: true);
      await File(
        p.join(
          repoRoot.path,
          'packages',
          'mini_program_tooling',
          'pubspec.yaml',
        ),
      ).writeAsString('name: mini_program_tooling');
      stateStore = LocalCliStateStore(
        homeDirectoryPath: p.join(tempDir.path, 'fake_home'),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reports ok checks for env, repo root, and healthy backend', () async {
      final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await workspaceRoot.create(recursive: true);
      final now = DateTime.utc(2026, 4, 10).toIso8601String();
      await stateStore.writeEnvironmentState(
        workspaceRoot.path,
        LocalCliEnvironmentState(
          schemaVersion: 1,
          repoRootPath: repoRoot.path,
          activeEnvironment: 'local',
          initializedAtUtc: now,
          updatedAtUtc: now,
        ),
      );

      final doctor = MiniprogramDoctor(
        stateStore: stateStore,
        backendController: _HealthyBackendController(repoRoot.path),
        shellRunner: _okShellRunner,
        workingDirectory: workspaceRoot.path,
      );

      final result = await doctor.diagnose();

      expect(result.hasErrors, isFalse);
      expect(
        result.checks.any(
          (check) =>
              check.label == 'Env config' &&
              check.status == MiniprogramDoctorCheckStatus.ok,
        ),
        isTrue,
      );
      expect(
        result.checks.any(
          (check) =>
              check.label == 'Backend status' &&
              check.status == MiniprogramDoctorCheckStatus.ok,
        ),
        isTrue,
      );
    });

    test('warns when env config and repo root are missing', () async {
      final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await workspaceRoot.create(recursive: true);

      final doctor = MiniprogramDoctor(
        stateStore: stateStore,
        backendController: const LocalBackendController(),
        shellRunner: _missingShellRunner,
        workingDirectory: workspaceRoot.path,
      );

      final result = await doctor.diagnose();

      expect(result.hasErrors, isFalse);
      expect(
        result.checks.any(
          (check) =>
              check.label == 'Env config' &&
              check.status == MiniprogramDoctorCheckStatus.warning,
        ),
        isTrue,
      );
      expect(
        result.checks.any(
          (check) =>
              check.label == 'Platform repo' &&
              check.status == MiniprogramDoctorCheckStatus.skipped,
        ),
        isTrue,
      );
      expect(
        result.checks.any(
          (check) =>
              check.label == 'Backend status' &&
              check.status == MiniprogramDoctorCheckStatus.skipped,
        ),
        isTrue,
      );
    });

    test(
      'uses a saved backend workspace even when no repo root is resolved',
      () async {
        final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
        await workspaceRoot.create(recursive: true);
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        final backendState = LocalBackendWorkspaceState(
          schemaVersion: 1,
          backendRootPath: backendRoot,
          apiRootPath: p.join(backendRoot, 'backend', 'api'),
          serviceDirectoryPath: p.join(
            backendRoot,
            'backend',
            'local_backend_service',
          ),
          initializedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
        );
        await stateStore.writeGlobalBackendWorkspaceState(backendState);
        await Directory(
          p.join(backendRoot, 'backend', 'api'),
        ).create(recursive: true);
        await Directory(
          p.join(backendRoot, 'backend', 'local_backend_service', 'bin'),
        ).create(recursive: true);
        await File(
          p.join(
            backendRoot,
            'backend',
            'local_backend_service',
            'bin',
            'server.dart',
          ),
        ).writeAsString('void main() {}');

        final doctor = MiniprogramDoctor(
          stateStore: stateStore,
          backendController: _HealthyBackendController(backendRoot),
          shellRunner: _okShellRunner,
          workingDirectory: workspaceRoot.path,
        );

        final result = await doctor.diagnose();

        expect(result.hasErrors, isFalse);
        expect(
          result.checks.any(
            (check) =>
                check.label == 'Backend workspace' &&
                check.status == MiniprogramDoctorCheckStatus.ok,
          ),
          isTrue,
        );
        expect(
          result.checks.any(
            (check) =>
                check.label == 'Backend status' &&
                check.status == MiniprogramDoctorCheckStatus.ok,
          ),
          isTrue,
        );
      },
    );
  });
}

Future<ProcessResult> _okShellRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final versionLine = switch (executable) {
    'flutter' => 'Flutter 3.35.0',
    'stac' => 'stac 1.0.0',
    _ => '$executable ok',
  };
  return ProcessResult(1, 0, versionLine, '');
}

Future<ProcessResult> _missingShellRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) {
  throw ProcessException(executable, arguments, 'not found', 1);
}

class _HealthyBackendController extends LocalBackendController {
  const _HealthyBackendController(this.repoRootPath);

  final String repoRootPath;

  @override
  Future<LocalBackendStatusResult> status({
    required String repoRootPath,
  }) async {
    return LocalBackendStatusResult(
      state: LocalBackendState(
        pid: 1234,
        port: 8080,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:8080/health',
        stdoutLogPath: p.join(repoRootPath, '.mini_program', 'backend.out.log'),
        stderrLogPath: p.join(repoRootPath, '.mini_program', 'backend.err.log'),
        startedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
      ),
      hasState: true,
      processAlive: true,
      healthy: true,
      healthStatusCode: 200,
    );
  }
}
