part of '../miniprogram_cli_test.dart';

void _registerCloudHostPartnerTests() {
  test(
    'publish --target firebase-hosting dry-run writes hosting config and JSON output',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.2.3',
      );
      await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
      final staticPublisher = _FakeMiniProgramStaticPublisher();
      final stdoutBuffer = StringBuffer();
      var deployCalled = false;

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: StringBuffer(),
            firebaseHostingPublisher: MiniProgramFirebaseHostingPublisher(
              staticPublisher: staticPublisher,
              shellRunner: (executable, arguments, {workingDirectory}) async {
                deployCalled = true;
                return ProcessResult(0, 0, '', '');
              },
            ),
            workingDirectory: standaloneRoot,
          ).run(<String>[
            'publish',
            '--target',
            'firebase-hosting',
            '--env',
            'my-firebase-prod',
            '--clean',
            '--dry-run',
            '--json',
          ]);

      expect(exitCode, 0);
      expect(deployCalled, isFalse);
      final expectedOutputPath = p.normalize(
        p.absolute(
          p.join(standaloneRoot, 'backend', 'firebase_hosting', 'public'),
        ),
      );
      expect(staticPublisher.lastRequest, isNotNull);
      expect(staticPublisher.lastRequest!.outputPath, expectedOutputPath);
      expect(staticPublisher.lastRequest!.clean, isTrue);
      final decoded =
          jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(decoded['command'], 'publish firebase-hosting');
      expect(decoded['projectId'], 'coupon-prod');
      expect(decoded['siteId'], 'coupon-prod');
      expect(decoded['deliveryApiBaseUrl'], 'https://coupon-prod.web.app/');
      expect(decoded['dryRun'], isTrue);
      expect(decoded['deployed'], isFalse);
      final firebaseJson =
          jsonDecode(
                await File(
                  p.join(
                    standaloneRoot,
                    'backend',
                    'firebase_hosting',
                    'firebase.json',
                  ),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final hosting = firebaseJson['hosting'] as Map<String, dynamic>;
      expect(hosting['public'], 'public');
      expect(hosting.containsKey('site'), isFalse);
      final headers = hosting['headers'] as List<dynamic>;
      expect(headers, hasLength(1));
      expect(headers.first, {
        'source': '**',
        'headers': [
          {'key': 'Access-Control-Allow-Origin', 'value': '*'},
          {
            'key': 'Access-Control-Allow-Methods',
            'value': 'GET, HEAD, OPTIONS',
          },
          {
            'key': 'Access-Control-Allow-Headers',
            'value': 'Content-Type, X-Mini-Program-Access-Key',
          },
        ],
      });
    },
  );

  test('publish --target firebase-hosting deploys an optional site', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
    final staticPublisher = _FakeMiniProgramStaticPublisher();
    final outputPath = p.join(tempDir.path, 'hosting', 'site_public');
    String? capturedExecutable;
    List<String>? capturedArguments;
    String? capturedWorkingDirectory;

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          firebaseHostingPublisher: MiniProgramFirebaseHostingPublisher(
            staticPublisher: staticPublisher,
            shellRunner: (executable, arguments, {workingDirectory}) async {
              capturedExecutable = executable;
              capturedArguments = List<String>.from(arguments);
              capturedWorkingDirectory = workingDirectory;
              return ProcessResult(0, 0, 'deploy ok', '');
            },
          ),
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publish',
          '--target',
          'firebase-hosting',
          '--env',
          'my-firebase-prod',
          '--output',
          outputPath,
          '--site',
          'coupon-hosting',
        ]);

    expect(exitCode, 0);
    expect(capturedExecutable, 'firebase');
    expect(capturedArguments, <String>[
      'deploy',
      '--only',
      'hosting',
      '--project',
      'coupon-prod',
      '--config',
      p.join(p.dirname(p.normalize(p.absolute(outputPath))), 'firebase.json'),
    ]);
    expect(
      capturedWorkingDirectory,
      p.dirname(p.normalize(p.absolute(outputPath))),
    );
    final firebaseJson =
        jsonDecode(
              await File(
                p.join(
                  p.dirname(p.normalize(p.absolute(outputPath))),
                  'firebase.json',
                ),
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final hosting = firebaseJson['hosting'] as Map<String, dynamic>;
    expect(hosting['public'], 'site_public');
    expect(hosting['site'], 'coupon-hosting');
    expect(hosting['headers'], isA<List<dynamic>>());
  });

  test('publish --target firebase-hosting rejects non-Firebase envs', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stderrBuffer = StringBuffer();

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          firebaseHostingPublisher: MiniProgramFirebaseHostingPublisher(
            staticPublisher: _FakeMiniProgramStaticPublisher(),
          ),
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publish',
          '--target',
          'firebase-hosting',
          '--env',
          'my-aws-prod',
        ]);

    expect(exitCode, 1);
    expect(
      stderrBuffer.toString(),
      contains('requires a Firebase environment'),
    );
  });

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
    expect(endpointSource, contains('sendAccessKeyToBackend: true'));
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

  test('host endpoint add supports a custom local mock backend port', () async {
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
      p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
    ).readAsString();
    expect(
      endpointSource,
      contains('"backendBaseUri":"http://127.0.0.1:9091"'),
    );
    expect(endpointSource, contains('Uri.parse("http://127.0.0.1:9091")'));
  });

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
        contains('cannot use both --backend-local-mock and --backend-base-url'),
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
    final outputPath = p.join(tempDir.path, 'public_coupon_demo.partner.json');

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
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
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
    expect(endpointSource, contains('sendAccessKeyToBackend: true'));
    expect(endpointSource, contains('mpk_live_company_b_12345678901234567890'));
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
}
