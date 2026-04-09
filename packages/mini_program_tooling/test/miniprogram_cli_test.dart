import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniprogramCli', () {
    late Directory tempDir;
    late Directory repoRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_cli_',
      );
      repoRoot = Directory(p.join(tempDir.path, 'repo'));
      await Directory(
        p.join(repoRoot.path, 'backend', 'api'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'mini_programs'),
      ).create(recursive: true);
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
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('create uses standalone ./<id> output by default', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        workingDirectory: tempDir.path,
      );

      final exitCode = await cli.run(<String>['create', 'coupon_center']);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);
      expect(
        await File(
          p.join(tempDir.path, 'coupon_center', 'manifest.json'),
        ).exists(),
        isTrue,
      );
      expect(
        stdoutBuffer.toString(),
        contains('Created mini-program scaffold'),
      );
    });

    test('build resolves a repo-managed mini-program from repo root', () async {
      final miniProgramRoot = p.join(
        repoRoot.path,
        'mini_programs',
        'coupon_center',
      );
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final fakeCliPath = p.join(repoRoot.path, 'fake_stac_cli.dart');
      await File(fakeCliPath).writeAsString(_fakeStacCliSource);

      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: repoRoot.path,
      );

      final exitCode = await cli.run(<String>[
        'build',
        'coupon_center',
        '--stac-cli-script',
        fakeCliPath,
        '--skip-pub-get',
      ]);

      expect(exitCode, 0);
      expect(
        stdoutBuffer.toString(),
        contains('Built mini-program: coupon_center'),
      );
      expect(
        await File(
          p.join(
            miniProgramRoot,
            'stac',
            '.build',
            'screens',
            'coupon_center_home.json',
          ),
        ).exists(),
        isTrue,
      );
    });

    test('env init, use, and status manage active environment state', () async {
      final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await workspaceRoot.create(recursive: true);

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        workingDirectory: workspaceRoot.path,
      );

      expect(
        await cli.run(<String>['env', 'init', '--repo-root', repoRoot.path]),
        0,
      );
      expect(
        await File(
          p.join(workspaceRoot.path, '.mini_program', 'env.json'),
        ).exists(),
        isTrue,
      );

      expect(await cli.run(<String>['env', 'use', 'cloud']), 0);

      final statusBuffer = StringBuffer();
      final statusCli = MiniprogramCli(
        stdoutSink: statusBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: workspaceRoot.path,
      );
      expect(await statusCli.run(<String>['env', 'status']), 0);
      expect(statusBuffer.toString(), contains('Active environment: cloud'));
      expect(stderrBuffer.toString(), isEmpty);
    });

    test(
      'build reports a missing mini-program root without throwing',
      () async {
        final stdoutBuffer = StringBuffer();
        final stderrBuffer = StringBuffer();
        final cli = MiniprogramCli(
          stdoutSink: stdoutBuffer,
          stderrSink: stderrBuffer,
          workingDirectory: tempDir.path,
        );

        final exitCode = await cli.run(<String>[
          'build',
          'coupon_center',
          '--mini-program-root',
          p.join(tempDir.path, 'missing_coupon_center'),
          '--repo-root',
          repoRoot.path,
        ]);

        expect(exitCode, 1);
        expect(stdoutBuffer.toString(), isEmpty);
        expect(
          stderrBuffer.toString(),
          contains('No usable manifest.json matching "coupon_center"'),
        );
      },
    );

    test('validate works against a repo-managed mini-program', () async {
      final miniProgramRoot = p.join(
        repoRoot.path,
        'mini_programs',
        'coupon_center',
      );
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );

      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: repoRoot.path,
      );

      final exitCode = await cli.run(<String>['validate', 'coupon_center']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Repo root:'));
    });

    test('publish tracks local artifact state', () async {
      final miniProgramRoot = p.join(
        repoRoot.path,
        'mini_programs',
        'coupon_center',
      );
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'coupon_center',
        version: '1.2.0',
      );
      final fakeCliPath = p.join(repoRoot.path, 'fake_stac_cli.dart');
      await File(fakeCliPath).writeAsString(_fakeStacCliSource);

      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: repoRoot.path,
      );

      final exitCode = await cli.run(<String>[
        'publish',
        'coupon_center',
        '--stac-cli-script',
        fakeCliPath,
        '--skip-build-pub-get',
      ]);

      expect(exitCode, 0);
      expect(
        stdoutBuffer.toString(),
        contains('Published mini-program: coupon_center'),
      );
      expect(
        await File(
          p.join(
            repoRoot.path,
            '.mini_program',
            'published_local_artifacts.json',
          ),
        ).exists(),
        isTrue,
      );
    });

    test(
      'publish uses saved env repo root from a standalone mini-program root',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.2.0',
        );
        final fakeCliPath = p.join(repoRoot.path, 'fake_stac_cli.dart');
        await File(fakeCliPath).writeAsString(_fakeStacCliSource);

        final cli = MiniprogramCli(
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );

        expect(
          await cli.run(<String>['env', 'init', '--repo-root', repoRoot.path]),
          0,
        );

        final publishBuffer = StringBuffer();
        final publishCli = MiniprogramCli(
          stdoutSink: publishBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );
        final exitCode = await publishCli.run(<String>[
          'publish',
          'coupon_center',
          '--stac-cli-script',
          fakeCliPath,
          '--skip-build-pub-get',
        ]);

        expect(exitCode, 0);
        expect(
          publishBuffer.toString(),
          contains('Published mini-program: coupon_center'),
        );
        expect(
          await File(
            p.join(
              repoRoot.path,
              '.mini_program',
              'published_local_artifacts.json',
            ),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(
              repoRoot.path,
              'backend',
              'api',
              'manifests',
              'coupon_center',
              'latest.json',
            ),
          ).exists(),
          isTrue,
        );
      },
    );

    test('embed init generates the embedding adapter', () async {
      final projectRoot = p.join(tempDir.path, 'host_app');
      await Directory(p.join(projectRoot, 'lib')).create(recursive: true);
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: host_app
version: 1.0.0+1
''');

      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: repoRoot.path,
      );

      final exitCode = await cli.run(<String>[
        'embed',
        'init',
        '--project-root',
        projectRoot,
        '--repo-root',
        repoRoot.path,
      ]);

      expect(exitCode, 0);
      expect(
        stdoutBuffer.toString(),
        contains('Initialized embedded mini-program adapter'),
      );
      expect(
        await File(
          p.join(projectRoot, 'lib', 'mini_program', 'mini_program.dart'),
        ).exists(),
        isTrue,
      );
    });

    test('backend subcommands dispatch to the controller', () async {
      final controller = _FakeLocalBackendController();
      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        backendController: controller,
        workingDirectory: repoRoot.path,
      );

      expect(await cli.run(<String>['backend', 'start', '--port', '9090']), 0);
      expect(controller.startedPort, 9090);

      expect(await cli.run(<String>['backend', 'status']), 0);
      expect(await cli.run(<String>['backend', 'stop']), 0);
      expect(await cli.run(<String>['backend', 'reset-local', '--yes']), 0);
      expect(controller.calls, <String>[
        'start',
        'status',
        'stop',
        'reset-local',
      ]);
      expect(stdoutBuffer.toString(), contains('Started local backend.'));
    });

    test(
      'backend commands use saved env repo root when run from a standalone workspace',
      () async {
        final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
        await workspaceRoot.create(recursive: true);

        final cli = MiniprogramCli(
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: workspaceRoot.path,
        );
        expect(
          await cli.run(<String>['env', 'init', '--repo-root', repoRoot.path]),
          0,
        );

        final controller = _FakeLocalBackendController();
        final backendCli = MiniprogramCli(
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          backendController: controller,
          workingDirectory: workspaceRoot.path,
        );

        expect(await backendCli.run(<String>['backend', 'start']), 0);
        expect(await backendCli.run(<String>['backend', 'status']), 0);
        expect(await backendCli.run(<String>['backend', 'stop']), 0);
        expect(controller.repoRootPaths, everyElement(repoRoot.path));
      },
    );
  });
}

class _FakeLocalBackendController extends LocalBackendController {
  final List<String> calls = <String>[];
  final List<String> repoRootPaths = <String>[];
  int? startedPort;

  @override
  Future<LocalBackendStartResult> start({
    required String repoRootPath,
    int port = 8080,
  }) async {
    calls.add('start');
    repoRootPaths.add(repoRootPath);
    startedPort = port;
    return LocalBackendStartResult(
      state: LocalBackendState(
        pid: 1234,
        port: port,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:$port/health',
        stdoutLogPath: p.join(repoRootPath, '.mini_program', 'backend.out.log'),
        stderrLogPath: p.join(repoRootPath, '.mini_program', 'backend.err.log'),
        startedAtUtc: DateTime.utc(2026, 4, 9).toIso8601String(),
      ),
      alreadyRunning: false,
    );
  }

  @override
  Future<LocalBackendStatusResult> status({
    required String repoRootPath,
  }) async {
    calls.add('status');
    repoRootPaths.add(repoRootPath);
    return LocalBackendStatusResult(
      state: LocalBackendState(
        pid: 1234,
        port: 9090,
        bindHost: '0.0.0.0',
        healthCheckUrl: 'http://127.0.0.1:9090/health',
        stdoutLogPath: p.join(repoRootPath, '.mini_program', 'backend.out.log'),
        stderrLogPath: p.join(repoRootPath, '.mini_program', 'backend.err.log'),
        startedAtUtc: DateTime.utc(2026, 4, 9).toIso8601String(),
      ),
      hasState: true,
      processAlive: true,
      healthy: true,
      healthStatusCode: 200,
    );
  }

  @override
  Future<LocalBackendStopResult> stop({required String repoRootPath}) async {
    calls.add('stop');
    repoRootPaths.add(repoRootPath);
    return const LocalBackendStopResult(
      hadState: true,
      processWasAlive: true,
      stopped: true,
      clearedStaleState: false,
    );
  }

  @override
  Future<LocalBackendResetResult> resetLocal({
    required String repoRootPath,
  }) async {
    calls.add('reset-local');
    repoRootPaths.add(repoRootPath);
    return const LocalBackendResetResult(removedPaths: <String>[]);
  }
}

Future<void> _writeMiniProgramFixture(
  String miniProgramRootPath, {
  required String miniProgramId,
  required String version,
}) async {
  await Directory(
    p.join(miniProgramRootPath, 'stac', 'screens'),
  ).create(recursive: true);
  await Directory(p.join(miniProgramRootPath, 'lib')).create(recursive: true);

  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "version": "$version",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"],
  "cachePolicy": {
    "manifest": {"mode": "staleWhileError", "maxStaleSeconds": 3600},
    "entryScreen": {"mode": "staleWhileError", "maxStaleSeconds": 1800}
  }
}
''');

  await File(p.join(miniProgramRootPath, 'pubspec.yaml')).writeAsString('''
name: ${miniProgramId}_mini_program
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.10.0
''');

  await File(
    p.join(miniProgramRootPath, 'lib', 'default_stac_options.dart'),
  ).writeAsString('''
import 'package:stac_core/stac_core.dart';

StacOptions get defaultStacOptions => const StacOptions(
  name: '$miniProgramId',
  description: 'Fixture',
  projectId: '${miniProgramId}_local',
  sourceDir: 'stac',
  outputDir: 'stac/.build',
);
''');
}

const String _fakeStacCliSource = r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final projectIndex = arguments.indexOf('--project');
  if (projectIndex == -1 || projectIndex == arguments.length - 1) {
    stderr.writeln('missing --project');
    exitCode = 1;
    return;
  }

  final projectRoot = arguments[projectIndex + 1];
  final manifest = jsonDecode(
    await File(joinPaths(projectRoot, 'manifest.json')).readAsString(),
  ) as Map<String, dynamic>;
  final entry = manifest['entry'] as String;
  final outputDir = Directory(
    joinPaths(projectRoot, 'stac', '.build', 'screens'),
  );
  await outputDir.create(recursive: true);
  await File(joinPaths(outputDir.path, '$entry.json')).writeAsString('{}');
}

String joinPaths(String first, String second, [String? third, String? fourth]) {
  final values = <String>[first, second];
  if (third != null) {
    values.add(third);
  }
  if (fourth != null) {
    values.add(fourth);
  }

  return values.join(Platform.pathSeparator);
}
''';
