part of '../publisher_backend_starter_test.dart';

void _registerFirebaseCloudTests() {
  test('deploys Firebase Functions backend and records outputs', () async {
    final commands = <String>[];
    final workingDirectories = <String?>[];
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        commands.add('$executable ${arguments.join(' ')}');
        workingDirectories.add(workingDirectory);
        return ProcessResult(0, 0, '', '');
      },
      healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        if (uri.host == 'run.googleapis.com') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'bindings': <Object?>[
                <String, Object?>{
                  'role': 'roles/run.invoker',
                  'members': <String>['allUsers'],
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      },
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseDeploy(
      PublisherBackendFirebaseDeployRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
      ),
    );

    expect(result.projectId, 'coupon-prod');
    expect(result.region, 'asia-south1');
    expect(result.functionName, 'publisherBackend');
    expect(
      result.backendBaseUrl,
      'https://asia-south1-coupon-prod.cloudfunctions.net/publisherBackend/',
    );
    expect(result.healthUrl, endsWith('/publisherBackend/health'));
    expect(result.dependenciesInstalled, isTrue);
    expect(result.healthy, isTrue);
    expect(commands, contains('npm install'));
    expect(
      commands,
      contains(
        'firebase deploy --only functions:publisherBackend --project coupon-prod',
      ),
    );
    expect(
      workingDirectories,
      contains(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
        ),
      ),
    );

    final envFile = File(
      p.join(
        miniProgramRoot.path,
        'backend',
        'firebase_functions',
        'functions',
        '.env',
      ),
    );
    expect(await envFile.exists(), isTrue);
    final envText = await envFile.readAsString();
    expect(envText, contains('PUBLISHER_BACKEND_REGION=asia-south1'));
    expect(envText, isNot(contains('FUNCTION_REGION=')));
    expect(envText, contains('MINI_PROGRAM_ID=coupon_app'));

    final stateFile = File(
      p.join(
        miniProgramRoot.path,
        '.mini_program',
        'publisher_backend.firebase.json',
      ),
    );
    expect(await stateFile.exists(), isTrue);
    expect(await stateFile.readAsString(), contains('coupon-prod'));
  });

  test('Firebase deploy preserves unrelated env keys', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
      healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        if (uri.host == 'run.googleapis.com') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'bindings': <Object?>[
                <String, Object?>{
                  'role': 'roles/run.invoker',
                  'members': <String>['allUsers'],
                },
              ],
            }),
            200,
          );
        }
        if (uri.host == 'cloudfunctions.googleapis.com') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'serviceConfig': <String, Object?>{
                'serviceAccountEmail':
                    'publisher-backend@coupon-prod.iam.gserviceaccount.com',
              },
            }),
            200,
          );
        }
        if (uri.host == 'cloudresourcemanager.googleapis.com') {
          if (method == 'GET') {
            return http.Response(
              jsonEncode(<String, Object?>{'projectNumber': '123456789'}),
              200,
            );
          }
          return http.Response('{"bindings":[]}', 200);
        }
        return http.Response('{}', 200);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );
    await Directory(
      p.join(
        miniProgramRoot.path,
        'backend',
        'firebase_functions',
        'functions',
        'node_modules',
      ),
    ).create(recursive: true);
    final envFile = File(
      p.join(
        miniProgramRoot.path,
        'backend',
        'firebase_functions',
        'functions',
        '.env',
      ),
    );
    await envFile.writeAsString(
      'CUSTOM_VALUE=keep\nFUNCTION_REGION=old\nPUBLISHER_BACKEND_REGION=old\nMINI_PROGRAM_ID=old\nPUBLISHER_AUTH_WEB_API_KEY=older\nFIREBASE_AUTH_WEB_API_KEY=old\n',
    );

    await starter.firebaseDeploy(
      PublisherBackendFirebaseDeployRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(
          values: <String, dynamic>{
            'projectId': 'coupon-prod',
            'region': 'asia-south1',
            'functionName': 'publisherBackend',
            'authWebApiKey': 'AIzaSyFakeFirebaseWebApiKey123456789',
          },
        ),
      ),
    );

    final envText = await envFile.readAsString();
    expect(envText, contains('CUSTOM_VALUE=keep'));
    expect(envText, contains('PUBLISHER_BACKEND_REGION=asia-south1'));
    expect(envText, contains('MINI_PROGRAM_ID=coupon_app'));
    expect(
      envText,
      contains(
        'PUBLISHER_AUTH_WEB_API_KEY=AIzaSyFakeFirebaseWebApiKey123456789',
      ),
    );
    expect(envText, isNot(contains('FUNCTION_REGION=old')));
    expect(envText, isNot(contains('PUBLISHER_BACKEND_REGION=old')));
    expect(envText, isNot(contains('MINI_PROGRAM_ID=old')));
    expect(envText, isNot(contains('PUBLISHER_AUTH_WEB_API_KEY=older')));
    expect(envText, isNot(contains('FIREBASE_AUTH_WEB_API_KEY=old')));
  });

  test('Firebase deploy grants auth token creator for email auth', () async {
    final requests = <String>[];
    Object? setIamPolicyBody;
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
      healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        requests.add('$method $uri');
        if (uri.host == 'run.googleapis.com') {
          return http.Response('{"bindings":[]}', 200);
        }
        if (uri.host == 'cloudfunctions.googleapis.com') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'serviceConfig': <String, Object?>{
                'serviceAccountEmail':
                    '1056632163446-compute@developer.gserviceaccount.com',
              },
            }),
            200,
          );
        }
        if (uri.host == 'cloudresourcemanager.googleapis.com' &&
            uri.path.endsWith(':getIamPolicy')) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'etag': 'etag-1',
              'bindings': <Object?>[],
            }),
            200,
          );
        }
        if (uri.host == 'cloudresourcemanager.googleapis.com' &&
            uri.path.endsWith(':setIamPolicy')) {
          setIamPolicyBody = body;
          return http.Response('{}', 200);
        }
        fail('Unexpected Firebase HTTP request: $method $uri');
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );
    await Directory(
      p.join(
        miniProgramRoot.path,
        'backend',
        'firebase_functions',
        'functions',
        'node_modules',
      ),
    ).create(recursive: true);

    final result = await starter.firebaseDeploy(
      PublisherBackendFirebaseDeployRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(
          values: <String, dynamic>{
            'projectId': 'coupon-prod',
            'region': 'asia-south1',
            'functionName': 'publisherBackend',
            'authWebApiKey': 'AIzaSyFakeFirebaseWebApiKey123456789',
          },
        ),
      ),
    );

    expect(result.authTokenCreatorConfigured, isTrue);
    expect(result.authTokenCreatorChanged, isTrue);
    expect(
      result.authTokenCreatorServiceAccount,
      '1056632163446-compute@developer.gserviceaccount.com',
    );
    expect(result.authTokenCreatorError, isNull);
    expect(
      requests,
      contains(
        startsWith(
          'GET https://cloudfunctions.googleapis.com/v2/projects/coupon-prod/locations/asia-south1/functions/publisherBackend',
        ),
      ),
    );
    final decoded = jsonDecode(setIamPolicyBody.toString());
    final bindings = decoded['policy']['bindings'] as List<Object?>;
    final binding = bindings.single as Map<Object?, Object?>;
    expect(binding['role'], 'roles/iam.serviceAccountTokenCreator');
    expect(
      binding['members'],
      contains(
        'serviceAccount:1056632163446-compute@developer.gserviceaccount.com',
      ),
    );
  });

  test('Firebase deploy fails when scaffold is missing', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(
      () => starter.firebaseDeploy(
        PublisherBackendFirebaseDeployRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
  });

  test('Firebase status and outputs use configured function URL', () async {
    final starter = PublisherBackendStarter(
      healthGetter: (uri) async => http.Response('{"ok":true}', 200),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );
    final environment = _firebaseEnvironment(
      values: <String, dynamic>{
        'projectId': 'coupon-prod',
        'region': 'us-central1',
        'functionName': 'publisherBackend',
        'functionUrl': 'https://custom-functions.example.com/publisherBackend',
      },
    );

    final status = await starter.firebaseStatus(
      PublisherBackendFirebaseStatusRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: environment,
      ),
    );
    final outputs = await starter.firebaseOutputs(
      PublisherBackendFirebaseOutputsRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: environment,
      ),
    );

    expect(status.scaffoldExists, isTrue);
    expect(status.healthy, isTrue);
    expect(
      status.backendBaseUrl,
      'https://custom-functions.example.com/publisherBackend/',
    );
    expect(
      status.healthUrl,
      'https://custom-functions.example.com/publisherBackend/health',
    );
    expect(
      outputs.outputs['PublisherBackendBaseUrl'],
      'https://custom-functions.example.com/publisherBackend/',
    );
    expect(outputs.outputs['PublisherBackendStorageMode'], 'firestore');
  });

  test('Firebase smoke checks read-only backend routes', () async {
    final requestedUris = <Uri>[];
    final requestedHttpUris = <Uri>[];
    final starter = PublisherBackendStarter(
      healthGetter: (uri) async {
        requestedUris.add(uri);
        return http.Response('{"ok":true}', 200);
      },
      httpRequester: (method, uri, {headers, body}) async {
        requestedHttpUris.add(uri);
        return http.Response(
          jsonEncode(<String, Object?>{'errorCode': 'auth_required'}),
          401,
        );
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseSmoke(
      PublisherBackendFirebaseSmokeRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
      ),
    );

    expect(result.passed, isTrue);
    expect(
      result.routes.map((route) => '${route.method} ${route.path}'),
      <String>[
        'GET /health',
        'GET /home/bootstrap',
        'GET /coupons/list',
        'GET /auth/session',
      ],
    );
    expect(requestedUris.map((uri) => uri.path), <String>[
      '/publisherBackend/health',
      '/publisherBackend/home/bootstrap',
      '/publisherBackend/coupons/list',
    ]);
    expect(requestedHttpUris.single.path, '/publisherBackend/auth/session');
  });

  test('Firebase smoke retries transient read route failures', () async {
    var healthAttempts = 0;
    final starter = PublisherBackendStarter(
      healthGetter: (uri) async {
        healthAttempts += 1;
        if (uri.path.endsWith('/health') && healthAttempts == 1) {
          throw http.ClientException(
            'Connection terminated during handshake',
            uri,
          );
        }
        return http.Response('{"ok":true}', 200);
      },
      httpRequester: (method, uri, {headers, body}) async => http.Response(
        jsonEncode(<String, Object?>{'errorCode': 'auth_required'}),
        401,
      ),
      delay: (duration) async {},
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseSmoke(
      PublisherBackendFirebaseSmokeRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
      ),
    );

    expect(result.passed, isTrue);
    final health = result.routes.singleWhere(
      (route) => route.path == '/health',
    );
    expect(health.statusCode, 200);
    expect(health.error, isNull);
    expect(healthAttempts, 4);
  });

  test('Firebase write smoke verifies Firestore redemption document', () async {
    final requestedPosts = <Uri>[];
    final requestedFirestoreReads = <Uri>[];
    final requestBodies = <Object?>[];
    final starter = PublisherBackendStarter(
      healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      postRequester: (uri, {headers, body}) async {
        requestedPosts.add(uri);
        requestBodies.add(body);
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
        requestedFirestoreReads.add(uri);
        return http.Response(
          _firestoreDocumentJson(<String, Object?>{
            'status': 'redeemed',
            'couponId': 'coupon-20',
            'userId': 'preview-user',
            'redeemedAtUtc': '2026-05-24T12:00:00Z',
          }),
          200,
        );
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseSmoke(
      PublisherBackendFirebaseSmokeRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
        includeWrite: true,
        writeCouponId: 'coupon-20',
        writeUserId: 'preview-user',
      ),
    );

    expect(result.includeWrite, isTrue);
    expect(result.passed, isTrue);
    final writeRoute = result.routes.singleWhere(
      (route) => route.method == 'POST' && route.path == '/coupon/redeem',
    );
    expect(writeRoute.method, 'POST');
    expect(writeRoute.path, '/coupon/redeem');
    expect(writeRoute.statusCode, 200);
    expect(writeRoute.responseStatus, 'redeemed');
    expect(writeRoute.redemptionVerified, isTrue);
    expect(
      writeRoute.redemptionDocumentPath,
      'miniPrograms/coupon_app/redemptions/preview-user_coupon-20',
    );
    expect(requestedPosts.single.path, '/publisherBackend/coupon/redeem');
    expect(
      jsonDecode(requestBodies.single.toString()),
      containsPair('couponId', 'coupon-20'),
    );
    expect(
      requestedFirestoreReads.single.path,
      contains('/miniPrograms/coupon_app/redemptions/preview-user_coupon-20'),
    );
  });

  test(
    'Firebase write smoke fails when redemption verification fails',
    () async {
      final starter = PublisherBackendStarter(
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        postRequester: (uri, {headers, body}) async {
          return http.Response(
            jsonEncode(<String, Object?>{'status': 'redeemed'}),
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
          return http.Response('{}', 404);
        },
        delay: (duration) async {},
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseSmoke(
        PublisherBackendFirebaseSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
          includeWrite: true,
        ),
      );

      expect(result.passed, isFalse);
      final writeRoute = result.routes.singleWhere(
        (route) => route.method == 'POST' && route.path == '/coupon/redeem',
      );
      expect(writeRoute.responseStatus, 'redeemed');
      expect(writeRoute.redemptionVerified, isFalse);
      expect(writeRoute.verificationError, contains('not found'));
      expect(writeRoute.error, contains('verification failed'));
    },
  );

  test('Firebase smoke fails when a route returns non-200', () async {
    final starter = PublisherBackendStarter(
      healthGetter: (uri) async {
        if (uri.path.endsWith('/coupons/list')) {
          return http.Response('unavailable', 503);
        }
        return http.Response('{"ok":true}', 200);
      },
      httpRequester: (method, uri, {headers, body}) async => http.Response(
        jsonEncode(<String, Object?>{'errorCode': 'auth_required'}),
        401,
      ),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseSmoke(
      PublisherBackendFirebaseSmokeRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
      ),
    );

    expect(result.passed, isFalse);
    final coupons = result.routes.singleWhere(
      (route) => route.path == '/coupons/list',
    );
    expect(coupons.statusCode, 503);
    expect(coupons.passed, isFalse);
  });

  test('Firebase seed writes Firestore starter documents', () async {
    final requests = <Map<String, Object?>>[];
    final starter = PublisherBackendStarter(
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        requests.add(<String, Object?>{
          'method': method,
          'uri': uri.toString(),
          'headers': headers,
          'body': body,
        });
        return http.Response('{}', 200);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseSeed(
      PublisherBackendFirebaseSeedRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
      ),
    );

    expect(result.seeded, isTrue);
    expect(result.itemCount, 4);
    expect(result.couponCount, 2);
    expect(requests.map((request) => request['method']), everyElement('PATCH'));
    expect(
      requests.map((request) => request['uri'].toString()),
      contains(contains('/documents/miniPrograms/coupon_app/home/bootstrap')),
    );
    expect(
      requests.map((request) => request['uri'].toString()),
      contains(
        contains('/documents/miniPrograms/coupon_app/coupons/coupon-10'),
      ),
    );
    final firstBody =
        jsonDecode(requests.first['body']! as String) as Map<String, dynamic>;
    expect(firstBody['fields'], contains('title'));
    final headers = requests.first['headers']! as Map<String, String>;
    expect(headers['authorization'], 'Bearer firebase-token');
  });

  test(
    'Firebase Firestore requests retry once after 401 with fresh token',
    () async {
      var tokenRequests = 0;
      final authorizationHeaders = <String>[];
      final starter = PublisherBackendStarter(
        delay: (_) async {},
        firebaseAccessTokenProvider: () async {
          tokenRequests += 1;
          return tokenRequests == 1 ? 'stale-token' : 'fresh-token';
        },
        httpRequester: (method, uri, {headers, body}) async {
          authorizationHeaders.add(headers?['authorization'] ?? '');
          if (headers?['authorization'] == 'Bearer stale-token') {
            return http.Response('{}', 401);
          }
          return http.Response('{}', 200);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseSeed(
        PublisherBackendFirebaseSeedRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      expect(result.seeded, isTrue);
      expect(authorizationHeaders.first, 'Bearer stale-token');
      expect(authorizationHeaders, contains('Bearer fresh-token'));
      expect(tokenRequests, greaterThanOrEqualTo(2));
    },
  );

  test('Firebase data status counts Firestore collections', () async {
    final requestedPaths = <String>[];
    final starter = PublisherBackendStarter(
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        requestedPaths.add(uri.path);
        if (uri.path.endsWith('/home')) {
          return http.Response(_firestoreDocumentsJson(1), 200);
        }
        if (uri.path.endsWith('/sessions')) {
          return http.Response(_firestoreDocumentsJson(1), 200);
        }
        if (uri.path.endsWith('/coupons')) {
          return http.Response(_firestoreDocumentsJson(2), 200);
        }
        if (uri.path.endsWith('/redemptions')) {
          return http.Response(_firestoreDocumentsJson(3), 200);
        }
        return http.Response('{}', 404);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseDataStatus(
      PublisherBackendFirebaseDataStatusRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
      ),
    );

    expect(result.available, isTrue);
    expect(result.homeRecordCount, 1);
    expect(result.authSessionCount, 1);
    expect(result.couponCount, 2);
    expect(result.redemptionCount, 3);
    expect(result.appRecordCount, 4);
    expect(requestedPaths, hasLength(4));
  });

  test('Firebase data export writes logical app records only', () async {
    final starter = PublisherBackendStarter(
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        if (uri.path.endsWith('/home')) {
          return http.Response(
            _firestoreDocumentsJsonFrom(
              'coupon_app',
              'home',
              <String, Map<String, Object?>>{
                'bootstrap': <String, Object?>{
                  'title': 'Firebase home',
                  'enabled': true,
                  'count': 2,
                  'price': 4.5,
                  'tags': <Object?>['one', null],
                  'meta': <String, Object?>{'tier': 'gold'},
                  'nothing': null,
                  'createdAt': _firestoreTimestamp('2026-05-24T12:00:00Z'),
                },
              },
            ),
            200,
          );
        }
        if (uri.path.endsWith('/sessions')) {
          return http.Response(
            _firestoreDocumentsJsonFrom(
              'coupon_app',
              'sessions',
              <String, Map<String, Object?>>{
                'demo': <String, Object?>{'authenticated': true},
              },
            ),
            200,
          );
        }
        if (uri.path.endsWith('/coupons')) {
          return http.Response(
            _firestoreDocumentsJsonFrom(
              'coupon_app',
              'coupons',
              <String, Map<String, Object?>>{
                'coupon-10': <String, Object?>{'id': 'coupon-10'},
                'coupon-20': <String, Object?>{'id': 'coupon-20'},
              },
            ),
            200,
          );
        }
        if (uri.path.endsWith('/redemptions')) {
          return http.Response(
            _firestoreDocumentsJsonFrom(
              'coupon_app',
              'redemptions',
              <String, Map<String, Object?>>{
                'user_coupon': <String, Object?>{'couponId': 'coupon-10'},
              },
            ),
            200,
          );
        }
        return http.Response('{}', 404);
      },
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );
    final outputPath = p.join(tempDir.path, 'firebase-export.json');

    final result = await starter.firebaseDataExport(
      PublisherBackendFirebaseDataExportRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
        outputPath: outputPath,
      ),
    );

    expect(result.exported, isTrue);
    expect(result.appRecordCount, 4);
    expect(result.redemptionCount, 0);
    final export =
        jsonDecode(await File(outputPath).readAsString())
            as Map<String, dynamic>;
    expect(export['command'], 'publisher-backend firebase data export');
    expect(export['includeRedemptions'], isFalse);
    final records = export['records'] as List<dynamic>;
    expect(records, hasLength(4));
    expect(
      records.map((record) => record['collection']),
      isNot(contains('redemptions')),
    );
    final home =
        records.singleWhere((record) => record['collection'] == 'home')
            as Map<String, dynamic>;
    final data = home['data'] as Map<String, dynamic>;
    expect(data['title'], 'Firebase home');
    expect(data['enabled'], isTrue);
    expect(data['count'], 2);
    expect(data['price'], 4.5);
    expect(data['tags'], <Object?>['one', null]);
    expect(data['meta'], <String, Object?>{'tier': 'gold'});
    expect(data['nothing'], isNull);
    expect(data['createdAt'], '2026-05-24T12:00:00Z');
  });

  test('Firebase data export includes redemptions when requested', () async {
    final starter = PublisherBackendStarter(
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        if (uri.path.endsWith('/home') ||
            uri.path.endsWith('/sessions') ||
            uri.path.endsWith('/coupons')) {
          return http.Response(_firestoreDocumentsJson(0), 200);
        }
        if (uri.path.endsWith('/redemptions')) {
          return http.Response(
            _firestoreDocumentsJsonFrom(
              'coupon_app',
              'redemptions',
              <String, Map<String, Object?>>{
                'preview-user_coupon-10': <String, Object?>{
                  'status': 'redeemed',
                  'couponId': 'coupon-10',
                  'userId': 'preview-user',
                  'redeemedAtUtc': '2026-05-24T12:00:00Z',
                },
              },
            ),
            200,
          );
        }
        return http.Response('{}', 404);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseDataExport(
      PublisherBackendFirebaseDataExportRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
        outputPath: p.join(tempDir.path, 'firebase-export.json'),
        includeRedemptions: true,
      ),
    );

    expect(result.exported, isTrue);
    expect(result.redemptionCount, 1);
    expect(result.itemCount, 1);
  });

  test(
    'Firebase data import dry-run validates and skips redemptions',
    () async {
      final requests = <String>[];
      final starter = PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          requests.add(method);
          return http.Response('{}', 200);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      final inputPath = p.join(tempDir.path, 'firebase-export.json');
      await File(inputPath).writeAsString(
        jsonEncode(_firebaseExportFixture(includeRedemption: true)),
      );

      final result = await starter.firebaseDataImport(
        PublisherBackendFirebaseDataImportRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
          inputPath: inputPath,
          dryRun: true,
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.imported, isFalse);
      expect(result.appRecordCount, 1);
      expect(result.redemptionCount, 0);
      expect(result.skippedRedemptionCount, 1);
      expect(requests, isEmpty);
    },
  );

  test('Firebase data import upserts records and redemptions', () async {
    final requests = <Map<String, Object?>>[];
    final starter = PublisherBackendStarter(
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        requests.add(<String, Object?>{
          'method': method,
          'uri': uri.toString(),
          'body': body,
        });
        return http.Response('{}', 200);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );
    final inputPath = p.join(tempDir.path, 'firebase-export.json');
    await File(inputPath).writeAsString(
      jsonEncode(_firebaseExportFixture(includeRedemption: true)),
    );

    final result = await starter.firebaseDataImport(
      PublisherBackendFirebaseDataImportRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
        inputPath: inputPath,
        includeRedemptions: true,
      ),
    );

    expect(result.imported, isTrue);
    expect(result.itemCount, 2);
    expect(requests.map((request) => request['method']), everyElement('PATCH'));
    expect(
      requests.map((request) => request['uri'].toString()),
      contains(contains('/miniPrograms/coupon_app/redemptions/user_coupon')),
    );
    final body =
        jsonDecode(requests.first['body']! as String) as Map<String, dynamic>;
    expect(body['fields'], contains('title'));
  });

  test('Firebase data redemptions filters and limits records', () async {
    final starter = PublisherBackendStarter(
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        if (uri.path.endsWith('/redemptions')) {
          return http.Response(
            _firestoreDocumentsJsonFrom(
              'coupon_app',
              'redemptions',
              <String, Map<String, Object?>>{
                'a': <String, Object?>{
                  'status': 'redeemed',
                  'couponId': 'coupon-10',
                  'userId': 'preview-user',
                  'redeemedAtUtc': '2026-05-24T10:00:00Z',
                },
                'b': <String, Object?>{
                  'status': 'redeemed',
                  'couponId': 'coupon-10',
                  'userId': 'preview-user',
                  'redeemedAtUtc': '2026-05-24T12:00:00Z',
                },
                'c': <String, Object?>{
                  'status': 'redeemed',
                  'couponId': 'coupon-20',
                  'userId': 'preview-user',
                  'redeemedAtUtc': '2026-05-24T11:00:00Z',
                },
              },
            ),
            200,
          );
        }
        return http.Response('{}', 404);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseDataRedemptions(
      PublisherBackendFirebaseDataRedemptionsRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
        couponId: 'coupon-10',
        userId: 'preview-user',
        limit: 1,
      ),
    );

    expect(result.available, isTrue);
    expect(result.matchedCount, 2);
    expect(result.returnedCount, 1);
    expect(
      (result.records.single['data'] as Map)['redeemedAtUtc'],
      '2026-05-24T12:00:00Z',
    );
  });

  test('Firebase destroy blocks when Firestore data exists', () async {
    var shellCalled = false;
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        shellCalled = true;
        return ProcessResult(0, 0, '', '');
      },
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async {
        if (uri.path.endsWith('/home')) {
          return http.Response(_firestoreDocumentsJson(1), 200);
        }
        return http.Response(_firestoreDocumentsJson(0), 200);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseDestroy(
      PublisherBackendFirebaseDestroyRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
      ),
    );

    expect(result.deleted, isFalse);
    expect(result.blockedByData, isTrue);
    expect(result.error, contains('--confirm-data-loss'));
    expect(shellCalled, isFalse);
  });

  test('Firebase destroy proceeds with data confirmation', () async {
    final commands = <String>[];
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        commands.add('$executable ${arguments.join(' ')}');
        return ProcessResult(0, 0, '', '');
      },
      firebaseAccessTokenProvider: () async => 'firebase-token',
      httpRequester: (method, uri, {headers, body}) async =>
          http.Response(_firestoreDocumentsJson(0), 200),
      clock: () => DateTime.utc(2026, 5, 24, 12),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseDestroy(
      PublisherBackendFirebaseDestroyRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _firebaseEnvironment(),
        confirmDataLoss: true,
      ),
    );

    expect(result.deleted, isTrue);
    expect(result.deletedAtUtc, '2026-05-24T12:00:00.000Z');
    expect(
      commands,
      contains(
        'firebase functions:delete publisherBackend --region asia-south1 --project coupon-prod --force',
      ),
    );
  });
}
