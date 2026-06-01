part of '../miniprogram_cli_test.dart';

void _registerPublisherBackendFirebaseTests() {
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

  test('publisher-backend firebase host-command prints public command', () async {
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
          'host-command',
          '--env',
          'my-firebase-prod',
          '--api-base-url',
          'https://cdn.example.com/public_mini_program/',
          '--public',
        ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Firebase host endpoint command.'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('Mini-program ID: firebase_coupon'),
    );
    expect(stdoutBuffer.toString(), contains('Access mode: public'));
    expect(
      stdoutBuffer.toString(),
      contains(
        "miniprogram host endpoint add firebase_coupon --title 'Firebase Coupon' --api-base-url https://cdn.example.com/public_mini_program/ --public --backend-base-url https://asia-south1-coupon-prod.cloudfunctions.net/publisherBackend/",
      ),
    );
  });

  test(
    'publisher-backend firebase host-command supports protected mode',
    () async {
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
            'host-command',
            '--env',
            'my-firebase-prod',
            '--api-base-url',
            'https://cdn.example.com/public_mini_program/',
            '--access-key',
            'mpk_live_partner_123',
          ]);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Access mode: protected'));
      expect(
        stdoutBuffer.toString(),
        contains('--access-key mpk_live_partner_123'),
      );
      expect(stdoutBuffer.toString(), isNot(contains('--public')));
    },
  );

  test('publisher-backend firebase handoff creates public package', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    final hostRoot = p.join(tempDir.path, 'host_app');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_coupon',
      version: '1.0.0',
    );
    await _writeEmbeddedHostFixture(hostRoot);
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
          'handoff',
          '--env',
          'my-firebase-prod',
          '--delivery-url',
          'https://cdn.example.com/public_mini_program/',
          '--public',
          '--json',
        ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    final packagePath = json['packagePath'] as String;
    expect(json['command'], 'publisher-backend firebase handoff');
    expect(json['miniProgramId'], 'firebase_coupon');
    expect(json['accessMode'], 'public');
    expect(json['accessKeyIncluded'], isFalse);
    expect(json.containsKey('accessKey'), isFalse);
    expect(
      json['backendBaseUrl'],
      'https://asia-south1-coupon-prod.cloudfunctions.net/publisherBackend',
    );
    expect(
      packagePath,
      p.normalize(
        p.absolute(
          p.join(
            standaloneRoot,
            'firebase_coupon-my-firebase-prod.partner.json',
          ),
        ),
      ),
    );
    expect(
      json['hostImportCommandText'],
      contains('miniprogram host endpoint import'),
    );

    final decodedPackage =
        jsonDecode(await File(packagePath).readAsString())
            as Map<String, dynamic>;
    expect(decodedPackage['schemaVersion'], 2);
    expect(decodedPackage['type'], 'mini_program_partner_handoff');
    expect(decodedPackage['accessMode'], 'public');
    expect(decodedPackage.containsKey('accessKey'), isFalse);
    expect(
      decodedPackage['backendBaseUrl'],
      'https://asia-south1-coupon-prod.cloudfunctions.net/publisherBackend',
    );

    final importExitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: hostRoot,
        ).run(<String>[
          'host',
          'endpoint',
          'import',
          packagePath,
          '--project-root',
          hostRoot,
        ]);
    expect(importExitCode, 0);
    final endpointSource = await File(
      p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
    ).readAsString();
    expect(endpointSource, contains('firebase_coupon'));
    expect(endpointSource, contains('backendBaseUri'));
  });

  test(
    'publisher-backend firebase handoff redacts protected access key',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'firebase_coupon',
        version: '1.0.0',
      );
      await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
      const accessKey = 'mpk_live_partner_123456789012345';
      final textOutputPath = p.join(
        tempDir.path,
        'protected-text.partner.json',
      );
      final textStdout = StringBuffer();

      final textExitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: textStdout,
            stderrSink: StringBuffer(),
            workingDirectory: standaloneRoot,
          ).run(<String>[
            'publisher-backend',
            'firebase',
            'handoff',
            '--env',
            'my-firebase-prod',
            '--delivery-url',
            'https://cdn.example.com/public_mini_program/',
            '--access-key',
            accessKey,
            '--output',
            textOutputPath,
          ]);

      expect(textExitCode, 0);
      expect(textStdout.toString(), contains('Access key included: true'));
      expect(textStdout.toString(), isNot(contains(accessKey)));

      final jsonOutputPath = p.join(
        tempDir.path,
        'protected-json.partner.json',
      );
      final jsonStdout = StringBuffer();
      final jsonExitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: jsonStdout,
            stderrSink: StringBuffer(),
            workingDirectory: standaloneRoot,
          ).run(<String>[
            'publisher-backend',
            'firebase',
            'handoff',
            '--env',
            'my-firebase-prod',
            '--delivery-url',
            'https://cdn.example.com/public_mini_program/',
            '--access-key',
            accessKey,
            '--output',
            jsonOutputPath,
            '--json',
          ]);

      expect(jsonExitCode, 0);
      expect(jsonStdout.toString(), isNot(contains(accessKey)));
      final json = jsonDecode(jsonStdout.toString()) as Map<String, dynamic>;
      expect(json['accessMode'], 'protected');
      expect(json['accessKeyIncluded'], isTrue);
      expect(json.containsKey('accessKey'), isFalse);

      final decodedPackage =
          jsonDecode(await File(jsonOutputPath).readAsString())
              as Map<String, dynamic>;
      expect(decodedPackage['accessKey'], accessKey);
    },
  );

  test('publisher-backend firebase handoff validates usage', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_coupon',
      version: '1.0.0',
    );
    await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
    final stderrBuffer = StringBuffer();

    final missingModeExitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'handoff',
          '--env',
          'my-firebase-prod',
          '--delivery-url',
          'https://cdn.example.com/public_mini_program/',
        ]);

    expect(missingModeExitCode, 64);
    expect(stderrBuffer.toString(), contains('requires --access-key'));

    final badUrlExitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'handoff',
          '--env',
          'my-firebase-prod',
          '--delivery-url',
          'not-a-url',
          '--public',
        ]);

    expect(badUrlExitCode, 64);
    expect(stderrBuffer.toString(), contains('expected an absolute'));

    final bothModesExitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'handoff',
          '--env',
          'my-firebase-prod',
          '--delivery-url',
          'https://cdn.example.com/public_mini_program/',
          '--access-key',
          'mpk_live_partner_123456789012345',
          '--public',
        ]);

    expect(bothModesExitCode, 64);
    expect(stderrBuffer.toString(), contains('cannot use both'));
  });

  test(
    'publisher-backend firebase access-key create/list redacts hashes',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'firebase_coupon',
        version: '1.0.0',
      );
      await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
      final writes = <String, Object?>{};
      final stdoutBuffer = StringBuffer();
      final accessKey = 'mpk_live_partner_123456789012345';
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        publisherBackendStarter: PublisherBackendStarter(
          firebaseAccessTokenProvider: () async => 'firebase-token',
          clock: () => DateTime.utc(2026, 6),
          httpRequester: (method, uri, {headers, body}) async {
            expect(headers?['authorization'], 'Bearer firebase-token');
            if (method == 'GET' && uri.path.endsWith('/accessKeys/host-a')) {
              return http.Response('{}', 404);
            }
            if (method == 'PATCH' && uri.path.endsWith('/accessKeys/host-a')) {
              writes[uri.path] = body;
              return http.Response('{}', 200);
            }
            if (method == 'GET' && uri.path.endsWith('/accessKeys')) {
              return http.Response(
                _firestoreDocumentsJsonFrom(
                  'firebase_coupon',
                  'accessKeys',
                  <String, Map<String, Object?>>{
                    'host-a': <String, Object?>{
                      'keyId': 'host-a',
                      'keyHash': 'hash-that-must-not-appear-in-list-output',
                      'lastFour': '2345',
                      'active': true,
                      'createdAtUtc': '2026-06-01T00:00:00.000Z',
                      'updatedAtUtc': '2026-06-01T00:00:00.000Z',
                    },
                  },
                ),
                200,
              );
            }
            fail('Unexpected Firebase HTTP request: $method $uri');
          },
        ),
        workingDirectory: standaloneRoot,
      );

      final createExitCode = await cli.run(<String>[
        'publisher-backend',
        'firebase',
        'access-key',
        'create',
        '--env',
        'my-firebase-prod',
        '--key-id',
        'host-a',
        '--key',
        accessKey,
        '--json',
      ]);

      expect(createExitCode, 0);
      final createJson =
          jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(
        createJson['command'],
        'publisher-backend firebase access-key create',
      );
      expect(createJson['accessKey'], accessKey);
      expect(createJson['keyId'], 'host-a');
      expect(stdoutBuffer.toString(), isNot(contains('hash-that')));
      expect(writes, isNotEmpty);
      final writeBody = writes.values.single.toString();
      expect(writeBody, contains('keyHash'));
      expect(writeBody, contains('lastFour'));
      expect(writeBody, isNot(contains(accessKey)));

      stdoutBuffer.clear();
      final listExitCode = await cli.run(<String>[
        'publisher-backend',
        'firebase',
        'access-key',
        'list',
        '--env',
        'my-firebase-prod',
        '--json',
      ]);

      expect(listExitCode, 0);
      expect(stdoutBuffer.toString(), isNot(contains(accessKey)));
      expect(
        stdoutBuffer.toString(),
        isNot(contains('hash-that-must-not-appear-in-list-output')),
      );
      final listJson =
          jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(listJson['activeKeyCount'], 1);
      expect(listJson['keys'], hasLength(1));
      expect((listJson['keys'] as List).single['lastFour'], '2345');
    },
  );

  test('publisher-backend firebase access-key revoke and rotate', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_coupon',
      version: '1.0.0',
    );
    await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
    final patchedPaths = <String>[];
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        clock: () => DateTime.utc(2026, 6, 1, 1),
        httpRequester: (method, uri, {headers, body}) async {
          if (method == 'GET' && uri.path.endsWith('/accessKeys/host-a')) {
            return http.Response(
              _firestoreDocumentJson(<String, Object?>{
                'keyId': 'host-a',
                'keyHash': 'old-hash',
                'lastFour': '0000',
                'active': true,
                'createdAtUtc': '2026-06-01T00:00:00.000Z',
                'updatedAtUtc': '2026-06-01T00:00:00.000Z',
              }),
              200,
            );
          }
          if (method == 'GET' && uri.path.endsWith('/accessKeys/host-b')) {
            return http.Response('{}', 404);
          }
          if (method == 'PATCH' && uri.path.contains('/accessKeys/')) {
            patchedPaths.add(uri.path);
            return http.Response('{}', 200);
          }
          fail('Unexpected Firebase HTTP request: $method $uri');
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final revokeExitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'access-key',
      'revoke',
      '--env',
      'my-firebase-prod',
      '--key-id',
      'host-a',
      '--json',
    ]);

    expect(revokeExitCode, 0);
    final revokeJson =
        jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(
      revokeJson['command'],
      'publisher-backend firebase access-key revoke',
    );
    expect(revokeJson['keyId'], 'host-a');

    stdoutBuffer.clear();
    final rotateExitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'access-key',
      'rotate',
      '--env',
      'my-firebase-prod',
      '--key-id',
      'host-a',
      '--new-key-id',
      'host-b',
      '--key',
      'mpk_live_replacement_123456789012',
      '--json',
    ]);

    expect(rotateExitCode, 0);
    final rotateJson =
        jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(
      rotateJson['command'],
      'publisher-backend firebase access-key rotate',
    );
    expect(rotateJson['revokedKeyId'], 'host-a');
    expect(rotateJson['newKeyId'], 'host-b');
    expect(rotateJson['accessKey'], 'mpk_live_replacement_123456789012');
    expect(
      patchedPaths.where((path) => path.endsWith('/accessKeys/host-a')),
      isNotEmpty,
    );
    expect(
      patchedPaths.where((path) => path.endsWith('/accessKeys/host-b')),
      isNotEmpty,
    );
  });

  test(
    'publisher-backend firebase host-command JSON reports host ready',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'firebase_coupon',
        version: '1.0.0',
      );
      await _writeEmbeddedHostFixture(hostRoot);
      await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
      final hostAddExitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'endpoint',
            'add',
            'firebase_coupon',
            '--title',
            'Firebase Coupon',
            '--api-base-url',
            'https://cdn.example.com/public_mini_program/',
            '--public',
            '--backend-base-url',
            'https://asia-south1-coupon-prod.cloudfunctions.net/publisherBackend/',
          ]);
      expect(hostAddExitCode, 0);
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
            'host-command',
            '--env',
            'my-firebase-prod',
            '--api-base-url',
            'https://cdn.example.com/public_mini_program/',
            '--public',
            '--host-project-root',
            hostRoot,
            '--json',
          ]);

      expect(exitCode, 0);
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['command'], 'publisher-backend firebase host-command');
      expect(json['miniProgramId'], 'firebase_coupon');
      expect(json['accessMode'], 'public');
      expect(json['hostEndpointChecked'], isTrue);
      expect(json['hostEndpointReady'], isTrue);
      expect(json['hostEndpointFound'], isTrue);
      expect(json['hostEndpointIssues'], isEmpty);
      expect(
        json['hostEndpointCommandText'],
        contains('--project-root ${p.normalize(p.absolute(hostRoot))}'),
      );
    },
  );

  test(
    'publisher-backend firebase host-command reports host mismatch',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'firebase_coupon',
        version: '1.0.0',
      );
      await _writeEmbeddedHostFixture(hostRoot);
      await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
      final hostAddExitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'endpoint',
            'add',
            'firebase_coupon',
            '--title',
            'Firebase Coupon',
            '--api-base-url',
            'https://cdn.example.com/public_mini_program/',
            '--public',
            '--backend-base-url',
            'https://old.example.com/publisherBackend/',
          ]);
      expect(hostAddExitCode, 0);
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
            'host-command',
            '--env',
            'my-firebase-prod',
            '--api-base-url',
            'https://cdn.example.com/public_mini_program/',
            '--public',
            '--host-project-root',
            hostRoot,
          ]);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Host endpoint ready: false'));
      expect(
        stdoutBuffer.toString(),
        contains('Publisher backend base URL differs'),
      );
    },
  );

  test(
    'publisher-backend firebase host-command reports missing host auth controller',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'firebase_coupon',
        version: '1.0.0',
      );
      await _writeEmbeddedHostFixture(hostRoot);
      await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
      final hostAddExitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            workingDirectory: hostRoot,
          ).run(<String>[
            'host',
            'endpoint',
            'add',
            'firebase_coupon',
            '--title',
            'Firebase Coupon',
            '--api-base-url',
            'https://cdn.example.com/public_mini_program/',
            '--public',
            '--backend-base-url',
            'https://asia-south1-coupon-prod.cloudfunctions.net/publisherBackend/',
          ]);
      expect(hostAddExitCode, 0);
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
            'host-command',
            '--env',
            'my-firebase-prod',
            '--api-base-url',
            'https://cdn.example.com/public_mini_program/',
            '--public',
            '--host-project-root',
            hostRoot,
          ]);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('Host endpoint ready: true'));
      expect(
        stdoutBuffer.toString(),
        contains('Host auth controller ready: false'),
      );
      expect(
        stdoutBuffer.toString(),
        contains('Host runtime setup does not configure'),
      );
    },
  );

  test('publisher-backend firebase auth status reports ready setup', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    final hostRoot = p.join(tempDir.path, 'host_app');
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
    await File(
      p.join(
        standaloneRoot,
        'backend',
        'firebase_functions',
        'functions',
        '.env',
      ),
    ).writeAsString('PUBLISHER_AUTH_WEB_API_KEY=fake-web-api-key\n');
    await _writeEmbeddedHostFixture(hostRoot);
    await File(
      p.join(
        hostRoot,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    ).writeAsString('''
  import 'package:mini_program_sdk/mini_program_sdk.dart';

  MiniProgramConfig buildMiniProgramConfig() {
    return MiniProgramConfig(
  sdkVersion: '1.0.0',
  source: throw UnimplementedError(),
  hostBridge: throw UnimplementedError(),
  capabilityRegistry: throw UnimplementedError(),
  authController: MiniProgramAuthController.secure(),
  disposeAuthController: true,
    );
  }
  ''');
    await _writeFirebaseEnvironmentState(
      stateStore,
      standaloneRoot,
      authWebApiKey: 'fake-web-api-key',
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
          'auth',
          'status',
          '--env',
          'my-firebase-prod',
          '--host-project-root',
          hostRoot,
          '--json',
        ]);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), isNot(contains('fake-web-api-key')));
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend firebase auth status');
    expect(json['authWebApiKeyConfigured'], isTrue);
    expect(json['scaffoldExists'], isTrue);
    expect(json['authServiceFileExists'], isTrue);
    expect(json['routerAuthRoutesReady'], isTrue);
    expect(json['routerAllowsAuthorizationHeader'], isTrue);
    expect(json['packageJsonHasFirebaseAdmin'], isTrue);
    expect(json['envAuthKeyConfigured'], isTrue);
    expect(json['envUsesReservedAuthKey'], isFalse);
    expect(json['deployEnvReady'], isTrue);
    expect(json['ready'], isTrue);
    expect(json['issues'], isEmpty);
    expect(json['hostAuthChecked'], isTrue);
    expect(json['hostAuthControllerReady'], isTrue);
    expect(json['hostSecureAuthControllerConfigured'], isTrue);
    expect(json['hostDisposeAuthControllerConfigured'], isTrue);
    expect(json['hostAuthIssues'], isEmpty);
  });

  test(
    'publisher-backend firebase auth status reports missing env key',
    () async {
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

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: StringBuffer(),
            workingDirectory: standaloneRoot,
          ).run(<String>[
            'publisher-backend',
            'firebase',
            'auth',
            'status',
            '--env',
            'my-firebase-prod',
            '--json',
          ]);

      expect(exitCode, 1);
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['authWebApiKeyConfigured'], isFalse);
      expect(json['ready'], isFalse);
      expect(
        (json['issues'] as List).join('\n'),
        contains('missing --auth-web-api-key'),
      );
      expect(
        (json['warnings'] as List).join('\n'),
        contains('Functions .env was not found yet'),
      );
    },
  );

  test('publisher-backend firebase host-command validates usage', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_coupon',
      version: '1.0.0',
    );
    await _writeFirebaseEnvironmentState(stateStore, standaloneRoot);
    final stderrBuffer = StringBuffer();

    final missingModeExitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'host-command',
          '--env',
          'my-firebase-prod',
          '--api-base-url',
          'https://cdn.example.com/public_mini_program/',
        ]);

    expect(missingModeExitCode, 64);
    expect(stderrBuffer.toString(), contains('requires --access-key'));

    final badUrlExitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'host-command',
          '--env',
          'my-firebase-prod',
          '--api-base-url',
          'not-a-url',
          '--public',
        ]);

    expect(badUrlExitCode, 64);
    expect(stderrBuffer.toString(), contains('expected an absolute'));

    final bothModesExitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'host-command',
          '--env',
          'my-firebase-prod',
          '--api-base-url',
          'https://cdn.example.com/public_mini_program/',
          '--public',
          '--access-key',
          'mpk_live_partner_123',
        ]);

    expect(bothModesExitCode, 64);
    expect(stderrBuffer.toString(), contains('cannot use both'));
  });

  test('publisher-backend firebase smoke prints route checks', () async {
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
      'smoke',
      '--env',
      'my-firebase-prod',
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Firebase Functions publisher backend smoke test.'),
    );
    expect(stdoutBuffer.toString(), contains('Passed: true'));
    expect(stdoutBuffer.toString(), contains('GET /health: 200 OK'));
    expect(stdoutBuffer.toString(), contains('GET /home/bootstrap: 200 OK'));
    expect(stdoutBuffer.toString(), contains('GET /coupons/list: 200 OK'));
    expect(
      stdoutBuffer.toString(),
      contains('GET /auth/session: 401 OK (auth_required)'),
    );
  });

  test('publisher-backend firebase smoke prints write verification', () async {
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
        postRequester: (uri, {headers, body}) async {
          return http.Response(
            jsonEncode(<String, Object?>{
              'status': 'redeemed',
              'couponId': 'coupon-20',
              'userId': 'preview-user',
            }),
            200,
          );
        },
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/auth/session')) {
            return http.Response(
              jsonEncode(<String, Object?>{'errorCode': 'auth_required'}),
              401,
            );
          }
          return http.Response(
            _firestoreDocumentJson(<String, Object?>{
              'status': 'redeemed',
              'couponId': 'coupon-20',
              'userId': 'preview-user',
            }),
            200,
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'smoke',
      '--env',
      'my-firebase-prod',
      '--include-write',
      '--write-coupon-id',
      'coupon-20',
      '--write-user-id',
      'preview-user',
    ]);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('Write smoke: true'));
    expect(stdoutBuffer.toString(), contains('Write coupon ID: coupon-20'));
    expect(stdoutBuffer.toString(), contains('Write user ID: preview-user'));
    expect(
      stdoutBuffer.toString(),
      contains('POST /coupon/redeem: 200 OK (redeemed) [Firestore verified]'),
    );
    expect(
      stdoutBuffer.toString(),
      contains(
        'miniPrograms/firebase_coupon/redemptions/preview-user_coupon-20',
      ),
    );
  });

  test('publisher-backend firebase smoke prints write JSON', () async {
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
        postRequester: (uri, {headers, body}) async {
          return http.Response(
            jsonEncode(<String, Object?>{'status': 'already_redeemed'}),
            200,
          );
        },
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/auth/session')) {
            return http.Response(
              jsonEncode(<String, Object?>{'errorCode': 'auth_required'}),
              401,
            );
          }
          return http.Response(
            _firestoreDocumentJson(<String, Object?>{
              'status': 'redeemed',
              'couponId': 'coupon-10',
              'userId': 'smoke-user',
            }),
            200,
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'smoke',
      '--env',
      'my-firebase-prod',
      '--include-write',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend firebase smoke');
    expect(json['includeWrite'], isTrue);
    expect(json['writeCouponId'], 'coupon-10');
    expect(json['writeUserId'], 'smoke-user');
    final routes = json['routes'] as List<Object?>;
    final writeRoute = routes.cast<Map<String, dynamic>>().singleWhere(
      (route) => route['method'] == 'POST' && route['path'] == '/coupon/redeem',
    );
    expect(writeRoute['method'], 'POST');
    expect(writeRoute['path'], '/coupon/redeem');
    expect(writeRoute['responseStatus'], 'already_redeemed');
    expect(writeRoute['redemptionVerified'], isTrue);
    expect(
      writeRoute['redemptionDocumentPath'],
      'miniPrograms/firebase_coupon/redemptions/smoke-user_coupon-10',
    );
  });

  test('publisher-backend firebase smoke prints auth verification', () async {
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
    var signedOut = false;
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        postRequester: (uri, {headers, body}) async {
          final path = uri.path;
          if (path.endsWith('/auth/email/sign-up')) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'errorCode': 'email_already_exists',
              }),
              409,
            );
          }
          if (path.endsWith('/auth/email/sign-in')) {
            return http.Response(
              _authSmokeSessionJson(
                idToken: 'secret-id-token-1',
                refreshToken: 'secret-refresh-token-1',
              ),
              200,
            );
          }
          if (path.endsWith('/auth/refresh')) {
            return http.Response(
              _authSmokeSessionJson(
                idToken: 'secret-id-token-2',
                refreshToken: 'secret-refresh-token-2',
              ),
              200,
            );
          }
          if (path.endsWith('/auth/sign-out')) {
            signedOut = true;
            return http.Response(
              jsonEncode(<String, Object?>{'status': 'signed_out'}),
              200,
            );
          }
          return http.Response('{}', 404);
        },
        httpRequester: (method, uri, {headers, body}) async {
          if (!signedOut &&
              headers?['authorization'] == 'Bearer secret-id-token-2') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'authenticated': true,
                'user': <String, Object?>{
                  'uid': 'firebase-user-1',
                  'email': 'auth-smoke@example.com',
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{'errorCode': 'auth_session_revoked'}),
            401,
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'smoke',
      '--env',
      'my-firebase-prod',
      '--include-auth',
      '--auth-email',
      'auth-smoke@example.com',
      '--auth-password',
      'secret-password',
      '--auth-create-user',
    ]);

    final output = stdoutBuffer.toString();
    expect(exitCode, 0);
    expect(output, contains('Auth smoke: true'));
    expect(output, contains('Auth email: auth-smoke@example.com'));
    expect(output, contains('Auth create user: true'));
    expect(
      output,
      contains('POST /auth/email/sign-up: 409 OK (email_already_exists)'),
    );
    expect(
      output,
      contains('POST /auth/email/sign-in: 200 OK (authenticated)'),
    );
    expect(output, contains('POST /auth/refresh: 200 OK (refreshed)'));
    expect(output, contains('POST /auth/sign-out: 200 OK (signed_out)'));
    expect(output, isNot(contains('secret-password')));
    expect(output, isNot(contains('secret-id-token')));
    expect(output, isNot(contains('secret-refresh-token')));
  });

  test('publisher-backend firebase smoke prints auth JSON redacted', () async {
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
    var signedOut = false;
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        postRequester: (uri, {headers, body}) async {
          if (uri.path.endsWith('/auth/email/sign-in')) {
            return http.Response(
              _authSmokeSessionJson(
                idToken: 'json-id-token-1',
                refreshToken: 'json-refresh-token-1',
              ),
              200,
            );
          }
          if (uri.path.endsWith('/auth/refresh')) {
            return http.Response(
              _authSmokeSessionJson(
                idToken: 'json-id-token-2',
                refreshToken: 'json-refresh-token-2',
              ),
              200,
            );
          }
          if (uri.path.endsWith('/auth/sign-out')) {
            signedOut = true;
            return http.Response(
              jsonEncode(<String, Object?>{'status': 'signed_out'}),
              200,
            );
          }
          return http.Response('{}', 404);
        },
        httpRequester: (method, uri, {headers, body}) async {
          if (!signedOut &&
              headers?['authorization'] == 'Bearer json-id-token-2') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'authenticated': true,
                'user': <String, Object?>{'uid': 'firebase-user-1'},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{'errorCode': 'auth_session_revoked'}),
            401,
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'smoke',
      '--env',
      'my-firebase-prod',
      '--include-auth',
      '--auth-email',
      'auth-smoke@example.com',
      '--auth-password',
      'json-secret-password',
      '--json',
    ]);

    final output = stdoutBuffer.toString();
    expect(exitCode, 0);
    expect(output, isNot(contains('json-secret-password')));
    expect(output, isNot(contains('json-id-token')));
    expect(output, isNot(contains('json-refresh-token')));
    final json = jsonDecode(output) as Map<String, dynamic>;
    expect(json['includeAuth'], isTrue);
    expect(json['authEmail'], 'auth-smoke@example.com');
    final routes = (json['routes'] as List<Object?>)
        .cast<Map<String, dynamic>>();
    expect(
      routes.map((route) => route['path']),
      containsAll(<String>[
        '/auth/email/sign-in',
        '/auth/refresh',
        '/auth/session',
        '/auth/sign-out',
      ]),
    );
  });

  test(
    'publisher-backend firebase smoke returns 1 when a route fails',
    () async {
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
          healthGetter: (uri) async {
            if (uri.path.endsWith('/coupons/list')) {
              return http.Response('nope', 500);
            }
            return http.Response('{"ok":true}', 200);
          },
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
        'smoke',
        '--env',
        'my-firebase-prod',
      ]);

      expect(exitCode, 1);
      expect(stdoutBuffer.toString(), contains('Passed: false'));
      expect(stdoutBuffer.toString(), contains('GET /coupons/list: 500 FAIL'));
    },
  );

  test(
    'publisher-backend firebase smoke rejects write options without write smoke',
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
        'publisher-backend',
        'firebase',
        'smoke',
        '--env',
        'my-firebase-prod',
        '--write-coupon-id',
        'coupon-20',
      ]);

      expect(exitCode, 64);
      expect(stderrBuffer.toString(), contains('require --include-write'));
      expect(stdoutBuffer.toString(), isEmpty);
    },
  );

  test(
    'publisher-backend firebase smoke rejects auth options without auth smoke',
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
        'publisher-backend',
        'firebase',
        'smoke',
        '--env',
        'my-firebase-prod',
        '--auth-email',
        'auth-smoke@example.com',
      ]);

      expect(exitCode, 64);
      expect(stderrBuffer.toString(), contains('require --include-auth'));
      expect(stdoutBuffer.toString(), isEmpty);
    },
  );

  test('publisher-backend firebase smoke sends access key header', () async {
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
    final seenHeaders = <Map<String, String>?>[];
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        httpRequester: (method, uri, {headers, body}) async {
          seenHeaders.add(headers);
          if (uri.path.endsWith('/auth/session')) {
            return http.Response(
              jsonEncode(<String, Object?>{'errorCode': 'auth_required'}),
              401,
            );
          }
          return http.Response('{"ok":true}', 200);
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'smoke',
      '--env',
      'my-firebase-prod',
      '--access-key',
      'mpk_live_partner_123456789012345',
      '--json',
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      isNot(contains('mpk_live_partner_123456789012345')),
    );
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['accessKeyProvided'], isTrue);
    expect(
      seenHeaders.where(
        (headers) =>
            headers?['x-mini-program-access-key'] ==
            'mpk_live_partner_123456789012345',
      ),
      hasLength(4),
    );
  });

  test(
    'publisher-backend firebase smoke help includes write options',
    () async {
      final stdoutBuffer = StringBuffer();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: tempDir.path,
      ).run(<String>['publisher-backend', 'firebase', 'smoke', '--help']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('--include-write'));
      expect(stdoutBuffer.toString(), contains('--include-auth'));
      expect(stdoutBuffer.toString(), contains('--write-coupon-id'));
      expect(stdoutBuffer.toString(), contains('--write-user-id'));
      expect(stdoutBuffer.toString(), contains('--auth-email'));
      expect(stdoutBuffer.toString(), contains('--auth-password'));
      expect(stdoutBuffer.toString(), contains('--auth-create-user'));
      expect(stdoutBuffer.toString(), contains('--access-key'));
    },
  );

  test('publisher-backend firebase seed prints text output', () async {
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
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async =>
            http.Response('{}', 200),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'seed',
      '--env',
      'my-firebase-prod',
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Firebase Firestore publisher backend seed.'),
    );
    expect(stdoutBuffer.toString(), contains('Seeded: true'));
    expect(stdoutBuffer.toString(), contains('Items written: 4'));
  });

  test('publisher-backend firebase data status prints JSON', () async {
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
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/home') || uri.path.endsWith('/sessions')) {
            return http.Response(_firestoreDocumentsJson(1), 200);
          }
          if (uri.path.endsWith('/coupons')) {
            return http.Response(_firestoreDocumentsJson(2), 200);
          }
          return http.Response(_firestoreDocumentsJson(0), 200);
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'data',
      'status',
      '--env',
      'my-firebase-prod',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend firebase data status');
    expect(json['available'], isTrue);
    expect(json['appRecordCount'], 4);
    expect(json['couponCount'], 2);
  });

  test('publisher-backend firebase data export prints JSON', () async {
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
    final outputPath = p.join(tempDir.path, 'firebase-export.json');
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/home')) {
            return http.Response(
              _firestoreDocumentsJsonFrom(
                'firebase_coupon',
                'home',
                <String, Map<String, Object?>>{
                  'bootstrap': <String, Object?>{'title': 'Home'},
                },
              ),
              200,
            );
          }
          return http.Response(_firestoreDocumentsJson(0), 200);
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'data',
      'export',
      '--env',
      'my-firebase-prod',
      '--output',
      outputPath,
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend firebase data export');
    expect(json['exported'], isTrue);
    expect(json['appRecordCount'], 1);
    expect(await File(outputPath).exists(), isTrue);
  });

  test('publisher-backend firebase data import dry-run prints text', () async {
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
    final inputPath = p.join(tempDir.path, 'firebase-export.json');
    await File(
      inputPath,
    ).writeAsString(jsonEncode(_firebaseExportFixture('firebase_coupon')));
    final stdoutBuffer = StringBuffer();

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          publisherBackendStarter: PublisherBackendStarter(
            firebaseAccessTokenProvider: () async => 'firebase-token',
            httpRequester: (method, uri, {headers, body}) async =>
                http.Response('{}', 200),
          ),
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'data',
          'import',
          '--env',
          'my-firebase-prod',
          '--input',
          inputPath,
          '--dry-run',
        ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Firebase Firestore publisher backend data import.'),
    );
    expect(stdoutBuffer.toString(), contains('Dry run: true'));
    expect(stdoutBuffer.toString(), contains('Imported: false'));
  });

  test('publisher-backend firebase data redemptions prints JSON', () async {
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
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          return http.Response(
            _firestoreDocumentsJsonFrom(
              'firebase_coupon',
              'redemptions',
              <String, Map<String, Object?>>{
                'user_coupon': <String, Object?>{
                  'status': 'redeemed',
                  'couponId': 'coupon-10',
                  'userId': 'preview-user',
                  'redeemedAtUtc': '2026-05-24T12:00:00Z',
                },
              },
            ),
            200,
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'firebase',
      'data',
      'redemptions',
      '--env',
      'my-firebase-prod',
      '--coupon-id',
      'coupon-10',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend firebase data redemptions');
    expect(json['matchedCount'], 1);
    expect(json['returnedCount'], 1);
  });

  test('publisher-backend firebase destroy blocks Firestore data', () async {
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

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          publisherBackendStarter: PublisherBackendStarter(
            firebaseAccessTokenProvider: () async => 'firebase-token',
            httpRequester: (method, uri, {headers, body}) async {
              if (uri.path.endsWith('/home')) {
                return http.Response(_firestoreDocumentsJson(1), 200);
              }
              return http.Response(_firestoreDocumentsJson(0), 200);
            },
          ),
          workingDirectory: standaloneRoot,
        ).run(<String>[
          'publisher-backend',
          'firebase',
          'destroy',
          '--env',
          'my-firebase-prod',
          '--yes',
        ]);

    expect(exitCode, 1);
    expect(stdoutBuffer.toString(), contains('Blocked by data: true'));
    expect(stdoutBuffer.toString(), contains('--confirm-data-loss'));
  });

  test('publisher-backend firebase help includes operations', () async {
    final stdoutBuffer = StringBuffer();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['publisher-backend', 'firebase', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('deploy --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('status --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('outputs --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('host-command --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('handoff --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('auth status --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('smoke --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('seed --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('data status --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('data export --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('data import --env <env-name>'));
    expect(
      stdoutBuffer.toString(),
      contains('data redemptions --env <env-name>'),
    );
    expect(stdoutBuffer.toString(), contains('destroy --env <env-name>'));
  });
}
