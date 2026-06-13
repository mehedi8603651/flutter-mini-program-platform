part of '../miniprogram_cli_test.dart';

void _registerCoreAndPreviewTests() {
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
      contains('create <mini-program-id> [--screen-format mp]'),
    );
    expect(
      stdoutBuffer.toString(),
      contains(
        'publish [mini-program-id] [--target local|cloud|static|firebase-hosting]',
      ),
    );
    expect(stdoutBuffer.toString(), contains('capabilities [--json]'));
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
      contains('embed init [--project-root <path>]'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('embed cloud configure [--env <env-name>]'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('publisher-backend scaffold --template mock'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('publisher-api contract init|validate|smoke|handoff'),
    );
    expect(stdoutBuffer.toString(), isNot(contains('publisher-backend aws')));
    expect(
      stdoutBuffer.toString(),
      isNot(contains('publisher-backend firebase')),
    );
  });

  test('create help exposes screen format selection', () async {
    final stdoutBuffer = StringBuffer();
    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['create', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('--screen-format'));
    expect(stdoutBuffer.toString(), contains('mp'));
    expect(stdoutBuffer.toString(), isNot(contains('stac')));
  });

  test('build and preview help expose Mp build script override', () async {
    final buildStdout = StringBuffer();
    final previewStdout = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: buildStdout,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    );

    expect(await cli.run(<String>['build', '--help']), 0);
    expect(buildStdout.toString(), contains('--mp-build-script'));

    final previewExitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: previewStdout,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['preview', '--help']);
    expect(previewExitCode, 0);
    expect(previewStdout.toString(), contains('--mp-build-script'));
  });

  test('capabilities prints text output', () async {
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: stderrBuffer,
      workingDirectory: tempDir.path,
    );

    final exitCode = await cli.run(<String>['capabilities']);

    expect(exitCode, 0);
    expect(stderrBuffer.toString(), isEmpty);
    expect(
      stdoutBuffer.toString(),
      contains('MiniProgram tooling capabilities.'),
    );
    expect(stdoutBuffer.toString(), contains('Version: 0.5.1'));
    expect(stdoutBuffer.toString(), contains('publish.firebase_hosting'));
    expect(stdoutBuffer.toString(), contains('publisher_api.mock.scaffold'));
    expect(stdoutBuffer.toString(), contains('publisher_api.contract.handoff'));
    expect(stdoutBuffer.toString(), isNot(contains('publisher_backend.aws')));
    expect(
      stdoutBuffer.toString(),
      isNot(contains('publisher_backend.firebase')),
    );
  });

  test('capabilities prints machine-readable JSON', () async {
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: stderrBuffer,
      workingDirectory: tempDir.path,
    );

    final exitCode = await cli.run(<String>['capabilities', '--json']);

    expect(exitCode, 0);
    expect(stderrBuffer.toString(), isEmpty);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['schemaVersion'], 1);
    expect(json['command'], 'capabilities');
    expect(json['toolingVersion'], '0.5.1');
    expect(json['packageName'], 'mini_program_tooling');
    expect(json['capabilityIds'], contains('publish.firebase_hosting'));
    expect(json['capabilityIds'], contains('publisher_api.mock.scaffold'));
    expect(json['capabilityIds'], contains('publisher_api.contract.handoff'));
    expect(json['capabilityIds'], isNot(contains('host.legacy_stac_adapter')));
    expect(
      json['capabilityIds'],
      isNot(contains(startsWith('publisher_backend.aws'))),
    );
    expect(
      json['capabilityIds'],
      isNot(contains(startsWith('publisher_backend.firebase'))),
    );
    final features = json['features'] as Map<String, dynamic>;
    expect(features.containsKey('hostLegacyStacAdapter'), isFalse);
    expect(features['firebaseHostingPublish'], isTrue);
    expect(features['publisherApiMock'], isTrue);
    expect(features['publisherBackendContractInit'], isTrue);
    expect(features['publisherBackendContractValidate'], isTrue);
    expect(features['publisherBackendContractSmoke'], isTrue);
    expect(features['publisherBackendContractHandoff'], isTrue);
    expect(
      features.keys.any((key) => key.startsWith('publisherBackendAws')),
      isFalse,
    );
    expect(
      features.keys.any((key) => key.startsWith('publisherBackendFirebase')),
      isFalse,
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
        'publisher-api',
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
    expect(stdoutBuffer.toString(), contains('Created mini-program scaffold'));
  });

  test('create can scaffold the mock Publisher API starter', () async {
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
        'mp',
        'screens',
        'coupon_backend_home.dart',
      ),
    ).readAsString();
    expect(screenSource, contains('Mp.backendBuilder('));
    expect(screenSource, contains('Mp.pagedBackendBuilder('));
    expect(screenSource, contains("endpoint: 'coupons/page'"));
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
          'mp',
          '.build',
          'screens',
          'coupon_center_home.json',
        ),
      ).exists(),
      isTrue,
    );
  });

  test('build infers the mini-program id from the current directory', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.0.0',
    );
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>['build', '--skip-pub-get']);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Built mini-program: coupon_center'),
    );
  });

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
    'preview forwards repo-root and build script overrides without requiring backend state',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final fakeMpBuildScriptPath = p.join(repoRoot.path, 'fake_build_mp.dart');
      await File(fakeMpBuildScriptPath).writeAsString('// mp');
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
            '--mp-build-script',
            fakeMpBuildScriptPath,
          ]);

      expect(exitCode, 0);
      expect(previewController.lastRequest, isNotNull);
      expect(previewController.lastRequest!.repoRootPath, repoRoot.path);
      expect(
        previewController.lastRequest!.mpBuildScriptPath,
        fakeMpBuildScriptPath,
      );
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
}
