part of '../miniprogram_cli_test.dart';

void _registerWorkflowValidationEmbedBackendTests() {
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

  test('workflow status is local-first and redacts partner secrets', () async {
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
      p.join(miniProgramRoot, 'backend', 'mock', 'data', 'home_bootstrap.json'),
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
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['workspace']['type'], 'mini_program');
    expect(json['miniProgram']['appId'], 'coupon_center');
    expect(json['miniProgram']['build']['exists'], isTrue);
    expect(json['miniProgram']['partnerPackages'][0]['hasAccessKey'], isTrue);
    expect(
      json['miniProgram']['partnerPackages'][0]['accessMode'],
      'protected',
    );
    expect(
      json['miniProgram']['partnerPackages'][0]['backendConfigured'],
      isTrue,
    );
    expect(json['miniProgram']['backendUsage']['usesBackendBuilder'], isTrue);
    expect(
      json['miniProgram']['backendUsage']['usesBackendQueryAction'],
      isTrue,
    );
    expect(json['miniProgram']['backendUsage']['requestIds'], contains('home'));
    expect(json['miniProgram']['publisherBackendStarter']['detected'], isTrue);
    expect(json['miniProgram']['publisherBackendStarter']['template'], 'mock');
    expect(json['remote']['checked'], isFalse);
    expect(cloudController.lastStatusRequest, isNull);
    expect(cloudController.lastAppInfoRequest, isNull);
    expect(cloudController.lastAccessKeyListRequest, isNull);
  });

  test('workflow status reports Firebase publisher backend scaffold', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_coupon',
      version: '1.0.0',
    );
    await const PublisherBackendStarter().scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: standaloneRoot,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );
    final stdoutBuffer = StringBuffer();

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'workflow',
          'status',
          '--workspace',
          standaloneRoot,
          '--json',
        ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    final starter =
        json['miniProgram']['publisherBackendStarter'] as Map<String, dynamic>;
    expect(starter['detected'], isTrue);
    expect(starter['template'], 'firebase-functions');
    expect(starter['storageMode'], 'firestore');
    expect(starter['backendRootPath'], contains('firebase_functions'));
    final firebase = starter['firebase'] as Map<String, dynamic>;
    expect(firebase['detected'], isTrue);
    expect(firebase['storageMode'], 'firestore');
    expect(firebase['dataFiles'], contains('home_bootstrap.json'));
  });

  test(
    'workflow status remote checks Firebase without AWS cloud checks',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'firebase_coupon',
        version: '1.0.0',
      );
      await Directory(
        p.join(standaloneRoot, 'stac', '.build', 'screens'),
      ).create(recursive: true);
      await File(
        p.join(
          standaloneRoot,
          'stac',
          '.build',
          'screens',
          'firebase_coupon_home.json',
        ),
      ).writeAsString('{}');
      await const PublisherBackendStarter().scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: standaloneRoot,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
      final cloudController = _FakeMiniProgramCloudController();
      final stdoutBuffer = StringBuffer();

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: StringBuffer(),
            cloudController: cloudController,
            publisherBackendStarter: PublisherBackendStarter(
              firebaseAccessTokenProvider: () async => 'firebase-token',
              healthGetter: (uri) async => http.Response('{"ok":true}', 200),
              httpRequester: (method, uri, {headers, body}) async {
                if (uri.path.endsWith('/home') ||
                    uri.path.endsWith('/sessions')) {
                  return http.Response(_firestoreDocumentsJson(1), 200);
                }
                if (uri.path.endsWith('/coupons')) {
                  return http.Response(_firestoreDocumentsJson(2), 200);
                }
                return http.Response(_firestoreDocumentsJson(0), 200);
              },
            ),
            workingDirectory: standaloneRoot,
          ).run(<String>[
            'workflow',
            'status',
            '--workspace',
            standaloneRoot,
            '--env',
            'my-firebase-prod',
            '--remote',
            '--json',
          ]);

      expect(exitCode, 0);
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['environment']['provider'], 'firebase');
      expect(json['environment']['projectId'], 'coupon-prod');
      expect(json['environment']['functionName'], 'publisherBackend');
      expect(json['remote']['provider'], 'firebase');
      expect(json['remote']['errors'], isEmpty);
      expect(json['remote']['firebase']['status']['healthy'], isTrue);
      expect(json['remote']['firebase']['dataStatus']['appRecordCount'], 4);
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
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
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
    'host run allows Firebase endpoint-map hosts without an AWS backend env',
    () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);
      await _writeFirebaseEnvironmentState(
        stateStore,
        hostRoot,
        environmentName: 'my-firebase-prod',
      );
      final hostController = _FakeMiniProgramHostController();
      final cloudController = _FakeMiniProgramCloudController();

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            cloudController: cloudController,
            hostController: hostController,
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'run',
            '-d',
            'chrome',
            '--env',
            'my-firebase-prod',
          ]);

      expect(exitCode, 0);
      expect(hostController.lastRequest, isNotNull);
      expect(hostController.lastRequest!.backendApiBaseUrl, isEmpty);
      expect(cloudController.lastOutputsRequest, isNull);
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

  test('build reports a missing mini-program root without throwing', () async {
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
  });

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
        await envCli.run(<String>['env', 'init', '--repo-root', repoRoot.path]),
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
      expect(publishBuffer.toString(), contains('Backend root: $backendRoot'));
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
      expect(publishBuffer.toString(), contains('Backend root: $backendRoot'));
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
      p.join(projectRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
    ).readAsString();
    final registrySource = await File(
      p.join(projectRoot, 'lib', 'mini_program', 'mini_program_registry.dart'),
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
        await envCli.run(<String>['env', 'init', '--repo-root', repoRoot.path]),
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
      expect(stdoutBuffer.toString(), contains('Repo root: ${repoRoot.path}'));
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
        await envCli.run(<String>['env', 'init', '--repo-root', repoRoot.path]),
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
}
