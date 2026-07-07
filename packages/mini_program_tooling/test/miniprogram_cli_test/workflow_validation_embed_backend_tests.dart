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

  test(
    'workflow status is static-artifact local-first and redacts legacy secrets',
    () async {
      final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'coupon_center',
        version: '1.0.0',
      );
      await Directory(
        p.join(miniProgramRoot, 'mp', '.build', 'screens'),
      ).create(recursive: true);
      await File(
        p.join(
          miniProgramRoot,
          'mp',
          '.build',
          'screens',
          'coupon_center_home.json',
        ),
      ).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'screenId': 'coupon_center_home',
          'root': <String, Object?>{
            'type': 'backendBuilder',
            'props': <String, Object?>{
              'requestId': 'home',
              'endpoint': 'home/bootstrap',
            },
          },
        }),
      );
      await File(
        p.join(miniProgramRoot, 'coupon_center.partner.json'),
      ).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'type': 'mini_program_partner_handoff',
          'appId': 'coupon_center',
          'title': 'Coupon Center',
          'apiBaseUrl': 'https://static.example.com/coupon',
          'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
        }),
      );
      await Directory(
        p.join(miniProgramRoot, 'mp', 'screens'),
      ).create(recursive: true);
      await File(
        p.join(miniProgramRoot, 'mp', 'screens', 'coupon_center_home.dart'),
      ).writeAsString('''
Mp.backendBuilder(
  requestId: 'home',
  endpoint: 'home/bootstrap',
);
Mp.backend.query(
  requestId: 'home',
  endpoint: 'home/bootstrap',
);
''');
      await _writeLocalEnvironmentState(stateStore, miniProgramRoot);
      final stdoutBuffer = StringBuffer();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: miniProgramRoot,
      ).run(<String>['workflow', 'status', '--json']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), isNot(contains('secret_should_not')));
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['workspace']['type'], 'mini_program');
      expect(json['environment']['activeEnvironment'], 'local');
      expect(json['miniProgram']['appId'], 'coupon_center');
      expect(json['miniProgram']['build']['exists'], isTrue);
      expect(
        json['miniProgram']['partnerPackages'][0]['artifactBaseUrl'],
        'https://static.example.com/coupon',
      );
      expect(json['miniProgram']['backendUsage']['usesBackendBuilder'], isTrue);
      expect(
        json['miniProgram']['backendUsage']['usesBackendQueryAction'],
        isTrue,
      );
      expect(json['remote']['checked'], isFalse);
    },
  );

  test('workflow status --remote reports provider checks removed', () async {
    final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      miniProgramRoot,
      miniProgramId: 'coupon_center',
      version: '1.0.0',
    );
    final stdoutBuffer = StringBuffer();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: miniProgramRoot,
    ).run(<String>['workflow', 'status', '--remote', '--json']);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['remote']['checked'], isTrue);
    expect(json['remote']['supported'], isFalse);
    expect(json['remote']['message'], contains('artifactBaseUrl'));
  });

  test(
    'workflow status reports host endpoints without access fields',
    () async {
      final hostRoot = p.join(tempDir.path, 'host_app');
      await _writeEmbeddedHostFixture(hostRoot);
      final endpointFile = File(
        p.join(hostRoot, 'lib', 'mini_program', 'mini_program_endpoints.dart'),
      );
      await endpointFile.writeAsString('''
// BEGIN MINI_PROGRAM_ENDPOINTS_JSON
// {"coupon_center":{"apiBaseUri":"https://static.example.com/coupon","backendBaseUri":"https://publisher.example.com/api","backendMode":"remote"}}
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
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      final endpoints = (json['hostApp']['endpoints'] as List)
          .cast<Map<String, dynamic>>();
      final endpoint = endpoints.single;
      final legacySecretFlag =
          'has'
          'Access'
          'Key';
      expect(endpoint['apiBaseUri'], 'https://static.example.com/coupon');
      expect(endpoint.containsKey('accessMode'), isFalse);
      expect(endpoint.containsKey(legacySecretFlag), isFalse);
      expect(endpoint['backendConfigured'], isTrue);
      expect(endpoint['backendMode'], 'remote');
    },
  );

  test('host run opens without runtime API URL', () async {
    final hostRoot = p.join(tempDir.path, 'host_app');
    await _writeEmbeddedHostFixture(hostRoot);
    final hostController = _FakeMiniProgramHostController();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: StringBuffer(),
      stderrSink: StringBuffer(),
      hostController: hostController,
      workingDirectory: hostRoot,
    ).run(<String>['host', 'run', '-d', 'chrome']);

    expect(exitCode, 0);
    expect(hostController.lastRequest, isNotNull);
    expect(hostController.lastRequest!.backendApiBaseUrl, isEmpty);
  });

  test('host endpoint import forwards requested policy acceptance', () async {
    final hostRoot = p.join(tempDir.path, 'host_app');
    await _writeEmbeddedHostFixture(hostRoot);
    final handoffPath = p.join(tempDir.path, 'calculator.partner.json');
    await File(handoffPath).writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 3,
        'type': MiniProgramPartnerHandoff.documentType,
        'appId': 'calculator',
        'title': 'Calculator',
        'artifactBaseUrl': 'https://cdn.example.com/calculator/',
        'generatedAtUtc': DateTime.utc(2026, 7, 7, 10).toIso8601String(),
        'requestedCache': <String, Object?>{
          'state': <String, Object?>{
            'enabled': true,
            'reason': 'calculator history',
            'recommendedMaxBytes': 1048576,
            'recommendedTtlDays': 30,
          },
        },
      }),
    );
    final hostController = _FakeMiniProgramHostController();

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: StringBuffer(),
          hostController: hostController,
          workingDirectory: hostRoot,
        ).run(<String>[
          'host',
          'endpoint',
          'import',
          handoffPath,
          '--accept-requested-policy',
        ]);

    expect(exitCode, 0);
    final request = hostController.lastEndpointAddRequest;
    expect(request, isNotNull);
    expect(request!.appId, 'calculator');
    expect(request.acceptRequestedPolicy, isTrue);
    expect(request.policySourcePath, handoffPath);
    expect(
      request.requestedCache['state'],
      containsPair('recommendedMaxBytes', 1048576),
    );
  });

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
    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: repoRoot.path,
        ).run(<String>[
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
  });

  test('artifact-host subcommands dispatch to the controller', () async {
    final controller = _FakeLocalBackendController();
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      backendController: controller,
      workingDirectory: repoRoot.path,
    );

    expect(
      await cli.run(<String>['artifact-host', 'start', '--port', '9090']),
      0,
    );
    expect(controller.startedPort, 9090);
    expect(await cli.run(<String>['artifact-host', 'status']), 0);
    expect(await cli.run(<String>['artifact-host', 'stop']), 0);
    expect(controller.calls, <String>['start', 'status', 'stop']);
  });
}
