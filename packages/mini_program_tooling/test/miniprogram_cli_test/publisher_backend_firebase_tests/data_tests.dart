part of '../../miniprogram_cli_test.dart';

void _registerPublisherBackendFirebaseDataTests() {
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
}
