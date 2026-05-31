part of '../miniprogram_cli_test.dart';

void _registerPublisherBackendAwsDataTests() {
  test('publisher-backend aws help includes seed and data status', () async {
    final stdoutBuffer = StringBuffer();

    final exitCode = await MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      workingDirectory: tempDir.path,
    ).run(<String>['publisher-backend', 'aws', '--help']);

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), contains('seed --env <env-name>'));
    expect(stdoutBuffer.toString(), contains('data status --env <env-name>'));
  });

  test('publisher-backend aws seed prints text output', () async {
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
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{
              'UnprocessedItems': <String, Object?>{},
            }),
            '',
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'seed',
      '--env',
      'my-aws-prod',
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('AWS DynamoDB publisher backend seed.'),
    );
    expect(
      stdoutBuffer.toString(),
      contains('DynamoDB table: coupon-data-table'),
    );
    expect(stdoutBuffer.toString(), contains('Seeded: true'));
    expect(stdoutBuffer.toString(), contains('Items written: 4'));
  });

  test('publisher-backend aws seed prints JSON', () async {
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
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{
              'UnprocessedItems': <String, Object?>{},
            }),
            '',
          );
        },
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'seed',
      '--env',
      'my-aws-prod',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend aws seed');
    expect(json['seeded'], isTrue);
    expect(json['tableName'], 'coupon-data-table');
    expect(json['itemCount'], 4);
  });

  test(
    'publisher-backend aws seed returns 1 when table output is missing',
    () async {
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
        ),
        workingDirectory: standaloneRoot,
      );

      final exitCode = await cli.run(<String>[
        'publisher-backend',
        'aws',
        'seed',
        '--env',
        'my-aws-prod',
      ]);

      expect(exitCode, 1);
      expect(stdoutBuffer.toString(), contains('Seeded: false'));
      expect(
        stdoutBuffer.toString(),
        contains('PublisherBackendDataTableName'),
      );
    },
  );

  test('publisher-backend aws data status prints text output', () async {
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
        shellRunner: _publisherBackendDataShellRunner,
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'data',
      'status',
      '--env',
      'my-aws-prod',
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('AWS DynamoDB publisher backend data status.'),
    );
    expect(stdoutBuffer.toString(), contains('Table status: ACTIVE'));
    expect(stdoutBuffer.toString(), contains('App records: 4'));
    expect(stdoutBuffer.toString(), contains('Redemptions: 1'));
  });

  test('publisher-backend aws data status prints JSON', () async {
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
        shellRunner: _publisherBackendDataShellRunner,
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'data',
      'status',
      '--env',
      'my-aws-prod',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend aws data status');
    expect(json['available'], isTrue);
    expect(json['tableName'], 'coupon-data-table');
    expect(json['appRecordCount'], 4);
    expect(json['redemptionCount'], 1);
  });

  test('publisher-backend aws data export prints text output', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final outputPath = p.join(tempDir.path, 'coupon-export.json');
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: _publisherBackendDataShellRunner,
        clock: () => DateTime.utc(2026, 5, 23, 12),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'data',
      'export',
      '--env',
      'my-aws-prod',
      '--output',
      outputPath,
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('AWS DynamoDB publisher backend data export.'),
    );
    expect(stdoutBuffer.toString(), contains('Exported: true'));
    expect(stdoutBuffer.toString(), contains('Items exported: 2'));
    expect(await File(outputPath).exists(), isTrue);
  });

  test('publisher-backend aws data export prints JSON', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final outputPath = p.join(tempDir.path, 'coupon-export.json');
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: _publisherBackendDataShellRunner,
        clock: () => DateTime.utc(2026, 5, 23, 12),
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'data',
      'export',
      '--env',
      'my-aws-prod',
      '--output',
      outputPath,
      '--include-redemptions',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend aws data export');
    expect(json['includeRedemptions'], isTrue);
    expect(json['exported'], isTrue);
    expect(json['itemCount'], 3);
    expect(json['redemptionCount'], 1);
  });

  test(
    'publisher-backend aws data import dry-run prints text output',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.2.3',
      );
      await _writeAwsEnvironmentState(stateStore, standaloneRoot);
      final inputPath = p.join(tempDir.path, 'coupon-export.json');
      await File(inputPath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'items': <Object?>[
            <String, Object?>{
              'pk': 'APP#coupon_center',
              'sk': 'HOME#bootstrap',
              'recordType': 'home',
              'payload': <String, Object?>{'title': 'Coupon Center'},
            },
            <String, Object?>{
              'pk': 'APP#coupon_center#REDEMPTIONS',
              'sk': 'USER#smoke-user#COUPON#coupon-20',
              'recordType': 'redemption',
              'payload': <String, Object?>{'couponId': 'coupon-20'},
            },
          ],
        }),
      );
      final stdoutBuffer = StringBuffer();
      final cli = MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        publisherBackendStarter: PublisherBackendStarter(
          shellRunner: _publisherBackendDataShellRunner,
        ),
        workingDirectory: standaloneRoot,
      );

      final exitCode = await cli.run(<String>[
        'publisher-backend',
        'aws',
        'data',
        'import',
        '--env',
        'my-aws-prod',
        '--input',
        inputPath,
        '--dry-run',
      ]);

      expect(exitCode, 0);
      expect(
        stdoutBuffer.toString(),
        contains('AWS DynamoDB publisher backend data import.'),
      );
      expect(stdoutBuffer.toString(), contains('Dry run: true'));
      expect(stdoutBuffer.toString(), contains('Succeeded: true'));
      expect(stdoutBuffer.toString(), contains('Redemptions skipped: 1'));
    },
  );

  test('publisher-backend aws data import prints JSON', () async {
    final standaloneRoot = p.join(tempDir.path, 'coupon_center');
    await _writeMiniProgramFixture(
      standaloneRoot,
      miniProgramId: 'coupon_center',
      version: '1.2.3',
    );
    await _writeAwsEnvironmentState(stateStore, standaloneRoot);
    final inputPath = p.join(tempDir.path, 'coupon-export.json');
    await File(inputPath).writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'items': <Object?>[
          <String, Object?>{
            'pk': 'APP#coupon_center',
            'sk': 'HOME#bootstrap',
            'recordType': 'home',
            'payload': <String, Object?>{'title': 'Coupon Center'},
          },
        ],
      }),
    );
    final stdoutBuffer = StringBuffer();
    final cli = MiniprogramCli(
      stateStore: stateStore,
      stdoutSink: stdoutBuffer,
      stderrSink: StringBuffer(),
      publisherBackendStarter: PublisherBackendStarter(
        shellRunner: _publisherBackendDataShellRunner,
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'data',
      'import',
      '--env',
      'my-aws-prod',
      '--input',
      inputPath,
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend aws data import');
    expect(json['succeeded'], isTrue);
    expect(json['imported'], isTrue);
    expect(json['itemCount'], 1);
  });

  test('publisher-backend aws data redemptions prints text output', () async {
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
        shellRunner: _publisherBackendDataShellRunner,
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'data',
      'redemptions',
      '--env',
      'my-aws-prod',
      '--coupon-id',
      'coupon-20',
    ]);

    expect(exitCode, 0);
    expect(
      stdoutBuffer.toString(),
      contains('AWS DynamoDB publisher backend redemptions.'),
    );
    expect(stdoutBuffer.toString(), contains('Matched: 1'));
    expect(stdoutBuffer.toString(), contains('coupon=coupon-20'));
  });

  test('publisher-backend aws data redemptions prints JSON', () async {
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
        shellRunner: _publisherBackendDataShellRunner,
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'data',
      'redemptions',
      '--env',
      'my-aws-prod',
      '--json',
    ]);

    expect(exitCode, 0);
    final json = jsonDecode(stdoutBuffer.toString()) as Map<String, dynamic>;
    expect(json['command'], 'publisher-backend aws data redemptions');
    expect(json['available'], isTrue);
    expect(json['returnedCount'], 1);
    expect(json['records'], isNotEmpty);
  });

  test('publisher-backend aws destroy blocks DynamoDB data', () async {
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
        shellRunner: _publisherBackendDataShellRunner,
      ),
      workingDirectory: standaloneRoot,
    );

    final exitCode = await cli.run(<String>[
      'publisher-backend',
      'aws',
      'destroy',
      '--env',
      'my-aws-prod',
      '--yes',
    ]);

    expect(exitCode, 1);
    expect(stdoutBuffer.toString(), contains('was not deleted'));
    expect(stdoutBuffer.toString(), contains('Blocked by data: true'));
    expect(stdoutBuffer.toString(), contains('--confirm-data-loss'));
  });

  test(
    'publisher-backend aws data help includes production commands',
    () async {
      final stdoutBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: tempDir.path,
      ).run(<String>['publisher-backend', 'aws', 'data', '--help']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('export --env'));
      expect(stdoutBuffer.toString(), contains('import --env'));
      expect(stdoutBuffer.toString(), contains('redemptions --env'));
    },
  );

  test(
    'publisher-backend aws destroy help includes data-loss confirmation',
    () async {
      final stdoutBuffer = StringBuffer();
      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: stdoutBuffer,
        stderrSink: StringBuffer(),
        workingDirectory: tempDir.path,
      ).run(<String>['publisher-backend', 'aws', 'destroy', '--help']);

      expect(exitCode, 0);
      expect(stdoutBuffer.toString(), contains('--confirm-data-loss'));
    },
  );

  test(
    'publish --target static writes to the selected output folder',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.2.3',
      );
      final staticPublisher = _FakeMiniProgramStaticPublisher();
      final outputPath = p.join(tempDir.path, 'public_mini_program');

      final exitCode =
          await MiniprogramCli(
            stateStore: stateStore,
            stdoutSink: StringBuffer(),
            stderrSink: StringBuffer(),
            staticPublisher: staticPublisher,
            workingDirectory: standaloneRoot,
          ).run(<String>[
            'publish',
            '--target',
            'static',
            '--output',
            outputPath,
            '--clean',
          ]);

      expect(exitCode, 0);
      expect(staticPublisher.lastRequest, isNotNull);
      expect(staticPublisher.lastRequest!.outputPath, outputPath);
      expect(staticPublisher.lastRequest!.miniProgramId, 'coupon_center');
      expect(staticPublisher.lastRequest!.clean, isTrue);
      expect(
        staticPublisher.lastRequest!.miniProgramRootPath,
        p.normalize(p.absolute(standaloneRoot)),
      );
    },
  );
}
