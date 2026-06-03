part of '../../miniprogram_cli_test.dart';

void _registerPublisherBackendFirebaseSetupDeployTests() {
  test('env configure supports Firebase publisher backend values', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    await Directory(standaloneRoot).create(recursive: true);
    await stateStore.writeEnvironmentState(
      standaloneRoot,
      LocalCliEnvironmentState(
        schemaVersion: 2,
        repoRootPath: null,
        activeEnvironment: 'local',
        cloudEnvironments: const <CloudEnvironmentConfiguration>[],
        initializedAtUtc: DateTime.utc(2026, 5, 24).toIso8601String(),
        updatedAtUtc: DateTime.utc(2026, 5, 24).toIso8601String(),
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
          'env',
          'configure',
          'my-firebase-prod',
          '--provider',
          'firebase',
          '--project-id',
          'coupon-prod',
          '--region',
          'asia-south1',
          '--function-name',
          'publisherBackend',
          '--function-url',
          'https://custom-functions.example.com/publisherBackend',
          '--auth-web-api-key',
          'AIzaSyFakeFirebaseWebApiKey123456789',
        ]);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('Provider: firebase'));
    expect(stdoutBuffer.toString(), contains('projectId: coupon-prod'));
    expect(stdoutBuffer.toString(), contains('authWebApiKey: <configured>'));
    expect(
      stdoutBuffer.toString(),
      isNot(contains('AIzaSyFakeFirebaseWebApiKey123456789')),
    );
    final state = await stateStore.readEnvironmentState(standaloneRoot);
    final environment = state!.cloudEnvironmentNamed('my-firebase-prod')!;
    expect(environment.provider, 'firebase');
    expect(environment.values['projectId'], 'coupon-prod');
    expect(environment.values['region'], 'asia-south1');
    expect(environment.values['functionName'], 'publisherBackend');
    expect(
      environment.values['functionUrl'],
      'https://custom-functions.example.com/publisherBackend',
    );
    expect(
      environment.values['authWebApiKey'],
      'AIzaSyFakeFirebaseWebApiKey123456789',
    );

    final useExitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: StringBuffer(),
      stderrSink: StringBuffer(),
      workingDirectory: standaloneRoot,
    ).run(<String>['env', 'use', 'my-firebase-prod']);
    expect(useExitCode, 0);
    final statusBuffer = StringBuffer();
    final statusExitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: statusBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: standaloneRoot,
    ).run(<String>['env', 'status', '--json']);
    expect(statusExitCode, 0);
    expect(
      statusBuffer.toString(),
      isNot(contains('AIzaSyFakeFirebaseWebApiKey123456789')),
    );
    final statusJson =
        jsonDecode(statusBuffer.toString()) as Map<String, dynamic>;
    final activeCloudEnvironment =
        statusJson['activeCloudEnvironment'] as Map<String, dynamic>;
    expect(activeCloudEnvironment['authWebApiKeyConfigured'], isTrue);
    expect(activeCloudEnvironment['values']['authWebApiKey'], '<configured>');
  });

  test('publisher-backend firebase starter-ui writes text output', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_starter_ui');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_starter_ui',
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
          'publisher-backend',
          'firebase',
          'starter-ui',
          '--mini-program-root',
          standaloneRoot,
        ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Firebase publisher backend starter UI updated.'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('Entry screen: firebase_starter_ui_home'),
    );
    expect(
      await File(
        p.join(
          standaloneRoot,
          'stac',
          'screens',
          'firebase_starter_ui_home.dart',
        ),
      ).exists(),
      isTrue,
    );
  });

  test('publisher-backend firebase starter-ui prints JSON output', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_starter_ui_json');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_starter_ui_json',
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
          'publisher-backend',
          'firebase',
          'starter-ui',
          '--json',
          '--force',
        ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend firebase starter-ui');
    expect(json['provider'], 'firebase');
    expect(json['miniProgramId'], 'firebase_starter_ui_json');
    expect(json['writtenFileCount'], 5);
    expect(
      json['writtenPaths'].toString(),
      contains('firebase_starter_ui_json_home.dart'),
    );
  });

  test('publisher-backend firebase deploy prints text output', () async {
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
    await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        httpRequester: (method, uri, {headers, body}) async => http.Response(
          jsonEncode(<String, Object?>{
            'bindings': <Object?>[
              <String, Object?>{
                'role': 'roles/run.invoker',
                'members': <String>['allUsers'],
              },
            ],
          }),
          200,
        ),
        clock: () => DateTime.utc(2026, 5, 24, 12),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'deploy',
      '--env',
      'my-firebase-prod',
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Deployed Firebase Functions publisher backend.'),
    );
    expect(stdoutBuffer.toString(), contains('Project: coupon-prod'));
    expect(stdoutBuffer.toString(), contains('Healthy: true'));
    expect(
      stdoutBuffer.toString(),
      contains(
        'publisher-backend firebase host-command --env my-firebase-prod',
      ),
    );
    expect(
      stdoutBuffer.toString(),
      contains('publisher-backend firebase smoke --env my-firebase-prod'),
    );
  });

  test('publisher-backend firebase status prints JSON', () async {
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
    await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        httpRequester: (method, uri, {headers, body}) async => http.Response(
          jsonEncode(<String, Object?>{'errorCode': 'auth_required'}),
          401,
        ),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'status',
      '--env',
      'my-firebase-prod',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend firebase status');
    expect(json['projectId'], 'coupon-prod');
    expect(json['scaffoldExists'], isTrue);
    expect(json['healthy'], isTrue);
  });

  test('publisher-backend firebase outputs prints text output', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_coupon',
      version: '1.0.0',
    );
    await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'outputs',
          '--env',
          'my-firebase-prod',
        ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Firebase Functions publisher backend outputs.'),
    );
    expect(stdoutBuffer.toString(), contains('PublisherBackendBaseUrl:'));
    expect(
      stdoutBuffer.toString(),
      contains('PublisherBackendStorageMode: firestore'),
    );
  });
}
