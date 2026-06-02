part of '../../miniprogram_cli_test.dart';

void _registerPublisherBackendFirebaseHostHandoffTests() {
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
}
