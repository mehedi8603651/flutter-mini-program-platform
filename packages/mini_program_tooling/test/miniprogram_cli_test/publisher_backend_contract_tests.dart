part of '../miniprogram_cli_test.dart';

void _registerPublisherBackendContractTests() {
  test(
    'help and capabilities expose runtime Publisher API contract commands',
    () async {
      final stdoutBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: tempDir.path,
      ).run(<String>['publisher-api', 'contract', '--help']);

      expect(exitCode, 0);
      final output = stdoutBuffer.toString();
      expect(output, contains('init --backend-base-url'));
      expect(output, contains('validate [--mini-program-root'));
      expect(output, contains('smoke [--mini-program-root'));
      expect(output, isNot(contains('access-key')));
    },
  );

  test(
    'contract init writes runtime API contract without artifact access mode',
    () async {
      final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      final stdoutBuffer = StringBuffer();

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: stdoutBuffer,
            stderrSink: StringBuffer(),
            workingDirectory: miniProgramRoot,
          ).run(<String>[
            'publisher-api',
            'contract',
            'init',
            '--backend-base-url',
            'http://127.0.0.1:9090',
            '--allow-local-http',
            '--json',
          ]);

      expect(exitCode, 0);
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['command'], 'publisher-api contract init');
      expect(json['backendBaseUrl'], 'http://127.0.0.1:9090');
      expect(json.containsKey('accessMode'), isFalse);
      final contractPath = p.join(miniProgramRoot, 'publisher_backend.json');
      final contractJson =
          jsonDecode(await File(contractPath).readAsString())
              as Map<String, dynamic>;
      expect(contractJson.containsKey('accessMode'), isFalse);
    },
  );

  test('contract validate accepts current runtime API contract', () async {
    final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      miniProgramRoot,
      miniProgramId: 'coupon_center',
      version: '1.0.0',
    );
    await File(p.join(miniProgramRoot, 'publisher_backend.json')).writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'type': 'mini_program_publisher_backend_contract',
        'contractVersion': '1',
        'appId': 'coupon_center',
        'backendBaseUrl': 'http://127.0.0.1:9090',
        'healthEndpoint': 'health',
        'smokeTests': <Object?>[
          <String, Object?>{
            'id': 'health',
            'method': 'GET',
            'endpoint': 'health',
            'expectedStatus': 200,
            'expectJsonObject': true,
          },
        ],
      }),
    );
    final stdoutBuffer = StringBuffer();

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: miniProgramRoot,
        ).run(<String>[
          'publisher-api',
          'contract',
          'validate',
          '--allow-local-http',
          '--json',
        ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['valid'], isTrue);
    expect(json['backendBaseUrl'], 'http://127.0.0.1:9090');
  });

  test('contract smoke sends normal runtime auth header only', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <HttpRequest>[];
    unawaited(
      server.forEach((request) {
        requests.add(request);
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{'status': 'ok'},
              'traceId': 'trace-1',
            }),
          )
          ..close();
      }),
    );
    addTearDown(() => server.close(force: true));

    final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      miniProgramRoot,
      miniProgramId: 'coupon_center',
      version: '1.0.0',
    );
    await File(p.join(miniProgramRoot, 'publisher_backend.json')).writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'type': 'mini_program_publisher_backend_contract',
        'contractVersion': '1',
        'appId': 'coupon_center',
        'backendBaseUrl': 'http://127.0.0.1:${server.port}',
        'healthEndpoint': 'health',
        'smokeTests': <Object?>[
          <String, Object?>{
            'id': 'health',
            'method': 'GET',
            'endpoint': 'health',
            'expectedStatus': 200,
            'expectJsonObject': true,
          },
        ],
      }),
    );

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          workingDirectory: miniProgramRoot,
        ).run(<String>[
          'publisher-api',
          'contract',
          'smoke',
          '--allow-local-http',
          '--auth-token',
          'runtime-token',
        ]);

    expect(exitCode, 0);
    expect(requests, hasLength(1));
    expect(
      requests.single.headers.value(HttpHeaders.authorizationHeader),
      'Bearer runtime-token',
    );
    expect(requests.single.headers.value('x-mini-program-access-key'), isNull);
  });

  test('contract handoff is removed from MVP flow', () async {
    final stderrBuffer = StringBuffer();
    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: StringBuffer(),
      stderrSink: stderrBuffer,
      workingDirectory: tempDir.path,
    ).run(<String>['publisher-api', 'contract', 'handoff']);

    expect(exitCode, 64);
    expect(stderrBuffer.toString(), contains('removed'));
    expect(stderrBuffer.toString(), contains('artifactBaseUrl'));
  });
}
