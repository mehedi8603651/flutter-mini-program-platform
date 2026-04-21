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
        contains('publish [mini-program-id] [--target local|cloud]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('cloud outputs [--format text|dart-define]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('host run -d <device> [--env <env-name>]'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('embed cloud configure [--env <env-name>]'),
      );
    });

    test(
      'group help requests print usage without unknown command errors',
      () async {
        for (final group in <String>[
          'env',
          'cloud',
          'host',
          'embed',
          'backend',
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
          ]),
          0,
        );
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
        contains('mini_program_sdk: ^0.1.3'),
      );
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

class _FakeMiniProgramCloudController extends MiniProgramCloudController {
  _FakeMiniProgramCloudController();

  MiniProgramCloudDeployRequest? lastDeployRequest;
  MiniProgramCloudOutputsRequest? lastOutputsRequest;
  MiniProgramCloudRollbackRequest? lastRollbackRequest;

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
