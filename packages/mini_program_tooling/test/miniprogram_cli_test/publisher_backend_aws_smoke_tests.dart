part of '../miniprogram_cli_test.dart';

void _registerPublisherBackendAwsSmokeTests() {
  test('publisher-backend aws smoke prints route checks', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: stderrBuffer,
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _publisherBackendStackJson(), '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'smoke',
      '--env',
      'my-aws-prod',
    ]);

    expect(exitCode, 0);
    expect(stderrBuffer.toString(), isEmpty);
    expect(
      stdoutBuffer.toString(),
      contains('AWS Lambda publisher backend smoke test.'),
    );
    expect(stdoutBuffer.toString(), contains('Passed: true'));
    expect(stdoutBuffer.toString(), contains('GET /health: 200 OK'));
    expect(stdoutBuffer.toString(), contains('GET /home/bootstrap: 200 OK'));
    expect(stdoutBuffer.toString(), contains('GET /coupons/list: 200 OK'));
    expect(stdoutBuffer.toString(), contains('GET /auth/session: 200 OK'));
  });

  test('publisher-backend aws smoke prints write route checks', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _publisherBackendStackJson(), '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        postRequester: (uri, {headers, body}) async {
          return http.Response(
            jsonEncode(<String, Object?>{'status': 'redeemed'}),
            200,
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'smoke',
      '--env',
      'my-aws-prod',
      '--include-write',
      '--write-coupon-id',
      'coupon-20',
      '--write-user-id',
      'smoke-user',
    ]);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('Write smoke: true'));
    expect(
      stdoutBuffer.toString(),
      contains('POST /coupon/redeem: 200 OK (redeemed)'),
    );
  });

  test('publisher-backend aws smoke prints JSON', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _publisherBackendStackJson(), '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'smoke',
      '--env',
      'my-aws-prod',
      '--json',
    ]);

    expect(exitCode, 0);
    final decoded = jsonDecode(stdoutBuffer.toString());
    expect(decoded, isA<Map<String, Object?>>());
    final json = decoded as Map<String, Object?>;
    expect(json['command'], 'publisher-backend aws smoke');
    expect(json['passed'], isTrue);
    expect(json['backendBaseUrl'], contains('/prod/'));
    expect(json['includeWrite'], isFalse);
    expect(json['accessKeyProvided'], isFalse);
    final routes = json['routes'] as List<Object?>;
    expect(routes, hasLength(4));
    expect(routes.first, containsPair('path', '/health'));
  });

  test('publisher-backend aws smoke prints write JSON', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _publisherBackendStackJson(), '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        postRequester: (uri, {headers, body}) async {
          return http.Response(
            jsonEncode(<String, Object?>{'status': 'already_redeemed'}),
            200,
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'smoke',
      '--env',
      'my-aws-prod',
      '--include-write',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['includeWrite'], isTrue);
    final routes = json['routes'] as List<Object?>;
    final writeRoute = routes.last as Map<String, dynamic>;
    expect(writeRoute['method'], 'POST');
    expect(writeRoute['path'], '/coupon/redeem');
    expect(writeRoute['responseStatus'], 'already_redeemed');
  });

  test('publisher-backend aws smoke forwards and redacts access key', () async {
    const accessKey = 'mpk_live_partner_123456789012345';
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final requestedHeaders = <Map<String, String>?>[];
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _publisherBackendStackJson(), '');
        },
        httpRequester: (method, uri, {headers, body}) async {
          requestedHeaders.add(headers);
          return http.Response('{"ok":true}', 200);
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'smoke',
      '--env',
      'my-aws-prod',
      '--access-key',
      accessKey,
      '--json',
    ]);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), isNot(contains(accessKey)));
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['accessKeyProvided'], isTrue);
    expect(
      requestedHeaders,
      everyElement(containsPair('x-mini-program-access-key', accessKey)),
    );
  });

  test('publisher-backend aws smoke returns 1 when a route fails', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _publisherBackendStackJson(), '');
        },
        healthGetter: (uri) async {
          if (uri.path.endsWith('/auth/session')) {
            return http.Response('nope', 500);
          }
          return http.Response('{"ok":true}', 200);
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'smoke',
      '--env',
      'my-aws-prod',
    ]);

    expect(exitCode, 1);
    expect(stdoutBuffer.toString(), contains('Passed: false'));
    expect(stdoutBuffer.toString(), contains('GET /auth/session: 500 FAIL'));
  });

  test(
    'publisher-backend aws smoke rejects write options without write smoke',
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
        'aws',
        'smoke',
        '--env',
        'my-aws-prod',
        '--write-coupon-id',
        'coupon-20',
      ]);

      expect(exitCode, 64);
      expect(stderrBuffer.toString(), contains('require --include-write'));
      expect(stdoutBuffer.toString(), isEmpty);
    },
  );

  test('publisher-backend aws smoke help includes write options', () async {
    final stdoutBuffer = StringBuffer();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['publisher-backend', 'aws', 'smoke', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('--include-write'));
    expect(stdoutBuffer.toString(), contains('--access-key'));
    expect(stdoutBuffer.toString(), contains('--write-coupon-id'));
    expect(stdoutBuffer.toString(), contains('--write-user-id'));
  });

  test('publisher-backend aws deploy prints DynamoDB next commands', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await const PublisherBackendStarter().scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: standaloneRoot,
        template: 'aws-lambda',
        storageMode: 'dynamodb',
      ),
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          if (arguments.contains('describe-stacks')) {
            return ProcessResult(
              0,
              0,
              _publisherBackendStackJsonWithDataTable(),
              '',
            );
          }
          return ProcessResult(0, 0, '{}', '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'deploy',
      '--env',
      'my-aws-prod',
    ]);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('Next commands:'));
    expect(
      stdoutBuffer.toString(),
      contains('publisher-backend aws seed --env my-aws-prod'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('publisher-backend aws data status --env my-aws-prod'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('publisher-backend aws smoke --env my-aws-prod'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('For protected backend smoke, append --access-key <key>.'),
    );
    expect(stdoutBuffer.toString(), contains('(--access-key <key>|--public)'));
    expect(
      stdoutBuffer.toString(),
      contains('publisher-backend aws logs --env my-aws-prod'),
    );
  });

  test('publisher-backend scaffold help includes storage', () async {
    final stdoutBuffer = StringBuffer();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['publisher-backend', 'scaffold', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('--storage'));
    expect(stdoutBuffer.toString(), contains('bundled'));
    expect(stdoutBuffer.toString(), contains('dynamodb'));
    expect(stdoutBuffer.toString(), contains('firebase-functions'));
    expect(stdoutBuffer.toString(), contains('firestore'));
    expect(stdoutBuffer.toString(), contains('--with-starter-ui'));
  });

  test(
    'publisher-backend scaffold prints Firebase template and storage',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'firebase_coupon');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'firebase_coupon',
        version: '1.0.0',
      );
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: stderrBuffer,
            workingDirectory: standaloneRoot,
          ).run(<String>[
            'publisher-backend',
            'scaffold',
            '--template',
            'firebase-functions',
            '--storage',
            'firestore',
          ]);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);
      expect(stdoutBuffer.toString(), contains('Template: firebase-functions'));
      expect(stdoutBuffer.toString(), contains('Storage: firestore'));
      expect(stdoutBuffer.toString(), contains('Next Firebase steps:'));
      expect(
        await File(
          p.join(
            standaloneRoot,
            'backend',
            'firebase_functions',
            'functions',
            'router.js',
          ),
        ).exists(),
        isTrue,
      );
    },
  );

  test('publisher-backend scaffold can include Firebase starter UI', () async {
    final standaloneRoot = p.join(tempDir.path, 'firebase_starter_scaffold');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'firebase_starter_scaffold',
      version: '1.0.0',
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
          'scaffold',
          '--template',
          'firebase-functions',
          '--storage',
          'firestore',
          '--with-starter-ui',
        ]);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('Firebase starter UI:'));
    expect(
      await File(
        p.join(
          standaloneRoot,
          'mp',
          'screens',
          'firebase_starter_scaffold_home.dart',
        ),
      ).exists(),
      isTrue,
    );
  });
}
