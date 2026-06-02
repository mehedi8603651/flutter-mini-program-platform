part of '../../miniprogram_cli_test.dart';

void _registerPublisherBackendFirebaseAccessKeyAuthTests() {
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
}
