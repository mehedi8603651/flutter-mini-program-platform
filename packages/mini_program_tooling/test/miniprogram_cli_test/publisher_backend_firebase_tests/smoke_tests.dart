part of '../../miniprogram_cli_test.dart';

void _registerPublisherBackendFirebaseSmokeTests() {
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
}
