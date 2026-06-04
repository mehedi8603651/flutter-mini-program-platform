part of '../publisher_backend_starter_test.dart';

void _registerScaffoldTests() {
  test('scaffolds mock backend files and respects force', () async {
    final starter = const PublisherBackendStarter();
    final result = await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
      ),
    );

    expect(result.template, 'mock');
    expect(
      await File(
        p.join(miniProgramRoot.path, 'backend', 'mock', 'bin', 'server.dart'),
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'mock',
          'data',
          'home_bootstrap.json',
        ),
      ).exists(),
      isTrue,
    );

    final readme = File(
      p.join(miniProgramRoot.path, 'backend', 'mock', 'README.md'),
    );
    await readme.writeAsString('custom');
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        force: true,
      ),
    );
    expect(await readme.readAsString(), contains('mock publisher backend'));
  });

  test('scaffolds AWS Lambda backend files and respects force', () async {
    final starter = const PublisherBackendStarter();
    final result = await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
      ),
    );

    expect(result.template, 'aws-lambda');
    expect(
      await File(
        p.join(miniProgramRoot.path, 'backend', 'aws_lambda', 'template.yaml'),
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'aws_lambda',
          'src',
          'handler.mjs',
        ),
      ).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'aws_lambda',
          'src',
          'data',
          'coupons_list.json',
        ),
      ).exists(),
      isTrue,
    );
    final template = await File(
      p.join(miniProgramRoot.path, 'backend', 'aws_lambda', 'template.yaml'),
    ).readAsString();
    final packageJson = await File(
      p.join(
        miniProgramRoot.path,
        'backend',
        'aws_lambda',
        'src',
        'package.json',
      ),
    ).readAsString();
    expect(template, contains('PublisherBackendStorageMode'));
    expect(template, contains('Value: bundled'));
    expect(template, contains('AccessPolicyBucketName'));
    expect(template, contains('PUBLISHER_BACKEND_ACCESS_POLICY_BUCKET'));
    expect(template, contains('s3:GetObject'));
    expect(template, isNot(contains('AWS::DynamoDB::Table')));
    expect(packageJson, contains('@aws-sdk/client-s3'));
    expect(packageJson, isNot(contains('@aws-sdk/client-dynamodb')));

    final readme = File(
      p.join(miniProgramRoot.path, 'backend', 'aws_lambda', 'README.md'),
    );
    await readme.writeAsString('custom');
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'aws-lambda',
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
        force: true,
      ),
    );
    expect(
      await readme.readAsString(),
      contains('AWS Lambda publisher backend'),
    );
  });

  test('scaffolds AWS Lambda DynamoDB storage files', () async {
    final starter = const PublisherBackendStarter();
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
        storageMode: 'dynamodb',
      ),
    );

    final template = await File(
      p.join(miniProgramRoot.path, 'backend', 'aws_lambda', 'template.yaml'),
    ).readAsString();
    final packageJson = await File(
      p.join(
        miniProgramRoot.path,
        'backend',
        'aws_lambda',
        'src',
        'package.json',
      ),
    ).readAsString();
    final readme = await File(
      p.join(miniProgramRoot.path, 'backend', 'aws_lambda', 'README.md'),
    ).readAsString();
    final handler = await File(
      p.join(
        miniProgramRoot.path,
        'backend',
        'aws_lambda',
        'src',
        'handler.mjs',
      ),
    ).readAsString();

    expect(template, contains('AWS::DynamoDB::Table'));
    expect(template, contains('BillingMode: PAY_PER_REQUEST'));
    expect(template, contains('PUBLISHER_BACKEND_STORAGE: dynamodb'));
    expect(template, contains('PUBLISHER_BACKEND_TABLE_NAME'));
    expect(template, contains('MINI_PROGRAM_ID: coupon_app'));
    expect(template, contains('DynamoDBCrudPolicy'));
    expect(template, contains('PublisherBackendDataTableName'));
    expect(packageJson, contains('@aws-sdk/client-dynamodb'));
    expect(packageJson, contains('@aws-sdk/lib-dynamodb'));
    expect(packageJson, contains('@aws-sdk/client-s3'));
    expect(readme, contains('Storage mode: DynamoDB'));
    expect(handler, contains('ConsistentRead: true'));
    expect(handler, contains('LastEvaluatedKey'));
  });

  test(
    'scaffolds Firebase Functions Firestore files and respects force',
    () async {
      final starter = const PublisherBackendStarter();
      final result = await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      expect(result.template, 'firebase-functions');
      expect(result.storageMode, 'firestore');
      final backendRoot = p.join(
        miniProgramRoot.path,
        'backend',
        'firebase_functions',
      );
      expect(await File(p.join(backendRoot, 'firebase.json')).exists(), isTrue);
      expect(
        await File(p.join(backendRoot, 'functions', 'index.js')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(backendRoot, 'functions', 'router.js')).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(backendRoot, 'functions', 'firestore_store.js'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(backendRoot, 'functions', 'auth_service.js'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(backendRoot, 'functions', 'data', 'coupons_list.json'),
        ).exists(),
        isTrue,
      );

      final firebaseJson = await File(
        p.join(backendRoot, 'firebase.json'),
      ).readAsString();
      final packageJson = await File(
        p.join(backendRoot, 'functions', 'package.json'),
      ).readAsString();
      final index = await File(
        p.join(backendRoot, 'functions', 'index.js'),
      ).readAsString();
      final store = await File(
        p.join(backendRoot, 'functions', 'firestore_store.js'),
      ).readAsString();
      final authService = await File(
        p.join(backendRoot, 'functions', 'auth_service.js'),
      ).readAsString();
      final router = await File(
        p.join(backendRoot, 'functions', 'router.js'),
      ).readAsString();
      final readme = File(p.join(backendRoot, 'README.md'));

      expect(firebaseJson, contains('"functions"'));
      expect(packageJson, contains('"node": "22"'));
      expect(packageJson, contains('"firebase-functions": "^7.2.5"'));
      expect(packageJson, contains('"firebase-admin": "^13.10.0"'));
      expect(index, contains("firebase-functions/v2/https"));
      expect(index, contains('createFirestorePublisherBackendStore'));
      expect(index, contains('createFirebasePublisherAuthService'));
      expect(store, contains("collection('miniPrograms')"));
      expect(store, contains("collection('redemptions')"));
      expect(store, contains("collection('authSessions')"));
      expect(authService, contains('signInWithPassword'));
      expect(authService, contains('miniProgramSessionId'));
      expect(authService, contains('hashToken'));
      expect(router, contains('access-control-allow-origin'));
      expect(router, contains('GET /coupons/page'));
      expect(router, contains("routePath === '/coupons/page'"));
      expect(router, contains('POST /auth/email/sign-up'));
      expect(router, contains('authorization'));
      expect(await readme.readAsString(), contains('Storage mode: Firestore'));

      await readme.writeAsString('custom');
      expect(
        () => starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'firestore',
          ),
        ),
        throwsA(isA<PublisherBackendException>()),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
          force: true,
        ),
      );
      expect(
        await readme.readAsString(),
        contains('Firebase publisher backend'),
      );
    },
  );

  test('generates Firebase production starter UI and seed data', () async {
    final starter = const PublisherBackendStarter();
    await File(
      p.join(miniProgramRoot.path, 'pubspec.yaml'),
    ).writeAsString('name: coupon_app_mini_program\n');
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseStarterUi(
      PublisherBackendFirebaseStarterUiRequest(
        miniProgramRootPath: miniProgramRoot.path,
        force: true,
      ),
    );

    expect(result.miniProgramId, 'coupon_app');
    expect(result.entryScreen, 'coupon_app_home');
    expect(result.screenFormat, 'stac');
    expect(result.screenSchemaVersion, isNull);
    expect(result.sourceRootPath, p.join(miniProgramRoot.path, 'stac'));
    expect(result.writtenPaths, hasLength(5));
    expect(result.skippedPaths, isEmpty);
    final helper = await File(
      p.join(miniProgramRoot.path, 'lib', 'host_action_helpers.dart'),
    ).readAsString();
    final screen = await File(
      p.join(miniProgramRoot.path, 'stac', 'screens', 'coupon_app_home.dart'),
    ).readAsString();
    final homeData =
        jsonDecode(
              await File(
                p.join(
                  miniProgramRoot.path,
                  'backend',
                  'firebase_functions',
                  'functions',
                  'data',
                  'home_bootstrap.json',
                ),
              ).readAsString(),
            )
            as Map<String, dynamic>;

    expect(helper, contains('miniProgramShowEmailAuthAction'));
    expect(helper, contains('miniProgramAuthBuilder'));
    expect(helper, contains('miniProgramPagedBackendBuilder'));
    expect(helper, contains('miniProgramLoadMore'));
    expect(screen, contains('miniProgramAuthBuilder'));
    expect(screen, contains("endpoint: 'auth/session'"));
    expect(screen, contains("endpoint: 'coupons/page'"));
    expect(screen, contains('Load more coupons'));
    expect(homeData['heroImageUrl'], contains('picsum.photos'));

    final second = await starter.firebaseStarterUi(
      PublisherBackendFirebaseStarterUiRequest(
        miniProgramRootPath: miniProgramRoot.path,
      ),
    );
    expect(second.writtenPaths, isEmpty);
    expect(second.unchangedPaths, hasLength(5));
    expect(second.skippedPaths, isEmpty);
  });

  test('generates Mp Firebase starter UI for Mp manifests', () async {
    await miniProgramRoot.delete(recursive: true);
    final scaffold = await const MiniProgramScaffolder().scaffold(
      MiniProgramScaffoldRequest(
        outputRootPath: miniProgramRoot.path,
        miniProgramId: 'coupon_app',
      ),
    );
    expect(scaffold.screenFormat, 'mp');
    final starter = const PublisherBackendStarter();
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'firebase-functions',
        storageMode: 'firestore',
      ),
    );

    final result = await starter.firebaseStarterUi(
      PublisherBackendFirebaseStarterUiRequest(
        miniProgramRootPath: miniProgramRoot.path,
        force: true,
      ),
    );

    expect(result.screenFormat, 'mp');
    expect(result.screenSchemaVersion, 1);
    expect(result.sourceRootPath, p.join(miniProgramRoot.path, 'mp'));
    expect(result.skippedPaths, isEmpty);
    final screen = await File(
      p.join(miniProgramRoot.path, 'mp', 'screens', 'coupon_app_home.dart'),
    ).readAsString();
    final program = await File(
      p.join(miniProgramRoot.path, 'mp', 'program.dart'),
    ).readAsString();
    final buildScript = await File(
      p.join(miniProgramRoot.path, 'tool', 'build_mp.dart'),
    ).readAsString();

    expect(screen, contains('Mp.authBuilder('));
    expect(screen, contains("endpoint: 'auth/session'"));
    expect(screen, contains("endpoint: 'coupons/page'"));
    expect(
      screen,
      contains("action: Mp.backend.loadMore(requestId: 'coupons')"),
    );
    expect(program, contains("'coupon_app_home':"));
    expect(buildScript, contains('writeMpBuildOutput(miniProgram'));
    expect(
      await File(
        p.join(miniProgramRoot.path, 'lib', 'host_action_helpers.dart'),
      ).exists(),
      isFalse,
    );
    expect(
      await File(
        p.join(miniProgramRoot.path, 'stac', 'screens', 'coupon_app_home.dart'),
      ).exists(),
      isFalse,
    );

    final second = await starter.firebaseStarterUi(
      PublisherBackendFirebaseStarterUiRequest(
        miniProgramRootPath: miniProgramRoot.path,
      ),
    );
    expect(second.screenFormat, 'mp');
    expect(second.writtenPaths, isEmpty);
    expect(second.skippedPaths, isEmpty);
    expect(second.unchangedPaths, containsAll(result.writtenPaths));
  });

  test(
    'scaffold can generate Firebase starter UI with backend files',
    () async {
      await File(
        p.join(miniProgramRoot.path, 'pubspec.yaml'),
      ).writeAsString('name: coupon_app_mini_program\n');
      final result = await const PublisherBackendStarter().scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
          withStarterUi: true,
        ),
      );

      expect(result.starterUi, isNotNull);
      expect(result.starterUi!.screenFormat, 'stac');
      expect(result.starterUi!.writtenPaths, isNotEmpty);
      expect(
        await File(
          p.join(
            miniProgramRoot.path,
            'stac',
            'screens',
            'coupon_app_home.dart',
          ),
        ).exists(),
        isTrue,
      );
      final coupons = await File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
          'data',
          'coupons_list.json',
        ),
      ).readAsString();
      expect(coupons, contains('image-backed flash deal'));
    },
  );

  test('rejects invalid publisher backend storage combinations', () {
    final starter = const PublisherBackendStarter();
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'dynamodb',
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'aws-lambda',
          storageMode: 'firestore',
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
    expect(
      () => starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'mock',
          storageMode: 'firestore',
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
  });
}
