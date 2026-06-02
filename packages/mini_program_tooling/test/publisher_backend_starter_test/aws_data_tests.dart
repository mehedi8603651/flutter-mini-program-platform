part of '../publisher_backend_starter_test.dart';

void _registerAwsDataTests() {
  test('AWS seed writes DynamoDB starter records', () async {
    final commands = <List<String>>[];
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        commands.add(arguments);
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
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
      clock: () => DateTime.utc(2026, 5, 23, 12),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
        storageMode: 'dynamodb',
      ),
    );

    final result = await starter.awsSeed(
      PublisherBackendAwsSeedRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.seeded, isTrue);
    expect(result.tableName, 'coupon-data-table');
    expect(result.itemCount, 4);
    final batchCommand = commands.singleWhere(
      (arguments) => arguments.contains('batch-write-item'),
    );
    final requestItemsJson =
        batchCommand[batchCommand.indexOf('--request-items') + 1];
    final requestItems = jsonDecode(requestItemsJson) as Map<String, dynamic>;
    final writes = requestItems['coupon-data-table'] as List<dynamic>;
    expect(writes, hasLength(4));
    final keys = writes
        .map((write) => ((write as Map)['PutRequest'] as Map)['Item'] as Map)
        .map((item) => '${item['pk']['S']} ${item['sk']['S']}')
        .toList();
    expect(keys, contains('APP#coupon_app HOME#bootstrap'));
    expect(keys, contains('APP#coupon_app SESSION#demo'));
    expect(keys, contains('APP#coupon_app COUPON#coupon-10'));
    expect(keys, contains('APP#coupon_app COUPON#coupon-20'));
  });

  test('AWS seed retries unprocessed DynamoDB writes', () async {
    var batchWriteCalls = 0;
    var delayCalls = 0;
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        batchWriteCalls++;
        if (batchWriteCalls == 1) {
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{
              'UnprocessedItems': <String, Object?>{
                'coupon-data-table': <Object?>[
                  <String, Object?>{
                    'PutRequest': <String, Object?>{
                      'Item': <String, Object?>{
                        'pk': <String, Object?>{'S': 'APP#coupon_app'},
                        'sk': <String, Object?>{'S': 'HOME#bootstrap'},
                      },
                    },
                  },
                ],
              },
            }),
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
      delay: (duration) async {
        delayCalls++;
      },
      clock: () => DateTime.utc(2026, 5, 23, 12),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
        storageMode: 'dynamodb',
      ),
    );

    final result = await starter.awsSeed(
      PublisherBackendAwsSeedRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.seeded, isTrue);
    expect(batchWriteCalls, 2);
    expect(delayCalls, 1);
  });

  test('AWS seed fails when DynamoDB leaves unprocessed writes', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        return ProcessResult(
          0,
          0,
          jsonEncode(<String, Object?>{
            'UnprocessedItems': <String, Object?>{
              'coupon-data-table': <Object?>[
                <String, Object?>{
                  'PutRequest': <String, Object?>{
                    'Item': <String, Object?>{
                      'pk': <String, Object?>{'S': 'APP#coupon_app'},
                      'sk': <String, Object?>{'S': 'HOME#bootstrap'},
                    },
                  },
                },
              ],
            },
          }),
          '',
        );
      },
      delay: (duration) async {},
      clock: () => DateTime.utc(2026, 5, 23, 12),
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
        storageMode: 'dynamodb',
      ),
    );

    expect(
      () => starter.awsSeed(
        PublisherBackendAwsSeedRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _awsEnvironment(),
        ),
      ),
      throwsA(isA<PublisherBackendException>()),
    );
  });

  test('AWS seed fails when data table output is missing', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, _stackDescribeJson(), '');
      },
    );

    final result = await starter.awsSeed(
      PublisherBackendAwsSeedRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.seeded, isFalse);
    expect(result.error, contains('PublisherBackendDataTableName'));
  });

  test('AWS data status describes table and counts records', () async {
    final queryCommands = <List<String>>[];
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        if (arguments.contains('describe-table')) {
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{
              'Table': <String, Object?>{'TableStatus': 'ACTIVE'},
            }),
            '',
          );
        }
        final joined = arguments.join(' ');
        queryCommands.add(arguments);
        if (joined.contains('APP#coupon_app#REDEMPTIONS')) {
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{'Count': 1}),
            '',
          );
        }
        if (!arguments.contains('--exclusive-start-key')) {
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{
              'Count': 2,
              'LastEvaluatedKey': <String, Object?>{
                'pk': <String, Object?>{'S': 'APP#coupon_app'},
                'sk': <String, Object?>{'S': 'COUPON#coupon-10'},
              },
            }),
            '',
          );
        }
        return ProcessResult(
          0,
          0,
          jsonEncode(<String, Object?>{'Count': 2}),
          '',
        );
      },
    );

    final result = await starter.awsDataStatus(
      PublisherBackendAwsDataStatusRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.available, isTrue);
    expect(result.tableName, 'coupon-data-table');
    expect(result.tableStatus, 'ACTIVE');
    expect(result.appRecordCount, 4);
    expect(result.redemptionCount, 1);
    expect(queryCommands, hasLength(3));
    expect(
      queryCommands.every((command) => command.contains('--consistent-read')),
      isTrue,
    );
    expect(
      queryCommands.any((command) => command.contains('--exclusive-start-key')),
      isTrue,
    );
  });

  test('AWS data status fails when data table output is missing', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, _stackDescribeJson(), '');
      },
    );

    final result = await starter.awsDataStatus(
      PublisherBackendAwsDataStatusRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.available, isFalse);
    expect(result.error, contains('PublisherBackendDataTableName'));
  });

  test('AWS data export writes app records only by default', () async {
    final queryCommands = <List<String>>[];
    final outputPath = p.join(tempDir.path, 'exports', 'coupon-data.json');
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        queryCommands.add(arguments);
        return ProcessResult(
          0,
          0,
          _dynamoDbQueryItemsJson(<Map<String, Object?>>[
            _dynamoDbItem(
              pk: 'APP#coupon_app',
              sk: 'HOME#bootstrap',
              recordType: 'home',
              payload: <String, Object?>{
                'title': 'Coupon App',
                'count': 2,
                'active': true,
                'tags': <Object?>['featured', null],
              },
            ),
            _dynamoDbItem(
              pk: 'APP#coupon_app',
              sk: 'SESSION#demo',
              recordType: 'session',
              payload: <String, Object?>{'userId': 'demo-user'},
            ),
          ]),
          '',
        );
      },
      clock: () => DateTime.utc(2026, 5, 23, 12),
    );

    final result = await starter.awsDataExport(
      PublisherBackendAwsDataExportRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        outputPath: outputPath,
      ),
    );

    expect(result.exported, isTrue);
    expect(result.outputPath, p.normalize(p.absolute(outputPath)));
    expect(result.appRecordCount, 2);
    expect(result.redemptionCount, 0);
    expect(queryCommands, hasLength(1));
    expect(
      queryCommands.single.join(' '),
      isNot(contains('APP#coupon_app#REDEMPTIONS')),
    );
    final export =
        jsonDecode(await File(outputPath).readAsString())
            as Map<String, dynamic>;
    expect(export['schemaVersion'], 1);
    expect(export['includeRedemptions'], isFalse);
    final items = export['items'] as List<dynamic>;
    expect(items, hasLength(2));
    final home = items.first as Map<String, dynamic>;
    expect(home['pk'], 'APP#coupon_app');
    expect((home['payload'] as Map<String, dynamic>)['active'], isTrue);
    expect((home['payload'] as Map<String, dynamic>)['tags'], [
      'featured',
      null,
    ]);
  });

  test('AWS data export includes redemptions when requested', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        final joined = arguments.join(' ');
        if (joined.contains('APP#coupon_app#REDEMPTIONS')) {
          return ProcessResult(
            0,
            0,
            _dynamoDbQueryItemsJson(<Map<String, Object?>>[
              _redemptionItem(
                couponId: 'coupon-10',
                userId: 'demo-user',
                createdAtUtc: '2026-05-23T12:00:00.000Z',
              ),
            ]),
            '',
          );
        }
        return ProcessResult(
          0,
          0,
          _dynamoDbQueryItemsJson(<Map<String, Object?>>[
            _dynamoDbItem(
              pk: 'APP#coupon_app',
              sk: 'HOME#bootstrap',
              recordType: 'home',
              payload: <String, Object?>{'title': 'Coupon App'},
            ),
          ]),
          '',
        );
      },
      clock: () => DateTime.utc(2026, 5, 23, 12),
    );

    final result = await starter.awsDataExport(
      PublisherBackendAwsDataExportRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        includeRedemptions: true,
      ),
    );

    expect(result.exported, isTrue);
    expect(result.appRecordCount, 1);
    expect(result.redemptionCount, 1);
    final export =
        jsonDecode(await File(result.outputPath!).readAsString())
            as Map<String, dynamic>;
    expect(export['itemCount'], 2);
    expect(
      (export['items'] as List<dynamic>).map((item) => item['recordType']),
      contains('redemption'),
    );
  });

  test('AWS data import dry-run validates export without writing', () async {
    final inputPath = p.join(tempDir.path, 'coupon-export.json');
    await File(inputPath).writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'items': <Object?>[
          _plainExportItem(
            pk: 'APP#coupon_app',
            sk: 'HOME#bootstrap',
            recordType: 'home',
            payload: <String, Object?>{'title': 'Coupon App'},
          ),
          _plainExportItem(
            pk: 'APP#coupon_app#REDEMPTIONS',
            sk: 'USER#demo-user#COUPON#coupon-10',
            recordType: 'redemption',
            payload: <String, Object?>{'couponId': 'coupon-10'},
          ),
        ],
      }),
    );
    var batchWriteCalls = 0;
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        if (arguments.contains('batch-write-item')) {
          batchWriteCalls++;
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
    );

    final result = await starter.awsDataImport(
      PublisherBackendAwsDataImportRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        inputPath: inputPath,
        dryRun: true,
      ),
    );

    expect(result.succeeded, isTrue);
    expect(result.imported, isFalse);
    expect(result.appRecordCount, 1);
    expect(result.redemptionCount, 0);
    expect(result.skippedRedemptionCount, 1);
    expect(result.itemCount, 1);
    expect(batchWriteCalls, 0);
  });

  test('AWS data import upserts redemptions only when included', () async {
    final inputPath = p.join(tempDir.path, 'coupon-export.json');
    await File(inputPath).writeAsString(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'items': <Object?>[
          _plainExportItem(
            pk: 'APP#coupon_app',
            sk: 'COUPON#coupon-10',
            recordType: 'coupon',
            payload: <String, Object?>{'id': 'coupon-10'},
          ),
          _plainExportItem(
            pk: 'APP#coupon_app#REDEMPTIONS',
            sk: 'USER#demo-user#COUPON#coupon-10',
            recordType: 'redemption',
            payload: <String, Object?>{'couponId': 'coupon-10'},
          ),
        ],
      }),
    );
    List<dynamic>? writes;
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        if (arguments.contains('batch-write-item')) {
          final requestItems =
              jsonDecode(arguments[arguments.indexOf('--request-items') + 1])
                  as Map<String, dynamic>;
          writes = requestItems['coupon-data-table'] as List<dynamic>;
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
    );

    final result = await starter.awsDataImport(
      PublisherBackendAwsDataImportRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        inputPath: inputPath,
        includeRedemptions: true,
      ),
    );

    expect(result.succeeded, isTrue);
    expect(result.imported, isTrue);
    expect(result.appRecordCount, 1);
    expect(result.redemptionCount, 1);
    expect(writes, hasLength(2));
    final keys = writes!
        .map((write) => ((write as Map)['PutRequest'] as Map)['Item'] as Map)
        .map((item) => '${item['pk']['S']} ${item['sk']['S']}')
        .toList();
    expect(
      keys,
      contains('APP#coupon_app#REDEMPTIONS USER#demo-user#COUPON#coupon-10'),
    );
  });

  test('AWS data redemptions filters and limits records', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        return ProcessResult(
          0,
          0,
          _dynamoDbQueryItemsJson(<Map<String, Object?>>[
            _redemptionItem(
              couponId: 'coupon-20',
              userId: 'user-a',
              createdAtUtc: '2026-05-23T12:00:00.000Z',
            ),
            _redemptionItem(
              couponId: 'coupon-20',
              userId: 'user-b',
              createdAtUtc: '2026-05-23T12:05:00.000Z',
            ),
            _redemptionItem(
              couponId: 'coupon-10',
              userId: 'user-c',
              createdAtUtc: '2026-05-23T12:10:00.000Z',
            ),
          ]),
          '',
        );
      },
    );

    final result = await starter.awsDataRedemptions(
      PublisherBackendAwsDataRedemptionsRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        couponId: 'coupon-20',
        limit: 1,
      ),
    );

    expect(result.available, isTrue);
    expect(result.matchedCount, 2);
    expect(result.returnedCount, 1);
    expect(result.records.single['userId'], 'user-b');
  });

  test('AWS destroy blocks DynamoDB data without confirmation', () async {
    final commands = <List<String>>[];
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        commands.add(arguments);
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        if (arguments.contains('query')) {
          final count = arguments.join(' ').contains('REDEMPTIONS') ? 1 : 4;
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{'Count': count}),
            '',
          );
        }
        return ProcessResult(0, 0, '{}', '');
      },
    );

    final result = await starter.awsDestroy(
      PublisherBackendAwsDestroyRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.deleted, isFalse);
    expect(result.blockedByData, isTrue);
    expect(result.appRecordCount, 4);
    expect(result.redemptionCount, 1);
    expect(
      commands.any((command) => command.contains('delete-stack')),
      isFalse,
    );
  });

  test('AWS destroy proceeds with data confirmation', () async {
    final commands = <List<String>>[];
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        commands.add(arguments);
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJsonWithDataTable(), '');
        }
        if (arguments.contains('query')) {
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{'Count': 1}),
            '',
          );
        }
        return ProcessResult(0, 0, '{}', '');
      },
      clock: () => DateTime.utc(2026, 5, 23, 12),
    );

    final result = await starter.awsDestroy(
      PublisherBackendAwsDestroyRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        confirmDataLoss: true,
      ),
    );

    expect(result.deleted, isTrue);
    expect(result.dataLossConfirmed, isTrue);
    expect(commands.any((command) => command.contains('delete-stack')), isTrue);
    expect(
      commands.any((command) => command.contains('stack-delete-complete')),
      isTrue,
    );
  });

  test('AWS logs resolves Lambda function before tailing CloudWatch', () async {
    final commands = <String>[];
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        commands.add('$executable ${arguments.join(' ')}');
        if (arguments.contains('describe-stack-resources')) {
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{
              'StackResources': <Object?>[
                <String, Object?>{
                  'ResourceType': 'AWS::Lambda::Function',
                  'PhysicalResourceId': 'coupon-function',
                },
              ],
            }),
            '',
          );
        }
        return ProcessResult(0, 0, 'log line', '');
      },
    );

    final result = await starter.awsLogs(
      PublisherBackendAwsLogsRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        since: '30m',
      ),
    );

    expect(result.lambdaFunctionName, 'coupon-function');
    expect(result.stdoutText, 'log line');
    expect(commands.last, contains('/aws/lambda/coupon-function'));
    expect(commands.last, contains('--since 30m'));
  });
}
