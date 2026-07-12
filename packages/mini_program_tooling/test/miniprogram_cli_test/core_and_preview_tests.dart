part of '../miniprogram_cli_test.dart';

void _registerCoreAndPreviewTests() {
  test(
    'root help shows static artifact and runtime API commands only',
    () async {
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: stderrBuffer,
        workingDirectory: tempDir.path,
      ).run(<String>['--help']);

      expect(exitCode, 0);
      expect(stderrBuffer.toString(), isEmpty);
      final output = stdoutBuffer.toString();
      expect(output, contains('create <mini-program-id> [--screen-format mp]'));
      expect(output, contains('artifact build [mini-program-id]'));
      expect(output, contains('artifact verify [mini-program-id]'));
      expect(
        output,
        contains('publish [mini-program-id] [--target local|static]'),
      );
      expect(output, contains('partner package <mini-program-id>'));
      expect(output, contains('host endpoint import <partner-package.json>'));
      expect(output, contains('publisher-api scaffold --template mock'));
      expect(output, contains('publisher-api contract init|validate|smoke'));
    },
  );

  test(
    'removed provider delivery commands fail with migration message',
    () async {
      final removedDeliveryCommand =
          'clo'
          'ud';
      final removedCredentialCommand =
          'access'
          '-key';
      final removedProvider =
          'aw'
          's';
      for (final command in <List<String>>[
        <String>[removedDeliveryCommand, 'status'],
        <String>[removedCredentialCommand, 'list', 'coupon_center'],
        <String>['env', 'configure', 'prod', '--provider', removedProvider],
      ]) {
        final stderrBuffer = StringBuffer();
        final exitCode = await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: StringBuffer(),
          stderrSink: stderrBuffer,
          workingDirectory: tempDir.path,
        ).run(command);

        expect(exitCode, 64);
        expect(stderrBuffer.toString(), contains('removed'));
      }
    },
  );

  test('create help exposes screen format selection', () async {
    final stdoutBuffer = StringBuffer();
    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['create', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('--screen-format'));
    expect(stdoutBuffer.toString(), contains('mp'));
    expect(stdoutBuffer.toString(), isNot(contains('stac')));
  });

  test('build and preview help expose Mp build script override', () async {
    final buildStdout = StringBuffer();
    expect(
      await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: buildStdout,
        stderrSink: StringBuffer(),
        workingDirectory: tempDir.path,
      ).run(<String>['build', '--help']),
      0,
    );
    expect(buildStdout.toString(), contains('--mp-build-script'));

    final previewStdout = StringBuffer();
    expect(
      await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: previewStdout,
        stderrSink: StringBuffer(),
        workingDirectory: tempDir.path,
      ).run(<String>['preview', '--help']),
      0,
    );
    expect(previewStdout.toString(), contains('--mp-build-script'));
  });

  test('artifact help exposes portable build and verify commands', () async {
    final stdoutBuffer = StringBuffer();
    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['artifact', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('build [mini-program-id]'));
    expect(stdoutBuffer.toString(), contains('verify [mini-program-id]'));
  });

  test(
    'capabilities expose only static artifact and runtime API support',
    () async {
      final stdoutBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: tempDir.path,
      ).run(<String>['capabilities', '--json']);

      expect(exitCode, 0);
      final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
      expect(json['toolingVersion'], '0.6.8');
      final capabilities = (json['capabilityIds'] as List).cast<String>();
      expect(capabilities, contains('publish.static'));
      expect(capabilities, contains('publisher_api.mock.scaffold'));
      expect(capabilities, contains('publisher_api.contract.smoke'));
      expect(capabilities, isNot(contains('publisher_api.contract.handoff')));
    },
  );

  test('env init/list/status are local-only', () async {
    final envRoot = p.join(tempDir.path, 'env_root');
    await Directory(envRoot).create(recursive: true);
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: envRoot,
    );
    expect(await cli.run(<String>['env', 'init']), 0);
    expect(await cli.run(<String>['env', 'list']), 0);

    final lines = stdoutBuffer.toString();
    expect(lines, contains('Active environment: local'));
    expect(lines, isNot(contains('provider')));
    final jsonBuffer = StringBuffer();
    expect(
      await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: jsonBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: envRoot,
      ).run(<String>['env', 'status', '--json']),
      0,
    );
    final envJson = jsonDecode(jsonBuffer.toString()) as Map<String, dynamic>;
    expect(envJson['activeEnvironment'], 'local');
  });

  test('build resolves a repo-managed mini-program from repo root', () async {
    final miniProgramRoot = p.join(
      repoRoot.path,
      'mini_programs',
      'coupon_center',
    );
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
      workingDirectory: repoRoot.path,
    ).run(<String>['build', 'coupon_center', '--skip-pub-get']);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Built mini-program: coupon_center'),
    );
  });

  test('artifact build and verify use the mini-program local bundle', () async {
    final miniProgramRoot = p.join(tempDir.path, 'calculator');
    await _writeMiniProgramFixture(
      miniProgramRoot,
      miniProgramId: 'calculator',
      version: '1.0.0',
    );
    final buildOutput = StringBuffer();
    final buildErrors = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: buildOutput,
      stderrSink: buildErrors,
      workingDirectory: miniProgramRoot,
    );

    expect(await cli.run(<String>['artifact', 'build', '--skip-pub-get']), 0);
    expect(buildErrors.toString(), isEmpty);
    expect(buildOutput.toString(), contains('Version: 1.0.0'));
    expect(
      await File(
        p.join(
          miniProgramRoot,
          'artifacts',
          'calculator',
          '1.0.0',
          'checksums.json',
        ),
      ).exists(),
      isTrue,
    );

    final verifyOutput = StringBuffer();
    final verifyErrors = StringBuffer();
    expect(
      await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: verifyOutput,
        stderrSink: verifyErrors,
        workingDirectory: miniProgramRoot,
      ).run(<String>['artifact', 'verify']),
      0,
    );
    expect(verifyErrors.toString(), isEmpty);
    expect(verifyOutput.toString(), contains('Artifact verification passed.'));
  });

  test('publish static writes a public artifact folder', () async {
    final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      miniProgramRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.0',
    );
    final outputRoot = p.join(tempDir.path, 'public_mini_program');
    final stdoutBuffer = StringBuffer();

    final exitCode =
        await MiniprogramCli(
          stateStore: stateStore,
          stdoutSink: stdoutBuffer,
          stderrSink: StringBuffer(),
          workingDirectory: miniProgramRoot,
        ).run(<String>[
          'publish',
          '--target',
          'static',
          '--output',
          outputRoot,
          '--skip-build-pub-get',
        ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('Published mini-program to static folder: coupon_center'),
    );
    expect(
      await File(
        p.join(outputRoot, 'artifacts', 'coupon_center', 'latest.json'),
      ).exists(),
      isTrue,
    );
  });

  test('preview dispatches to the preview controller', () async {
    final miniProgramRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      miniProgramRoot,
      miniProgramId: 'coupon_center',
      version: '1.0.0',
    );
    final previewController = _FakeMiniProgramPreviewController();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: StringBuffer(),
      stderrSink: StringBuffer(),
      previewController: previewController,
      workingDirectory: miniProgramRoot,
    ).run(<String>['preview', '-d', 'chrome']);

    expect(exitCode, 0);
    expect(previewController.lastRequest, isNotNull);
    expect(previewController.lastRequest!.deviceId, 'chrome');
  });
}
