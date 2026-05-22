import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniprogramCli', () {
    late Directory tempDir;
    late Directory repoRoot;
    late LocalCliStateStore stateStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_cli_',
      );
      repoRoot = Directory(p.join(tempDir.path, 'repo'));
      await Directory(
        p.join(repoRoot.path, 'backend', 'api'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'backend', 'local_backend_service', 'bin'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'mini_programs'),
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

    test('root help shows current cloud and host commands', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        workingDirectory: tempDir.path,
      );

      final exitCode = await cli.run(<String>['--help']);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);
      expect(
        stdoutBuffer.toString(),
        contains('publish [mini-program-id] [--target local|cloud|static]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('access-key create|list|revoke|rotate'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('cloud outputs [--format text|dart-define]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('cloud app list|info|disable|delete'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('workflow status [--workspace <path>]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('partner package <mini-program-id>'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('host run -d <device> [--env <env-name>]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('host endpoint add <mini-program-id>'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('host endpoint import <partner-package.json>'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('embed init [--project-root <path>] [--with-demo]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('embed cloud configure [--env <env-name>]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('publisher-backend scaffold --template mock'),
      );
    });

    test(
      'group help requests print usage without unknown command errors',
      () async {
        for (final group in <String>[
          'env',
          'access-key',
          'cloud',
          'workflow',
          'partner',
          'host',
          'embed',
          'backend',
          'publisher-backend',
        ]) {
          final stdoutBuffer = StringBuffer();
          final stderrBuffer = StringBuffer();
          final cli = MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: stderrBuffer,
            workingDirectory: tempDir.path,
          );

          final exitCode = await cli.run(<String>[group, '--help']);

          expect(exitCode, 0, reason: group);
          expect(stderrBuffer.toString(), isEmpty, reason: group);
          expect(
            stdoutBuffer.toString(),
            contains('Usage: miniprogram $group'),
            reason: group,
          );
        }

        final embedCloudStdout = StringBuffer();
        final embedCloudStderr = StringBuffer();
        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: embedCloudStdout,
          stderrSink: embedCloudStderr,
          workingDirectory: tempDir.path,
        );

        final exitCode = await cli.run(<String>['embed', 'cloud', '--help']);

        expect(exitCode, 0);
        expect(embedCloudStderr.toString(), isEmpty);
        expect(
          embedCloudStdout.toString(),
          contains('Usage: miniprogram embed cloud'),
        );

        final cloudAppStdout = StringBuffer();
        final cloudAppStderr = StringBuffer();
        final cloudAppCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: cloudAppStdout,
          stderrSink: cloudAppStderr,
          workingDirectory: tempDir.path,
        );

        expect(await cloudAppCli.run(<String>['cloud', 'app', '--help']), 0);
        expect(cloudAppStderr.toString(), isEmpty);
        expect(
          cloudAppStdout.toString(),
          contains('Usage: miniprogram cloud app'),
        );

        final hostEndpointStdout = StringBuffer();
        final hostEndpointStderr = StringBuffer();
        final hostEndpointCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: hostEndpointStdout,
          stderrSink: hostEndpointStderr,
          workingDirectory: tempDir.path,
        );

        expect(
          await hostEndpointCli.run(<String>['host', 'endpoint', '--help']),
          0,
        );
        expect(hostEndpointStderr.toString(), isEmpty);
        expect(
          hostEndpointStdout.toString(),
          contains('Usage: miniprogram host endpoint'),
        );

        final workflowStatusStdout = StringBuffer();
        final workflowStatusStderr = StringBuffer();
        final workflowStatusCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: workflowStatusStdout,
          stderrSink: workflowStatusStderr,
          workingDirectory: tempDir.path,
        );

        expect(
          await workflowStatusCli.run(<String>['workflow', 'status', '--help']),
          0,
        );
        expect(workflowStatusStderr.toString(), isEmpty);
        expect(
          workflowStatusStdout.toString(),
          contains('Usage: miniprogram workflow status'),
        );
      },
    );

    test('create uses standalone ./<id> output by default', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
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

    test('create can scaffold the mock publisher backend starter', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        workingDirectory: tempDir.path,
      );

      final exitCode = await cli.run(<String>[
        'create',
        'coupon_backend',
        '--with-backend',
        'mock',
      ]);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);
      expect(
        await File(
          p.join(
            tempDir.path,
            'coupon_backend',
            'backend',
            'mock',
            'bin',
            'server.dart',
          ),
        ).exists(),
        isTrue,
      );
      final screenSource = await File(
        p.join(
          tempDir.path,
          'coupon_backend',
          'stac',
          'screens',
          'coupon_backend_home.dart',
        ),
      ).readAsString();
      expect(screenSource, contains('miniProgramBackendBuilder('));
    });

    test('doctor dispatches to the diagnostics helper', () async {
      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        doctor: const _FakeMiniprogramDoctor(),
        workingDirectory: tempDir.path,
      );

      final exitCode = await cli.run(<String>['doctor']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Miniprogram doctor report:'));
      expect(stdoutBuffer.toString(), contains('[ok] Fake check: all good'));
    });

    test('doctor supports machine-readable JSON output', () async {
      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        doctor: const _FakeMiniprogramDoctor(),
        workingDirectory: tempDir.path,
      );

      final exitCode = await cli.run(<String>['doctor', '--json']);

      expect(exitCode, 0);
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['command'], 'doctor');
      expect(json['hasErrors'], isFalse);
      expect(json['checks'], isA<List>());
    });

    test('status commands support JSON output', () async {
      final envRoot = p.join(tempDir.path, 'coupon_center');
      await Directory(envRoot).create(recursive: true);
      await _writeAwsEnvironmentState(stateStore, envRoot);
      final backendRoot = p.join(tempDir.path, 'backend_workspace');
      await _initializeBackendWorkspaceState(stateStore, backendRoot);
      final cloudController = _FakeMiniProgramCloudController();

      final envStdout = StringBuffer();
      expect(
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: envStdout,
          stderrSink: StringBuffer(),
          workingDirectory: envRoot,
        ).run(<String>['env', 'status', '--json']),
        0,
      );
      expect(jsonDecode(envStdout.toString())['command'], 'env status');

      final backendStdout = StringBuffer();
      expect(
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: backendStdout,
          stderrSink: StringBuffer(),
          backendController: _FakeLocalBackendController(),
          workingDirectory: envRoot,
        ).run(<String>['backend', 'status', '--json']),
        0,
      );
      expect(jsonDecode(backendStdout.toString())['healthy'], isTrue);

      final cloudStdout = StringBuffer();
      expect(
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: cloudStdout,
          stderrSink: StringBuffer(),
          cloudController: cloudController,
          workingDirectory: envRoot,
        ).run(<String>['cloud', 'status', '--json']),
        0,
      );
      expect(jsonDecode(cloudStdout.toString())['stackExists'], isTrue);

      final accessStdout = StringBuffer();
      expect(
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: accessStdout,
          stderrSink: StringBuffer(),
          cloudController: cloudController,
          workingDirectory: envRoot,
        ).run(<String>['access-key', 'list', 'coupon_center', '--json']),
        0,
      );
      final accessJson =
          jsonDecode(accessStdout.toString()) as Map<String, dynamic>;
      expect(accessJson['activeCount'], 1);
      expect(accessStdout.toString(), isNot(contains('sha256')));
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
        stateStore: stateStore,
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

    test(
      'build infers the mini-program id from the current directory',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        final fakeCliPath = p.join(repoRoot.path, 'fake_stac_cli.dart');
        await File(fakeCliPath).writeAsString(_fakeStacCliSource);

        final stdoutBuffer = StringBuffer();
        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );

        final exitCode = await cli.run(<String>[
          'build',
          '--stac-cli-script',
          fakeCliPath,
          '--skip-pub-get',
        ]);

        expect(exitCode, 0);
        expect(
          stdoutBuffer.toString(),
          contains('Built mini-program: coupon_center'),
        );
      },
    );

    test('preview requires -d <device>', () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        workingDirectory: tempDir.path,
      );

      final exitCode = await cli.run(<String>['preview']);

      expect(exitCode, 64);
      expect(stdoutBuffer.toString(), isEmpty);
      expect(stderrBuffer.toString(), contains('preview requires -d <device>'));
    });

    test(
      'preview infers the mini-program id from the current directory',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        final previewController = _FakeMiniProgramPreviewController();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          previewController: previewController,
          workingDirectory: standaloneRoot,
        ).run(<String>['preview', '-d', 'chrome']);

        expect(exitCode, 0);
        expect(previewController.lastRequest, isNotNull);
        expect(previewController.lastRequest!.miniProgramId, 'coupon_center');
        expect(
          previewController.lastRequest!.miniProgramRootPath,
          p.normalize(p.absolute(standaloneRoot)),
        );
        expect(previewController.lastRequest!.deviceId, 'chrome');
      },
    );

    test('preview forwards Edge device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final previewController = _FakeMiniProgramPreviewController();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', 'edge']);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.deviceId, 'edge');
    });

    test('preview forwards iOS device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final previewController = _FakeMiniProgramPreviewController();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', 'ios']);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.deviceId, 'ios');
    });

    test('preview forwards Linux device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final previewController = _FakeMiniProgramPreviewController();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', 'linux']);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.deviceId, 'linux');
    });

    test('preview forwards macOS device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final previewController = _FakeMiniProgramPreviewController();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', 'macos']);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.deviceId, 'macos');
    });

    test('preview rejects unsupported v1 device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final stderrBuffer = StringBuffer();
      final previewController = MiniProgramPreviewController(
        shellRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              throw const ProcessException('adb.exe', <String>['version']);
            },
      );

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: stderrBuffer,
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', 'android']);

      expect(exitCode, 1);
      expect(
        stderrBuffer.toString(),
        contains('Preview currently supports only these devices'),
      );
    });

    test(
      'preview forwards repo-root and stac-cli-script without requiring backend state',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        final fakeCliPath = p.join(repoRoot.path, 'fake_stac_cli.dart');
        await File(fakeCliPath).writeAsString(_fakeStacCliSource);
        final previewController = _FakeMiniProgramPreviewController();

        final exitCode =
            await MiniprogramCli(
              stateStore: stateStore,
              stdoutSink: StringBuffer(),
              stderrSink: StringBuffer(),
              previewController: previewController,
              workingDirectory: standaloneRoot,
            ).run(<String>[
              'preview',
              '-d',
              'windows',
              '--repo-root',
              repoRoot.path,
              '--stac-cli-script',
              fakeCliPath,
            ]);

        expect(exitCode, 0);
        expect(previewController.lastRequest, isNotNull);
        expect(previewController.lastRequest!.repoRootPath, repoRoot.path);
        expect(previewController.lastRequest!.stacCliScriptPath, fakeCliPath);
      },
    );

    test('preview accepts Android emulator device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final previewController = _FakeMiniProgramPreviewController();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', 'emulator-5554']);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.deviceId, 'emulator-5554');
    });

    test('preview forwards Android USB physical device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final previewController = _FakeMiniProgramPreviewController();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', 'R58M123ABC']);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.deviceId, 'R58M123ABC');
    });

    test('preview forwards Android Wi-Fi physical device ids', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final previewController = _FakeMiniProgramPreviewController();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        previewController: previewController,
        workingDirectory: standaloneRoot,
      ).run(<String>['preview', '-d', '192.168.1.25:5555']);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.deviceId, '192.168.1.25:5555');
    });

    test(
      'env init, configure, list, use, and status manage named cloud environments',
      () async {
        final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
        await workspaceRoot.create(recursive: true);

        final stdoutBuffer = StringBuffer();
        final stderrBuffer = StringBuffer();
        final cli = MiniprogramCli(
          stateStore: stateStore,
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
        expect(
          await File(stateStore.globalEnvironmentStatePath()).exists(),
          isTrue,
        );

        expect(
          await cli.run(<String>[
            'env',
            'configure',
            'my-aws-prod',
            '--provider',
            'aws',
            '--bucket',
            'mini-program-prod',
            '--region',
            'us-east-1',
            '--cloudfront-base-url',
            'https://d111111abcdef8.cloudfront.net',
            '--api-base-url',
            'https://api.example.com',
            '--require-access-keys',
          ]),
          0,
        );
        final savedEnvJson =
            jsonDecode(
                  await File(
                    p.join(workspaceRoot.path, '.mini_program', 'env.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final savedCloudEnvironment =
            (savedEnvJson['cloudEnvironments'] as List<dynamic>).single
                as Map<String, dynamic>;
        final savedValues =
            savedCloudEnvironment['values'] as Map<String, dynamic>;
        expect(savedValues['requireAccessKeys'], isTrue);
        expect(await cli.run(<String>['env', 'use', 'my-aws-prod']), 0);

        final listBuffer = StringBuffer();
        final listCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: listBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: workspaceRoot.path,
        );
        expect(await listCli.run(<String>['env', 'list']), 0);
        expect(listBuffer.toString(), contains('* my-aws-prod (aws)'));

        final statusBuffer = StringBuffer();
        final statusCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: statusBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: workspaceRoot.path,
        );
        expect(await statusCli.run(<String>['env', 'status']), 0);
        expect(
          statusBuffer.toString(),
          contains('Active environment: my-aws-prod'),
        );
        expect(statusBuffer.toString(), contains('Active provider: aws'));
        expect(
          statusBuffer.toString(),
          contains('Configured cloud environments: 1'),
        );
        expect(statusBuffer.toString(), contains('Config scope: local'));
        expect(stderrBuffer.toString(), isEmpty);
      },
    );

    test(
      'publish --target cloud uses the active named cloud environment',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.2.3',
        );
        final envState = LocalCliEnvironmentState(
          schemaVersion: 2,
          repoRootPath: repoRoot.path,
          activeEnvironment: 'my-aws-prod',
          cloudEnvironments: <CloudEnvironmentConfiguration>[
            CloudEnvironmentConfiguration(
              name: 'my-aws-prod',
              provider: 'aws',
              values: <String, dynamic>{
                'bucket': 'mini-program-prod',
                'region': 'us-east-1',
                'artifactsPrefix': 'artifacts',
                'metadataPrefix': 'metadata',
              },
              configuredAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
              updatedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
            ),
          ],
          initializedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
        );
        await stateStore.writeEnvironmentState(standaloneRoot, envState);
        final cloudPublisher = _FakeMiniProgramCloudPublisher();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          cloudPublisher: cloudPublisher,
          workingDirectory: standaloneRoot,
        ).run(<String>['publish', '--target', 'cloud']);

        expect(exitCode, 0);
        expect(cloudPublisher.lastRequest, isNotNull);
        expect(cloudPublisher.lastRequest!.environment.name, 'my-aws-prod');
        expect(cloudPublisher.lastRequest!.environment.provider, 'aws');
        expect(cloudPublisher.lastRequest!.miniProgramId, 'coupon_center');
        expect(
          cloudPublisher.lastRequest!.miniProgramRootPath,
          p.normalize(p.absolute(standaloneRoot)),
        );
      },
    );

    test(
      'publish --target static writes to the selected output folder',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.2.3',
        );
        final staticPublisher = _FakeMiniProgramStaticPublisher();
        final outputPath = p.join(tempDir.path, 'public_mini_program');

        final exitCode =
            await MiniprogramCli(
              stateStore: stateStore,
              stdoutSink: StringBuffer(),
              stderrSink: StringBuffer(),
              staticPublisher: staticPublisher,
              workingDirectory: standaloneRoot,
            ).run(<String>[
              'publish',
              '--target',
              'static',
              '--output',
              outputPath,
              '--clean',
            ]);

        expect(exitCode, 0);
        expect(staticPublisher.lastRequest, isNotNull);
        expect(staticPublisher.lastRequest!.outputPath, outputPath);
        expect(staticPublisher.lastRequest!.miniProgramId, 'coupon_center');
        expect(staticPublisher.lastRequest!.clean, isTrue);
        expect(
          staticPublisher.lastRequest!.miniProgramRootPath,
          p.normalize(p.absolute(standaloneRoot)),
        );
      },
    );

    test(
      'cloud deploy uses the active named env and persists apiBaseUrl',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await Directory(standaloneRoot).create(recursive: true);
        final envState = LocalCliEnvironmentState(
          schemaVersion: 2,
          repoRootPath: repoRoot.path,
          activeEnvironment: 'my-aws-prod',
          cloudEnvironments: <CloudEnvironmentConfiguration>[
            CloudEnvironmentConfiguration(
              name: 'my-aws-prod',
              provider: 'aws',
              values: <String, dynamic>{
                'bucket': 'mini-program-prod',
                'region': 'us-east-1',
                'artifactsPrefix': 'artifacts',
                'metadataPrefix': 'metadata',
              },
              configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
              updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
            ),
          ],
          initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        );
        await stateStore.writeEnvironmentState(standaloneRoot, envState);
        final cloudController = _FakeMiniProgramCloudController();
        final stdoutBuffer = StringBuffer();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          cloudController: cloudController,
          workingDirectory: standaloneRoot,
        ).run(<String>['cloud', 'deploy']);

        expect(exitCode, 0);
        expect(cloudController.lastDeployRequest, isNotNull);
        expect(
          cloudController.lastDeployRequest!.environment.name,
          'my-aws-prod',
        );
        expect(
          stdoutBuffer.toString(),
          contains('Backend API base URL: https://api.example.com/api/'),
        );

        final updatedState = await stateStore.readEnvironmentState(
          standaloneRoot,
        );
        expect(
          updatedState!
              .cloudEnvironmentNamed('my-aws-prod')!
              .values['apiBaseUrl'],
          'https://api.example.com/api/',
        );
      },
    );

    test('cloud outputs supports --format dart-define', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await Directory(standaloneRoot).create(recursive: true);
      final envState = LocalCliEnvironmentState(
        schemaVersion: 2,
        repoRootPath: repoRoot.path,
        activeEnvironment: 'my-aws-prod',
        cloudEnvironments: <CloudEnvironmentConfiguration>[
          CloudEnvironmentConfiguration(
            name: 'my-aws-prod',
            provider: 'aws',
            values: <String, dynamic>{
              'bucket': 'mini-program-prod',
              'region': 'us-east-1',
              'artifactsPrefix': 'artifacts',
              'metadataPrefix': 'metadata',
            },
            configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
            updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          ),
        ],
        initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      );
      await stateStore.writeEnvironmentState(standaloneRoot, envState);
      final stdoutBuffer = StringBuffer();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        cloudController: _FakeMiniProgramCloudController(),
        workingDirectory: standaloneRoot,
      ).run(<String>['cloud', 'outputs', '--format', 'dart-define']);

      expect(exitCode, 0);
      expect(
        stdoutBuffer.toString().trim(),
        '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://api.example.com/api',
      );
    });

    test(
      'access-key create forwards the selected env and prints secret',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await Directory(standaloneRoot).create(recursive: true);
        final envState = LocalCliEnvironmentState(
          schemaVersion: 2,
          repoRootPath: repoRoot.path,
          activeEnvironment: 'my-aws-prod',
          cloudEnvironments: <CloudEnvironmentConfiguration>[
            CloudEnvironmentConfiguration(
              name: 'my-aws-prod',
              provider: 'aws',
              values: <String, dynamic>{
                'bucket': 'mini-program-prod',
                'region': 'us-east-1',
                'artifactsPrefix': 'artifacts',
                'metadataPrefix': 'metadata',
              },
              configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
              updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
            ),
          ],
          initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        );
        await stateStore.writeEnvironmentState(standaloneRoot, envState);
        final cloudController = _FakeMiniProgramCloudController();
        final stdoutBuffer = StringBuffer();

        final exitCode =
            await MiniprogramCli(
              stateStore: stateStore,
              stdoutSink: stdoutBuffer,
              stderrSink: StringBuffer(),
              cloudController: cloudController,
              workingDirectory: standaloneRoot,
            ).run(<String>[
              'access-key',
              'create',
              'coupon_center',
              '--key-id',
              'company-a',
            ]);

        expect(exitCode, 0);
        expect(cloudController.lastAccessKeyCreateRequest, isNotNull);
        expect(
          cloudController.lastAccessKeyCreateRequest!.miniProgramId,
          'coupon_center',
        );
        expect(cloudController.lastAccessKeyCreateRequest!.keyId, 'company-a');
        expect(stdoutBuffer.toString(), contains('Access key: mpk_live_fake'));
        expect(
          stdoutBuffer.toString(),
          contains('miniprogram host endpoint add coupon_center'),
        );
      },
    );

    test('cloud app delete defaults to a dry run', () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await Directory(standaloneRoot).create(recursive: true);
      final envState = LocalCliEnvironmentState(
        schemaVersion: 2,
        repoRootPath: repoRoot.path,
        activeEnvironment: 'my-aws-prod',
        cloudEnvironments: <CloudEnvironmentConfiguration>[
          CloudEnvironmentConfiguration(
            name: 'my-aws-prod',
            provider: 'aws',
            values: <String, dynamic>{
              'bucket': 'mini-program-prod',
              'region': 'us-east-1',
              'artifactsPrefix': 'artifacts',
              'metadataPrefix': 'metadata',
            },
            configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
            updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          ),
        ],
        initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      );
      await stateStore.writeEnvironmentState(standaloneRoot, envState);
      final cloudController = _FakeMiniProgramCloudController();
      final stdoutBuffer = StringBuffer();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        cloudController: cloudController,
        workingDirectory: standaloneRoot,
      ).run(<String>['cloud', 'app', 'delete', 'coupon_center']);

      expect(exitCode, 0);
      expect(cloudController.lastAppDeleteRequest, isNotNull);
      expect(cloudController.lastAppDeleteRequest!.confirmed, isFalse);
      expect(stdoutBuffer.toString(), contains('Dry run'));
    });

    test('host endpoint add writes a reusable endpoint map', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);
      final stdoutBuffer = StringBuffer();

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: StringBuffer(),
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'endpoint',
            'add',
            'aws_coupon_demo',
            '--title',
            'AWS Coupon Demo',
            '--api-base-url',
            'https://api.example.com/prod/api/',
            '--backend-base-url',
            'https://publisher.example.com/api/',
            '--access-key',
            'mpk_live_company_a_12345678901234567890',
          ]);

      expect(exitCode, 0);
      final endpointFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      );
      final endpointSource = await endpointFile.readAsString();
      expect(endpointSource, contains('buildMiniProgramEndpoints'));
      expect(endpointSource, contains('"aws_coupon_demo"'));
      expect(endpointSource, contains('MiniPrograms.awsCouponDemo.appId'));
      expect(endpointSource, contains('MiniProgramEndpoint('));
      expect(endpointSource, contains('https://api.example.com/prod/api'));
      expect(
        endpointSource,
        contains('"backendBaseUri":"https://publisher.example.com/api"'),
      );
      expect(endpointSource, contains('"backendMode":"remote"'));
      expect(endpointSource, contains('MiniProgramBackendEndpoint('));
      expect(endpointSource, contains('https://publisher.example.com/api'));
      final registryFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_registry.dart'),
      );
      final registrySource = await registryFile.readAsString();
      expect(registrySource, contains('static const awsCouponDemo'));
      expect(registrySource, contains('title: "AWS Coupon Demo"'));
      expect(registrySource, contains('static const values'));
      expect(registrySource, contains('static const byAppId'));
      expect(registrySource, contains('"aws_coupon_demo": awsCouponDemo'));
      expect(registrySource, isNot(contains('awsCouponDemo.appId:')));
      expect(
        stdoutBuffer.toString(),
        contains(
          'config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints())',
        ),
      );
    });

    test('host endpoint add supports public static endpoints', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'endpoint',
            'add',
            'public_coupon_demo',
            '--title',
            'Public Coupon Demo',
            '--api-base-url',
            'https://user.github.io/repo/public_mini_program/',
            '--public',
          ]);

      expect(exitCode, 0);
      final endpointFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      );
      final endpointSource = await endpointFile.readAsString();
      expect(endpointSource, contains('"accessMode":"public"'));
      expect(endpointSource, contains('"backendMode":"none"'));
      expect(endpointSource, contains('MiniProgramEndpoint.public('));
      expect(endpointSource, contains('MiniPrograms.publicCouponDemo.appId'));
      expect(endpointSource, isNot(contains('accessKey:')));
      final registryFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_registry.dart'),
      );
      final registrySource = await registryFile.readAsString();
      expect(registrySource, contains('static const publicCouponDemo'));
      expect(registrySource, contains('title: "Public Coupon Demo"'));
    });

    test('host endpoint add supports local mock backend shortcut', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'endpoint',
            'add',
            'coupon_app',
            '--title',
            'Coupon App',
            '--api-base-url',
            'https://user.github.io/repo/public_mini_program/',
            '--public',
            '--backend-local-mock',
          ]);

      expect(exitCode, 0);
      final endpointSource = await File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      ).readAsString();
      expect(endpointSource, contains('"backendMode":"local_mock"'));
      expect(
        endpointSource,
        contains('"backendBaseUri":"http://127.0.0.1:9090"'),
      );
      expect(endpointSource, contains('MiniProgramBackendEndpoint('));
      expect(endpointSource, contains('Uri.parse("http://127.0.0.1:9090")'));
    });

    test(
      'host endpoint add supports a custom local mock backend port',
      () async {
        final hostRoot = p.join(tempDir.path, 'host_app');
        await _writeEmbeddedHostFixture(hostRoot);

        final exitCode =
            await MiniprogramCli(
              stateStore: stateStore,
              stdoutSink: StringBuffer(),
              stderrSink: StringBuffer(),
              workingDirectory: hostRoot,
            ).run(<String>[
              'host',
              'endpoint',
              'add',
              'coupon_app',
              '--title',
              'Coupon App',
              '--api-base-url',
              'https://user.github.io/repo/public_mini_program/',
              '--public',
              '--backend-local-mock',
              '--backend-local-mock-port',
              '9091',
            ]);

        expect(exitCode, 0);
        final endpointSource = await File(
          p.join(
            hostRoot,
            'lib',
            'mini_program',
            'mini_program_endpoints.dart',
          ),
        ).readAsString();
        expect(
          endpointSource,
          contains('"backendBaseUri":"http://127.0.0.1:9091"'),
        );
        expect(endpointSource, contains('Uri.parse("http://127.0.0.1:9091")'));
      },
    );

    test(
      'host endpoint add rejects local mock and explicit backend URL together',
      () async {
        final hostRoot = p.join(tempDir.path, 'host_app');
        await _writeEmbeddedHostFixture(hostRoot);
        final stderrBuffer = StringBuffer();

        final exitCode =
            await MiniprogramCli(
              stateStore: stateStore,
              stdoutSink: StringBuffer(),
              stderrSink: stderrBuffer,
              workingDirectory: hostRoot,
            ).run(<String>[
              'host',
              'endpoint',
              'add',
              'coupon_app',
              '--api-base-url',
              'https://user.github.io/repo/public_mini_program/',
              '--public',
              '--backend-local-mock',
              '--backend-base-url',
              'https://publisher.example.com/api/',
            ]);

        expect(exitCode, 64);
        expect(
          stderrBuffer.toString(),
          contains(
            'cannot use both --backend-local-mock and --backend-base-url',
          ),
        );
      },
    );

    test('host endpoint add requires access key or public mode', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);
      final stderrBuffer = StringBuffer();

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: stderrBuffer,
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'endpoint',
            'add',
            'public_coupon_demo',
            '--api-base-url',
            'https://user.github.io/repo/public_mini_program/',
          ]);

      expect(exitCode, 64);
      expect(
        stderrBuffer.toString(),
        contains('requires --access-key <key> or --public'),
      );
    });

    test('partner package writes a portable handoff file', () async {
      final outputPath = p.join(tempDir.path, 'aws_coupon_demo.partner.json');
      final stdoutBuffer = StringBuffer();

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: StringBuffer(),
            workingDirectory: tempDir.path,
          ).run(<String>[
            'partner',
            'package',
            'aws_coupon_demo',
            '--title',
            'AWS Coupon Demo',
            '--api-base-url',
            'https://api.example.com/prod/api/',
            '--backend-base-url',
            'https://publisher.example.com/api/',
            '--access-key',
            'mpk_live_company_a_12345678901234567890',
            '--output',
            outputPath,
          ]);

      expect(exitCode, 0);
      final decoded =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 2);
      expect(decoded['type'], 'mini_program_partner_handoff');
      expect(decoded['appId'], 'aws_coupon_demo');
      expect(decoded['title'], 'AWS Coupon Demo');
      expect(decoded['apiBaseUrl'], 'https://api.example.com/prod/api');
      expect(decoded['backendBaseUrl'], 'https://publisher.example.com/api');
      expect(decoded['accessMode'], 'protected');
      expect(decoded['accessKey'], 'mpk_live_company_a_12345678901234567890');
      expect(
        stdoutBuffer.toString(),
        contains('miniprogram host endpoint import'),
      );
    });

    test('partner package supports public static handoff files', () async {
      final outputPath = p.join(
        tempDir.path,
        'public_coupon_demo.partner.json',
      );

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            workingDirectory: tempDir.path,
          ).run(<String>[
            'partner',
            'package',
            'public_coupon_demo',
            '--title',
            'Public Coupon Demo',
            '--api-base-url',
            'https://user.github.io/repo/public_mini_program/',
            '--public',
            '--output',
            outputPath,
          ]);

      expect(exitCode, 0);
      final decoded =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 2);
      expect(decoded['accessMode'], 'public');
      expect(decoded.containsKey('accessKey'), isFalse);
    });

    test(
      'host endpoint import supports old schema v1 partner packages',
      () async {
        final hostRoot = p.join(tempDir.path, 'host_app');
        await _writeEmbeddedHostFixture(hostRoot);
        final packagePath = p.join(tempDir.path, 'legacy.partner.json');
        await File(packagePath).writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'type': 'mini_program_partner_handoff',
            'appId': 'legacy_rewards',
            'title': 'Legacy Rewards',
            'apiBaseUrl': 'https://legacy.example.com/api',
            'accessKey': 'mpk_live_legacy_12345678901234567890',
            'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
          }),
        );

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: hostRoot,
        ).run(<String>['host', 'endpoint', 'import', packagePath]);

        expect(exitCode, 0);
        final endpointFile = File(
          p.join(
            hostRoot,
            'lib',
            'mini_program',
            'mini_program_endpoints.dart',
          ),
        );
        final endpointSource = await endpointFile.readAsString();
        expect(endpointSource, contains('"legacy_rewards"'));
        expect(endpointSource, contains('"accessMode":"protected"'));
        final registryFile = File(
          p.join(hostRoot, 'lib', 'mini_program', 'mini_program_registry.dart'),
        );
        final registrySource = await registryFile.readAsString();
        expect(registrySource, contains('title: "Legacy Rewards"'));
      },
    );

    test('host endpoint import reads a partner handoff package', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);
      final packagePath = p.join(tempDir.path, 'gcp_rewards.partner.json');
      final handoff = MiniProgramPartnerHandoff(
        appId: 'gcp_rewards',
        title: 'GCP Rewards',
        apiBaseUri: Uri.parse('https://gcp.example.com/api/'),
        backendBaseUri: Uri.parse('https://publisher.example.com/api/'),
        accessKey: 'mpk_live_company_b_12345678901234567890',
        generatedAtUtc: DateTime.utc(2026, 5, 14).toIso8601String(),
      );
      await File(packagePath).writeAsString(jsonEncode(handoff.toJson()));
      final stdoutBuffer = StringBuffer();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: hostRoot,
      ).run(<String>['host', 'endpoint', 'import', packagePath]);

      expect(exitCode, 0);
      final endpointFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      );
      final endpointSource = await endpointFile.readAsString();
      expect(endpointSource, contains('"gcp_rewards"'));
      expect(endpointSource, contains('https://gcp.example.com/api'));
      expect(endpointSource, contains('https://publisher.example.com/api'));
      expect(endpointSource, contains('MiniProgramBackendEndpoint('));
      expect(
        endpointSource,
        contains('mpk_live_company_b_12345678901234567890'),
      );
      expect(stdoutBuffer.toString(), contains('Imported MiniProgram'));
      expect(stdoutBuffer.toString(), contains('Open from app UI by appId'));
      final registryFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_registry.dart'),
      );
      final registrySource = await registryFile.readAsString();
      expect(registrySource, contains('static const gcpRewards'));
      expect(registrySource, contains('title: "GCP Rewards"'));
    });

    test('host endpoint import supports public partner packages', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);
      final packagePath = p.join(tempDir.path, 'public.partner.json');
      final handoff = MiniProgramPartnerHandoff(
        appId: 'public_rewards',
        title: 'Public Rewards',
        apiBaseUri: Uri.parse('https://cdn.example.com/public/'),
        accessMode: MiniProgramPartnerHandoff.accessModePublic,
        generatedAtUtc: DateTime.utc(2026, 5, 14).toIso8601String(),
      );
      await File(packagePath).writeAsString(jsonEncode(handoff.toJson()));

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        workingDirectory: hostRoot,
      ).run(<String>['host', 'endpoint', 'import', packagePath]);

      expect(exitCode, 0);
      final endpointFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      );
      final endpointSource = await endpointFile.readAsString();
      expect(endpointSource, contains('"public_rewards"'));
      expect(endpointSource, contains('MiniProgramEndpoint.public('));
      expect(endpointSource, isNot(contains('accessKey:')));
      final registryFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_registry.dart'),
      );
      final registrySource = await registryFile.readAsString();
      expect(registrySource, contains('title: "Public Rewards"'));
    });

    test('workflow status reports unknown workspaces as JSON', () async {
      final stdoutBuffer = StringBuffer();
      final unknownRoot = p.join(tempDir.path, 'unknown');
      await Directory(unknownRoot).create(recursive: true);

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: unknownRoot,
      ).run(<String>['workflow', 'status', '--json']);

      expect(exitCode, 0);
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['command'], 'workflow status');
      expect(json['workspace']['type'], 'unknown');
      expect(json['remote']['checked'], isFalse);
    });

    test(
      'workflow status is local-first and redacts partner secrets',
      () async {
        final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          miniProgramRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        await Directory(
          p.join(miniProgramRoot, 'stac', '.build', 'screens'),
        ).create(recursive: true);
        await File(
          p.join(
            miniProgramRoot,
            'stac',
            '.build',
            'screens',
            'coupon_center_home.json',
          ),
        ).writeAsString('{}');
        await File(
          p.join(miniProgramRoot, 'coupon_center.partner.json'),
        ).writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'type': 'mini_program_partner_handoff',
            'appId': 'coupon_center',
            'title': 'Coupon Center',
            'apiBaseUrl': 'https://api.example.com/api',
            'backendBaseUrl': 'https://publisher.example.com/api',
            'accessKey': 'mpk_live_secret_should_not_print_123456',
            'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
          }),
        );
        await File(
          p.join(miniProgramRoot, 'stac', 'screens', 'coupon_center_home.dart'),
        ).writeAsString('''
miniProgramBackendBuilder(
  requestId: 'home',
  endpoint: 'home/bootstrap',
);
miniProgramBackendQueryAction(
  requestId: 'home',
  endpoint: 'home/bootstrap',
);
''');
        await File(
          p.join(miniProgramRoot, 'backend', 'mock', 'bin', 'server.dart'),
        ).create(recursive: true);
        await Directory(
          p.join(miniProgramRoot, 'backend', 'mock', 'data'),
        ).create(recursive: true);
        await File(
          p.join(
            miniProgramRoot,
            'backend',
            'mock',
            'data',
            'home_bootstrap.json',
          ),
        ).writeAsString('{}');
        await _writeAwsEnvironmentState(stateStore, miniProgramRoot);
        final cloudController = _FakeMiniProgramCloudController();
        final stdoutBuffer = StringBuffer();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          cloudController: cloudController,
          workingDirectory: miniProgramRoot,
        ).run(<String>['workflow', 'status', '--json']);

        expect(exitCode, 0);
        expect(stdoutBuffer.toString(), isNot(contains('secret_should_not')));
        final json =
            jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
        expect(json['workspace']['type'], 'mini_program');
        expect(json['miniProgram']['appId'], 'coupon_center');
        expect(json['miniProgram']['build']['exists'], isTrue);
        expect(
          json['miniProgram']['partnerPackages'][0]['hasAccessKey'],
          isTrue,
        );
        expect(
          json['miniProgram']['partnerPackages'][0]['accessMode'],
          'protected',
        );
        expect(
          json['miniProgram']['partnerPackages'][0]['backendConfigured'],
          isTrue,
        );
        expect(
          json['miniProgram']['backendUsage']['usesBackendBuilder'],
          isTrue,
        );
        expect(
          json['miniProgram']['backendUsage']['usesBackendQueryAction'],
          isTrue,
        );
        expect(
          json['miniProgram']['backendUsage']['requestIds'],
          contains('home'),
        );
        expect(
          json['miniProgram']['publisherBackendStarter']['detected'],
          isTrue,
        );
        expect(
          json['miniProgram']['publisherBackendStarter']['template'],
          'mock',
        );
        expect(json['remote']['checked'], isFalse);
        expect(cloudController.lastStatusRequest, isNull);
        expect(cloudController.lastAppInfoRequest, isNull);
        expect(cloudController.lastAccessKeyListRequest, isNull);
      },
    );

    test('workflow status reports host endpoints without secrets', () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);
      final endpointFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      );
      await endpointFile.writeAsString('''
// BEGIN MINI_PROGRAM_ENDPOINTS_JSON
// {"coupon_center":{"apiBaseUri":"https://api.example.com/api","backendBaseUri":"https://publisher.example.com/api","backendMode":"remote","accessMode":"protected","accessKey":"mpk_live_secret_a_12345678901234567890"},"rewards":{"apiBaseUri":"https://gcp.example.com/api","accessMode":"public","backendMode":"none"}}
// END MINI_PROGRAM_ENDPOINTS_JSON
''');
      final stdoutBuffer = StringBuffer();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: hostRoot,
      ).run(<String>['workflow', 'status', '--json']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), isNot(contains('secret_a')));
      expect(stdoutBuffer.toString(), isNot(contains('secret_b')));
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['workspace']['type'], 'host_app');
      expect(json['hostApp']['endpointCount'], 2);
      expect(json['hostApp']['endpointAppIds'], contains('coupon_center'));
      final endpoints = (json['hostApp']['endpoints'] as List)
          .cast<Map<String, dynamic>>();
      final couponEndpoint = endpoints.singleWhere(
        (endpoint) => endpoint['appId'] == 'coupon_center',
      );
      final rewardsEndpoint = endpoints.singleWhere(
        (endpoint) => endpoint['appId'] == 'rewards',
      );
      expect(couponEndpoint['hasAccessKey'], isTrue);
      expect(couponEndpoint['accessMode'], 'protected');
      expect(couponEndpoint['backendConfigured'], isTrue);
      expect(couponEndpoint['backendMode'], 'remote');
      expect(rewardsEndpoint['accessMode'], 'public');
      expect(rewardsEndpoint['backendMode'], 'none');
    });

    test(
      'workflow status remote mode calls cloud app and access-key checks',
      () async {
        final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          miniProgramRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        await _writeAwsEnvironmentState(stateStore, miniProgramRoot);
        final cloudController = _FakeMiniProgramCloudController();
        final stdoutBuffer = StringBuffer();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          cloudController: cloudController,
          workingDirectory: miniProgramRoot,
        ).run(<String>['workflow', 'status', '--remote', '--json']);

        expect(exitCode, 0);
        expect(cloudController.lastStatusRequest, isNotNull);
        expect(cloudController.lastAppInfoRequest, isNotNull);
        expect(cloudController.lastAccessKeyListRequest, isNotNull);
        final json =
            jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
        expect(json['remote']['checked'], isTrue);
        expect(json['remote']['app']['miniProgramId'], 'coupon_center');
        expect(json['remote']['accessKeys']['activeCount'], 1);
      },
    );

    test(
      'embed cloud configure writes a host_cloud.json file for the host app',
      () async {
        final hostRoot = p.join(tempDir.path, 'host_app');
        await _writeEmbeddedHostFixture(hostRoot);
        final envState = LocalCliEnvironmentState(
          schemaVersion: 2,
          repoRootPath: repoRoot.path,
          activeEnvironment: 'my-aws-prod',
          cloudEnvironments: <CloudEnvironmentConfiguration>[
            CloudEnvironmentConfiguration(
              name: 'my-aws-prod',
              provider: 'aws',
              values: <String, dynamic>{
                'bucket': 'mini-program-prod',
                'region': 'us-east-1',
                'artifactsPrefix': 'artifacts',
                'metadataPrefix': 'metadata',
              },
              configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
              updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
            ),
          ],
          initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        );
        await stateStore.writeGlobalEnvironmentState(envState);
        final stdoutBuffer = StringBuffer();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          cloudController: _FakeMiniProgramCloudController(),
          workingDirectory: hostRoot,
        ).run(<String>['embed', 'cloud', 'configure', '--env', 'my-aws-prod']);

        expect(exitCode, 0);
        final configuration = await stateStore.readHostCloudConfiguration(
          hostRoot,
        );
        expect(configuration, isNotNull);
        expect(configuration!.environmentName, 'my-aws-prod');
        expect(configuration.provider, 'aws');
        expect(configuration.backendApiBaseUrl, 'https://api.example.com/api');
        expect(
          stdoutBuffer.toString(),
          contains(
            'Configured embedded host app for cloud mini-program delivery.',
          ),
        );
      },
    );

    test(
      'host run uses the selected cloud env and forwards the backend URL to flutter run',
      () async {
        final hostRoot = p.join(tempDir.path, 'host_app');
        await _writeEmbeddedHostFixture(hostRoot);
        final envState = LocalCliEnvironmentState(
          schemaVersion: 2,
          repoRootPath: repoRoot.path,
          activeEnvironment: 'my-aws-prod',
          cloudEnvironments: <CloudEnvironmentConfiguration>[
            CloudEnvironmentConfiguration(
              name: 'my-aws-prod',
              provider: 'aws',
              values: <String, dynamic>{
                'bucket': 'mini-program-prod',
                'region': 'us-east-1',
                'artifactsPrefix': 'artifacts',
                'metadataPrefix': 'metadata',
                'apiBaseUrl': 'https://api.example.com/api/',
              },
              configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
              updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
            ),
          ],
          initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        );
        await stateStore.writeGlobalEnvironmentState(envState);
        final hostController = _FakeMiniProgramHostController();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          cloudController: _FakeMiniProgramCloudController(),
          hostController: hostController,
          workingDirectory: hostRoot,
        ).run(<String>['host', 'run', '-d', 'chrome', '--env', 'my-aws-prod']);

        expect(exitCode, 0);
        expect(hostController.lastRequest, isNotNull);
        expect(hostController.lastRequest!.projectRootPath, hostRoot);
        expect(hostController.lastRequest!.deviceId, 'chrome');
        expect(
          hostController.lastRequest!.backendApiBaseUrl,
          'https://api.example.com/api',
        );
      },
    );

    test(
      'cloud rollback forwards version and inferred mini-program id',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.2.3',
        );
        final envState = LocalCliEnvironmentState(
          schemaVersion: 2,
          repoRootPath: repoRoot.path,
          activeEnvironment: 'my-aws-prod',
          cloudEnvironments: <CloudEnvironmentConfiguration>[
            CloudEnvironmentConfiguration(
              name: 'my-aws-prod',
              provider: 'aws',
              values: <String, dynamic>{
                'bucket': 'mini-program-prod',
                'region': 'us-east-1',
                'artifactsPrefix': 'artifacts',
                'metadataPrefix': 'metadata',
              },
              configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
              updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
            ),
          ],
          initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        );
        await stateStore.writeEnvironmentState(standaloneRoot, envState);
        final cloudController = _FakeMiniProgramCloudController();

        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          cloudController: cloudController,
          workingDirectory: standaloneRoot,
        ).run(<String>['cloud', 'rollback', '1.0.0']);

        expect(exitCode, 0);
        expect(cloudController.lastRollbackRequest, isNotNull);
        expect(cloudController.lastRollbackRequest!.version, '1.0.0');
        expect(
          cloudController.lastRollbackRequest!.miniProgramId,
          'coupon_center',
        );
      },
    );

    test(
      'env init succeeds without a repo root and reports standalone config',
      () async {
        final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
        await workspaceRoot.create(recursive: true);

        final stdoutBuffer = StringBuffer();
        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: workspaceRoot.path,
        );

        expect(await cli.run(<String>['env', 'init']), 0);
        expect(stdoutBuffer.toString(), contains('Repo root: not configured'));
        expect(
          await File(
            p.join(workspaceRoot.path, '.mini_program', 'env.json'),
          ).exists(),
          isTrue,
        );
      },
    );

    test(
      'build reports a missing mini-program root without throwing',
      () async {
        final stdoutBuffer = StringBuffer();
        final stderrBuffer = StringBuffer();
        final cli = MiniprogramCli(
          stateStore: stateStore,
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
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: repoRoot.path,
      );

      final exitCode = await cli.run(<String>['validate', 'coupon_center']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Repo root:'));
    });

    test(
      'validate works against a standalone mini-program with a backend workspace and no repo root',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        await _initializeBackendWorkspaceState(stateStore, backendRoot);

        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );
        expect(await cli.run(<String>['env', 'init']), 0);

        final stdoutBuffer = StringBuffer();
        final validateCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );

        final exitCode = await validateCli.run(<String>[
          'validate',
          'coupon_center',
        ]);

        expect(exitCode, 0);
        expect(stdoutBuffer.toString(), contains('Repo root: $backendRoot'));
      },
    );

    test(
      'validate infers the mini-program id from the current directory',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        await _initializeBackendWorkspaceState(stateStore, backendRoot);

        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );
        expect(await cli.run(<String>['env', 'init']), 0);

        final stdoutBuffer = StringBuffer();
        final validateCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );

        final exitCode = await validateCli.run(<String>['validate']);

        expect(exitCode, 0);
        expect(stdoutBuffer.toString(), contains('Repo root: $backendRoot'));
      },
    );

    test(
      'validate falls back to the global backend workspace when a parent local state is stale',
      () async {
        final standaloneRoot = p.join(
          tempDir.path,
          'mini_program_demo',
          'coupon_center',
        );
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.0.0',
        );
        await _initializeBackendWorkspaceState(stateStore, backendRoot);
        await _writeStaleLocalBackendWorkspaceState(stateStore, tempDir.path);

        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );
        expect(await cli.run(<String>['env', 'init']), 0);

        final stdoutBuffer = StringBuffer();
        final validateCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );

        final exitCode = await validateCli.run(<String>['validate']);

        expect(exitCode, 0);
        expect(stdoutBuffer.toString(), contains('Repo root: $backendRoot'));
      },
    );

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
        stateStore: stateStore,
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
          stateStore: stateStore,
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
          stateStore: stateStore,
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

    test(
      'publish infers the mini-program id from the current directory',
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
          stateStore: stateStore,
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
          stateStore: stateStore,
          stdoutSink: publishBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );
        final exitCode = await publishCli.run(<String>[
          'publish',
          '--stac-cli-script',
          fakeCliPath,
          '--skip-build-pub-get',
        ]);

        expect(exitCode, 0);
        expect(
          publishBuffer.toString(),
          contains('Published mini-program: coupon_center'),
        );
      },
    );

    test(
      'publish uses a saved backend workspace when one is configured',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.2.0',
        );
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
        await stateStore.writeGlobalBackendWorkspaceState(
          LocalBackendWorkspaceState(
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
          ),
        );

        final fakeCliPath = p.join(repoRoot.path, 'fake_stac_cli.dart');
        await File(fakeCliPath).writeAsString(_fakeStacCliSource);

        final envCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );
        expect(
          await envCli.run(<String>[
            'env',
            'init',
            '--repo-root',
            repoRoot.path,
          ]),
          0,
        );

        final publishBuffer = StringBuffer();
        final publishCli = MiniprogramCli(
          stateStore: stateStore,
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
          contains('Backend root: $backendRoot'),
        );
        expect(
          await File(
            p.join(
              backendRoot,
              '.mini_program',
              'published_local_artifacts.json',
            ),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(
              backendRoot,
              'backend',
              'api',
              'manifests',
              'coupon_center',
              'latest.json',
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
          isFalse,
        );
      },
    );

    test(
      'publish works from a standalone workspace without any repo root',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'coupon_center');
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        await _writeMiniProgramFixture(
          standaloneRoot,
          miniProgramId: 'coupon_center',
          version: '1.2.0',
        );
        await _initializeBackendWorkspaceState(stateStore, backendRoot);

        final fakeCliPath = p.join(repoRoot.path, 'fake_stac_cli.dart');
        await File(fakeCliPath).writeAsString(_fakeStacCliSource);

        final envCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        );
        expect(await envCli.run(<String>['env', 'init']), 0);

        final publishBuffer = StringBuffer();
        final publishCli = MiniprogramCli(
          stateStore: stateStore,
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
          contains('Backend root: $backendRoot'),
        );
        expect(
          await File(
            p.join(
              backendRoot,
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

dependencies:
  flutter:
    sdk: flutter
''');

      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
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
      expect(
        await File(p.join(projectRoot, 'pubspec.yaml')).readAsString(),
        contains('mini_program_sdk: ^0.3.5'),
      );
    });

    test('embed init with demo generates public demo endpoint files', () async {
      final projectRoot = p.join(tempDir.path, 'host_app');
      await Directory(p.join(projectRoot, 'lib')).create(recursive: true);
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: host_app
version: 1.0.0+1

dependencies:
  flutter:
    sdk: flutter
''');

      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: repoRoot.path,
      );

      final exitCode = await cli.run(<String>[
        'embed',
        'init',
        '--project-root',
        projectRoot,
        '--with-demo',
      ]);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Public demo: profile via'));
      final endpointSource = await File(
        p.join(
          projectRoot,
          'lib',
          'mini_program',
          'mini_program_endpoints.dart',
        ),
      ).readAsString();
      final registrySource = await File(
        p.join(
          projectRoot,
          'lib',
          'mini_program',
          'mini_program_registry.dart',
        ),
      ).readAsString();
      expect(endpointSource, contains('MiniProgramEndpoint.public('));
      expect(
        endpointSource,
        contains(
          'https://cdn.jsdelivr.net/gh/mehedi8603651/miniprogram-public@main/',
        ),
      );
      expect(registrySource, contains("appId: 'profile'"));
      expect(registrySource, contains("title: 'Public Demo'"));
    });

    test('embed init defaults to the current working directory', () async {
      final projectRoot = p.join(tempDir.path, 'host_app');
      await Directory(p.join(projectRoot, 'lib')).create(recursive: true);
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: host_app
version: 1.0.0+1

dependencies:
  flutter:
    sdk: flutter
''');

      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: projectRoot,
      );

      final exitCode = await cli.run(<String>['embed', 'init']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Project root: $projectRoot'));
      expect(
        await File(
          p.join(projectRoot, 'lib', 'mini_program', 'mini_program.dart'),
        ).exists(),
        isTrue,
      );
    });

    test(
      'embed init uses saved global repo root when run from an unrelated host app directory',
      () async {
        final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
        await workspaceRoot.create(recursive: true);
        final hostRoot = p.join(tempDir.path, 'host_app');
        await Directory(p.join(hostRoot, 'lib')).create(recursive: true);
        await File(p.join(hostRoot, 'pubspec.yaml')).writeAsString('''
name: host_app
version: 1.0.0+1

dependencies:
  flutter:
    sdk: flutter
''');

        final envCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: workspaceRoot.path,
        );
        expect(
          await envCli.run(<String>[
            'env',
            'init',
            '--repo-root',
            repoRoot.path,
          ]),
          0,
        );

        final stdoutBuffer = StringBuffer();
        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: hostRoot,
        );

        final exitCode = await cli.run(<String>[
          'embed',
          'init',
          '--project-root',
          hostRoot,
        ]);

        expect(exitCode, 0);
        expect(
          stdoutBuffer.toString(),
          contains('Repo root: ${repoRoot.path}'),
        );
        expect(
          await File(
            p.join(hostRoot, 'lib', 'mini_program', 'mini_program.dart'),
          ).exists(),
          isTrue,
        );
      },
    );

    test('backend init scaffolds a standalone backend workspace', () async {
      final initializer = _FakeLocalBackendInitializer();
      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        backendInitializer: initializer,
        workingDirectory: tempDir.path,
      );

      final backendRoot = p.join(tempDir.path, 'backend_workspace');
      final exitCode = await cli.run(<String>[
        'backend',
        'init',
        '--root',
        backendRoot,
      ]);

      expect(exitCode, 0);
      expect(initializer.initializedRootPath, backendRoot);
      expect(
        stdoutBuffer.toString(),
        contains('Initialized local backend workspace.'),
      );
    });

    test(
      'backend init defaults to the global backend workspace when root is omitted',
      () async {
        final defaultBackendRoot = p.join(tempDir.path, 'global_backend');
        final initializer = _FakeLocalBackendInitializer(
          defaultBackendRootPath: defaultBackendRoot,
        );
        final stdoutBuffer = StringBuffer();
        final cli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          backendInitializer: initializer,
          workingDirectory: tempDir.path,
        );

        final exitCode = await cli.run(<String>['backend', 'init']);

        expect(exitCode, 0);
        expect(initializer.initializedRootPath, isNull);
        expect(
          stdoutBuffer.toString(),
          contains('Backend root: $defaultBackendRoot'),
        );
      },
    );

    test('backend subcommands dispatch to the controller', () async {
      final controller = _FakeLocalBackendController();
      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
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
      expect(
        stdoutBuffer.toString(),
        contains('Android emulator URL: http://10.0.2.2:9090/api/'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('Desktop/Chrome URL: http://127.0.0.1:9090/api/'),
      );
    });

    test(
      'backend commands use saved env repo root when run from a standalone workspace',
      () async {
        final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
        await workspaceRoot.create(recursive: true);

        final cli = MiniprogramCli(
          stateStore: stateStore,
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
          stateStore: stateStore,
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

    test(
      'backend commands use saved global repo root from an unrelated working directory',
      () async {
        final workspaceRoot = Directory(p.join(tempDir.path, 'coupon_center'));
        await workspaceRoot.create(recursive: true);
        final otherRoot = Directory(p.join(tempDir.path, 'other_workdir'));
        await otherRoot.create(recursive: true);

        final envCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: workspaceRoot.path,
        );
        expect(
          await envCli.run(<String>[
            'env',
            'init',
            '--repo-root',
            repoRoot.path,
          ]),
          0,
        );

        final controller = _FakeLocalBackendController();
        final backendCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          backendController: controller,
          workingDirectory: otherRoot.path,
        );

        expect(await backendCli.run(<String>['backend', 'start']), 0);
        expect(await backendCli.run(<String>['backend', 'status']), 0);
        expect(await backendCli.run(<String>['backend', 'stop']), 0);
        expect(controller.repoRootPaths, everyElement(repoRoot.path));
      },
    );

    test(
      'backend commands use a saved backend workspace when no repo root is present',
      () async {
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
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

        final otherRoot = Directory(p.join(tempDir.path, 'other_workdir'));
        await otherRoot.create(recursive: true);
        final controller = _FakeLocalBackendController();
        final backendCli = MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          backendController: controller,
          workingDirectory: otherRoot.path,
        );

        expect(await backendCli.run(<String>['backend', 'start']), 0);
        expect(await backendCli.run(<String>['backend', 'status']), 0);
        expect(await backendCli.run(<String>['backend', 'stop']), 0);
        expect(controller.repoRootPaths, everyElement(backendRoot));
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

class _FakeMiniprogramDoctor extends MiniprogramDoctor {
  const _FakeMiniprogramDoctor();

  @override
  Future<MiniprogramDoctorResult> diagnose({
    String? explicitRepoRootPath,
  }) async {
    return const MiniprogramDoctorResult(
      checks: <MiniprogramDoctorCheck>[
        MiniprogramDoctorCheck(
          label: 'Fake check',
          status: MiniprogramDoctorCheckStatus.ok,
          summary: 'all good',
        ),
      ],
    );
  }
}

class _FakeLocalBackendInitializer extends LocalBackendInitializer {
  _FakeLocalBackendInitializer({this.defaultBackendRootPath});

  String? initializedRootPath;
  final String? defaultBackendRootPath;

  @override
  Future<LocalBackendInitResult> initialize(
    LocalBackendInitRequest request,
  ) async {
    initializedRootPath = request.backendRootPath;
    final backendRootPath = p.normalize(
      p.absolute(
        request.backendRootPath ??
            defaultBackendRootPath ??
            'backend_workspace',
      ),
    );
    return LocalBackendInitResult(
      backendRootPath: backendRootPath,
      apiRootPath: p.join(backendRootPath, 'backend', 'api'),
      serviceDirectoryPath: p.join(
        backendRootPath,
        'backend',
        'local_backend_service',
      ),
      stateFilePath: p.join(
        backendRootPath,
        '.mini_program',
        'backend_workspace.json',
      ),
      globalStateFilePath: p.join(
        backendRootPath,
        '.mini_program',
        'global_backend_workspace.json',
      ),
      createdPaths: <String>[
        p.join(backendRootPath, 'backend', 'api'),
        p.join(backendRootPath, 'backend', 'local_backend_service'),
      ],
    );
  }
}

class _FakeMiniProgramPreviewController extends MiniProgramPreviewController {
  _FakeMiniProgramPreviewController();

  MiniProgramPreviewRequest? lastRequest;

  @override
  Future<int> preview(
    MiniProgramPreviewRequest request, {
    required StringSink stdoutSink,
    required StringSink stderrSink,
  }) async {
    lastRequest = request;
    return 0;
  }
}

class _FakeMiniProgramCloudPublisher extends MiniProgramCloudPublisher {
  _FakeMiniProgramCloudPublisher();

  MiniProgramCloudPublishRequest? lastRequest;

  @override
  Future<MiniProgramCloudPublishResult> publish(
    MiniProgramCloudPublishRequest request,
  ) async {
    lastRequest = request;
    return MiniProgramCloudPublishResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId ?? 'coupon_center',
      version: '1.2.3',
      buildResult: MiniProgramBuildResult(
        repoRootPath: request.repoRootPath,
        miniProgramId: request.miniProgramId ?? 'coupon_center',
        miniProgramRootPath:
            request.miniProgramRootPath ??
            p.join(request.repoRootPath, 'coupon_center'),
        cliSource: 'fake',
        invocation: const <String>['dart', 'fake'],
        outputDirectoryPath: p.join(
          request.miniProgramRootPath ?? request.repoRootPath,
          'stac',
          '.build',
        ),
        screensDirectoryPath: p.join(
          request.miniProgramRootPath ?? request.repoRootPath,
          'stac',
          '.build',
          'screens',
        ),
        entryScreenJsonPath: p.join(
          request.miniProgramRootPath ?? request.repoRootPath,
          'stac',
          '.build',
          'screens',
          'coupon_center_home.json',
        ),
        pubGetRan: false,
      ),
      bucketName: 'mini-program-prod',
      region: 'us-east-1',
      artifactRootKey: 'artifacts/coupon_center/1.2.3',
      manifestKey: 'artifacts/coupon_center/1.2.3/manifest.json',
      screensPrefixKey: 'artifacts/coupon_center/1.2.3/screens',
      metadataReleaseKey: 'metadata/releases/coupon_center/1.2.3.json',
      metadataCatalogKey: 'metadata/catalog/coupon_center.json',
      publishedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
      uploadedObjects: const <CloudPublishedObjectRecord>[],
    );
  }
}

class _FakeMiniProgramStaticPublisher extends MiniProgramStaticPublisher {
  _FakeMiniProgramStaticPublisher();

  MiniProgramStaticPublishRequest? lastRequest;

  @override
  Future<MiniProgramStaticPublishResult> publish(
    MiniProgramStaticPublishRequest request,
  ) async {
    lastRequest = request;
    final miniProgramRootPath =
        request.miniProgramRootPath ??
        p.join(request.repoRootPath, request.miniProgramId ?? 'coupon_center');
    final buildResult = MiniProgramBuildResult(
      repoRootPath: request.repoRootPath,
      miniProgramId: request.miniProgramId ?? 'coupon_center',
      miniProgramRootPath: miniProgramRootPath,
      cliSource: 'fake',
      invocation: const <String>['dart', 'fake'],
      outputDirectoryPath: p.join(miniProgramRootPath, 'stac', '.build'),
      screensDirectoryPath: p.join(
        miniProgramRootPath,
        'stac',
        '.build',
        'screens',
      ),
      entryScreenJsonPath: p.join(
        miniProgramRootPath,
        'stac',
        '.build',
        'screens',
        'coupon_center_home.json',
      ),
      pubGetRan: false,
    );
    return MiniProgramStaticPublishResult(
      outputPath: request.outputPath,
      miniProgramId: request.miniProgramId ?? 'coupon_center',
      version: '1.2.3',
      buildResult: buildResult,
      manifestLatestPath: p.join(
        request.outputPath,
        'manifests',
        request.miniProgramId ?? 'coupon_center',
        'latest.json',
      ),
      manifestVersionPath: p.join(
        request.outputPath,
        'manifests',
        request.miniProgramId ?? 'coupon_center',
        'versions',
        '1.2.3.json',
      ),
      screensDirectoryPath: p.join(
        request.outputPath,
        'screens',
        request.miniProgramId ?? 'coupon_center',
        '1.2.3',
      ),
      metadataReleasePath: p.join(
        request.outputPath,
        'metadata',
        'releases',
        request.miniProgramId ?? 'coupon_center',
        '1.2.3.json',
      ),
      metadataCatalogPath: p.join(
        request.outputPath,
        'metadata',
        'catalog',
        '${request.miniProgramId ?? 'coupon_center'}.json',
      ),
      instructionsPath: p.join(request.outputPath, 'PUBLISH_INSTRUCTIONS.md'),
      nojekyllPath: p.join(request.outputPath, '.nojekyll'),
      publishedAtUtc: DateTime.utc(2026, 5, 18).toIso8601String(),
      writtenFiles: const <StaticPublishedFileRecord>[],
      cleaned: request.clean,
    );
  }
}

class _FakeMiniProgramCloudController extends MiniProgramCloudController {
  _FakeMiniProgramCloudController();

  MiniProgramCloudDeployRequest? lastDeployRequest;
  MiniProgramCloudStatusRequest? lastStatusRequest;
  MiniProgramCloudOutputsRequest? lastOutputsRequest;
  MiniProgramCloudRollbackRequest? lastRollbackRequest;
  MiniProgramAccessKeyCreateRequest? lastAccessKeyCreateRequest;
  MiniProgramAccessKeyListRequest? lastAccessKeyListRequest;
  MiniProgramAccessKeyRevokeRequest? lastAccessKeyRevokeRequest;
  MiniProgramAccessKeyRotateRequest? lastAccessKeyRotateRequest;
  MiniProgramCloudAppListRequest? lastAppListRequest;
  MiniProgramCloudAppInfoRequest? lastAppInfoRequest;
  MiniProgramCloudAppDisableRequest? lastAppDisableRequest;
  MiniProgramCloudAppDeleteRequest? lastAppDeleteRequest;

  @override
  Future<MiniProgramCloudDeployResult> deploy(
    MiniProgramCloudDeployRequest request,
  ) async {
    lastDeployRequest = request;
    return MiniProgramCloudDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: 'mini-program-cloud-${request.environment.name}',
      stageName: 'prod',
      region: request.environment.values['region'].toString(),
      bucketName: request.environment.values['bucket'].toString(),
      backendProjectRootPath: p.join(
        request.resolvedEnvironmentState.rootPath,
        '.mini_program',
        'cloud',
        'aws_backend',
      ),
      outputs: const <String, String>{
        'BackendApiBaseUrl': 'https://api.example.com/api/',
        'HealthUrl': 'https://api.example.com/health',
      },
      apiBaseUrl: 'https://api.example.com/api/',
      healthUrl: 'https://api.example.com/health',
      healthy: true,
      healthStatusCode: 200,
      deployedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramCloudStatusResult> status(
    MiniProgramCloudStatusRequest request,
  ) async {
    lastStatusRequest = request;
    return MiniProgramCloudStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: 'mini-program-cloud-${request.environment.name}',
      stageName: 'prod',
      region: request.environment.values['region'].toString(),
      stackExists: true,
      stackStatus: 'CREATE_COMPLETE',
      outputs: const <String, String>{
        'BackendApiBaseUrl': 'https://api.example.com/api/',
        'HealthUrl': 'https://api.example.com/health',
      },
      apiBaseUrl: 'https://api.example.com/api/',
      healthUrl: 'https://api.example.com/health',
      healthy: true,
      healthStatusCode: 200,
    );
  }

  @override
  Future<MiniProgramCloudOutputsResult> outputs(
    MiniProgramCloudOutputsRequest request,
  ) async {
    lastOutputsRequest = request;
    return MiniProgramCloudOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      stackName: 'mini-program-cloud-${request.environment.name}',
      region: request.environment.values['region'].toString(),
      outputs: const <String, String>{
        'BackendApiBaseUrl': 'https://api.example.com/api/',
        'HealthUrl': 'https://api.example.com/health',
      },
    );
  }

  @override
  Future<MiniProgramCloudRollbackResult> rollback(
    MiniProgramCloudRollbackRequest request,
  ) async {
    lastRollbackRequest = request;
    return MiniProgramCloudRollbackResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      version: request.version,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      catalogKey: 'metadata/catalog/${request.miniProgramId}.json',
      releaseKey:
          'metadata/releases/${request.miniProgramId}/${request.version}.json',
      rolledBackAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramAccessKeyCreateResult> createAccessKey(
    MiniProgramAccessKeyCreateRequest request,
  ) async {
    lastAccessKeyCreateRequest = request;
    return MiniProgramAccessKeyCreateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      keyId: request.keyId,
      accessKey: 'mpk_live_fake_${request.miniProgramId}_${request.keyId}',
      createdAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramAccessKeyListResult> listAccessKeys(
    MiniProgramAccessKeyListRequest request,
  ) async {
    lastAccessKeyListRequest = request;
    return MiniProgramAccessKeyListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      policyExists: true,
      keys: const <MiniProgramAccessKeyEntry>[
        MiniProgramAccessKeyEntry(
          id: 'host-a',
          sha256: 'sha256_should_not_print',
          enabled: true,
          createdAtUtc: '2026-04-19T00:00:00.000Z',
          updatedAtUtc: '2026-04-19T00:00:00.000Z',
        ),
      ],
    );
  }

  @override
  Future<MiniProgramAccessKeyRevokeResult> revokeAccessKey(
    MiniProgramAccessKeyRevokeRequest request,
  ) async {
    lastAccessKeyRevokeRequest = request;
    return MiniProgramAccessKeyRevokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      keyId: request.keyId,
      revokedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramAccessKeyRotateResult> rotateAccessKey(
    MiniProgramAccessKeyRotateRequest request,
  ) async {
    lastAccessKeyRotateRequest = request;
    return MiniProgramAccessKeyRotateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      policyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      revokedKeyId: request.keyId,
      newKeyId: request.newKeyId ?? '${request.keyId}-v2',
      accessKey: 'mpk_live_fake_${request.miniProgramId}_${request.keyId}_v2',
      rotatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }

  @override
  Future<MiniProgramCloudAppListResult> listApps(
    MiniProgramCloudAppListRequest request,
  ) async {
    lastAppListRequest = request;
    return MiniProgramCloudAppListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      apps: const <MiniProgramCloudAppSummary>[
        MiniProgramCloudAppSummary(
          miniProgramId: 'coupon_center',
          catalogKey: 'metadata/catalog/coupon_center.json',
          latestVersion: '1.2.3',
        ),
      ],
    );
  }

  @override
  Future<MiniProgramCloudAppInfoResult> appInfo(
    MiniProgramCloudAppInfoRequest request,
  ) async {
    lastAppInfoRequest = request;
    return MiniProgramCloudAppInfoResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      catalogKey: 'metadata/catalog/${request.miniProgramId}.json',
      catalog: <String, Object?>{
        'latestVersion': '1.2.3',
        'releaseKey': 'metadata/releases/${request.miniProgramId}/1.2.3.json',
      },
      releaseKey: 'metadata/releases/${request.miniProgramId}/1.2.3.json',
      accessPolicyKey: 'metadata/access_keys/${request.miniProgramId}.json',
      accessKeyCount: 1,
      activeAccessKeyCount: 1,
    );
  }

  @override
  Future<MiniProgramCloudAppDisableResult> disableApp(
    MiniProgramCloudAppDisableRequest request,
  ) async {
    lastAppDisableRequest = request;
    return MiniProgramCloudAppDisableResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      catalogKey: 'metadata/catalog/${request.miniProgramId}.json',
      disabledCatalogKey: 'metadata/disabled/${request.miniProgramId}.json',
      disabledAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      dryRun: !request.confirmed,
    );
  }

  @override
  Future<MiniProgramCloudAppDeleteResult> deleteApp(
    MiniProgramCloudAppDeleteRequest request,
  ) async {
    lastAppDeleteRequest = request;
    return MiniProgramCloudAppDeleteResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      miniProgramId: request.miniProgramId,
      bucketName: request.environment.values['bucket'].toString(),
      region: request.environment.values['region'].toString(),
      deletedKeys: <String>[
        'metadata/catalog/${request.miniProgramId}.json',
        'metadata/access_keys/${request.miniProgramId}.json',
      ],
      dryRun: !request.confirmed,
      deletedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    );
  }
}

class _FakeMiniProgramHostController extends MiniProgramHostController {
  _FakeMiniProgramHostController();

  MiniProgramHostRunRequest? lastRequest;

  @override
  Future<MiniProgramHostRunResult> run(
    MiniProgramHostRunRequest request,
  ) async {
    lastRequest = request;
    return MiniProgramHostRunResult(
      projectRootPath: request.projectRootPath,
      deviceId: request.deviceId,
      backendApiBaseUrl: request.backendApiBaseUrl,
      invocation: <String>[
        'run',
        '-d',
        request.deviceId,
        '--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=${request.backendApiBaseUrl}',
      ],
      exitCode: 0,
    );
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

Future<void> _writeEmbeddedHostFixture(String hostRootPath) async {
  await Directory(
    p.join(hostRootPath, 'lib', 'mini_program'),
  ).create(recursive: true);
  await File(p.join(hostRootPath, 'pubspec.yaml')).writeAsString('''
name: host_app
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.10.0
''');
  await File(
    p.join(
      hostRootPath,
      'lib',
      'mini_program',
      'mini_program_runtime_setup.dart',
    ),
  ).writeAsString('// generated runtime setup');
}

Future<void> _writeAwsEnvironmentState(
  LocalCliStateStore stateStore,
  String rootPath, {
  String environmentName = 'my-aws-prod',
}) async {
  await stateStore.writeEnvironmentState(
    rootPath,
    LocalCliEnvironmentState(
      schemaVersion: 2,
      repoRootPath: null,
      activeEnvironment: environmentName,
      cloudEnvironments: <CloudEnvironmentConfiguration>[
        CloudEnvironmentConfiguration(
          name: environmentName,
          provider: 'aws',
          values: <String, dynamic>{
            'bucket': 'mini-program-prod',
            'region': 'us-east-1',
            'artifactsPrefix': 'artifacts',
            'metadataPrefix': 'metadata',
            'apiBaseUrl': 'https://api.example.com/api/',
            'requireAccessKeys': true,
          },
          configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        ),
      ],
      initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
    ),
  );
}

Future<void> _initializeBackendWorkspaceState(
  LocalCliStateStore stateStore,
  String backendRoot,
) async {
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
  await stateStore.writeGlobalBackendWorkspaceState(
    LocalBackendWorkspaceState(
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
    ),
  );
}

Future<void> _writeStaleLocalBackendWorkspaceState(
  LocalCliStateStore stateStore,
  String rootPath,
) {
  return stateStore.writeBackendWorkspaceState(
    rootPath,
    LocalBackendWorkspaceState(
      schemaVersion: 1,
      backendRootPath: rootPath,
      apiRootPath: p.join(rootPath, 'backend', 'api'),
      serviceDirectoryPath: p.join(
        rootPath,
        'backend',
        'local_backend_service',
      ),
      initializedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
      updatedAtUtc: DateTime.utc(2026, 4, 10).toIso8601String(),
    ),
  );
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
