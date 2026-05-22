import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PublisherBackendStarter', () {
    late Directory tempDir;
    late Directory miniProgramRoot;
    int? runningPort;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_publisher_backend_',
      );
      miniProgramRoot = Directory(p.join(tempDir.path, 'coupon_app'));
      await miniProgramRoot.create(recursive: true);
      await File(p.join(miniProgramRoot.path, 'manifest.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'id': 'coupon_app',
          'version': '1.0.0',
          'entry': 'coupon_app_home',
        }),
      );
    });

    tearDown(() async {
      if (runningPort != null) {
        try {
          await const PublisherBackendStarter().stop(
            miniProgramRootPath: miniProgramRoot.path,
          );
        } catch (_) {
          // Best-effort cleanup for failed process tests.
        }
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

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
          p.join(
            miniProgramRoot.path,
            'backend',
            'aws_lambda',
            'template.yaml',
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
      expect(template, isNot(contains('AWS::DynamoDB::Table')));
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

      expect(template, contains('AWS::DynamoDB::Table'));
      expect(template, contains('BillingMode: PAY_PER_REQUEST'));
      expect(template, contains('PUBLISHER_BACKEND_STORAGE: dynamodb'));
      expect(template, contains('PUBLISHER_BACKEND_TABLE_NAME'));
      expect(template, contains('MINI_PROGRAM_ID: coupon_app'));
      expect(template, contains('DynamoDBCrudPolicy'));
      expect(template, contains('PublisherBackendDataTableName'));
      expect(packageJson, contains('@aws-sdk/client-dynamodb'));
      expect(packageJson, contains('@aws-sdk/lib-dynamodb'));
      expect(readme, contains('Storage mode: DynamoDB'));
    });

    test(
      'generated bundled Lambda handler serves read and redeem routes',
      () async {
        final nodeVersion = await Process.run('node', <String>['--version']);
        if (nodeVersion.exitCode != 0) {
          markTestSkipped('Node.js is not available.');
        }
        final starter = const PublisherBackendStarter();
        await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'aws-lambda',
          ),
        );
        final handlerUri = Uri.file(
          p.join(
            miniProgramRoot.path,
            'backend',
            'aws_lambda',
            'src',
            'handler.mjs',
          ),
        ).toString();

        final result = await _runNodeScript(tempDir, '''
import { handler } from '$handlerUri';

const event = (method, path, body) => ({
  rawPath: `/prod\${path}`,
  requestContext: { stage: 'prod', http: { method } },
  body: body == null ? undefined : JSON.stringify(body),
});

const home = await handler(event('GET', '/home/bootstrap'));
const coupons = await handler(event('GET', '/coupons/list'));
const session = await handler(event('GET', '/auth/session'));
const redeemed = await handler(event('POST', '/coupon/redeem', { couponId: 'coupon-10' }));
console.log(JSON.stringify({
  homeStatus: home.statusCode,
  homeTitle: JSON.parse(home.body).title,
  couponsStatus: coupons.statusCode,
  couponCount: JSON.parse(coupons.body).coupons.length,
  sessionStatus: session.statusCode,
  redeemStatus: redeemed.statusCode,
  redeemBody: JSON.parse(redeemed.body),
}));
''');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final decoded =
            jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        expect(decoded['homeStatus'], 200);
        expect(decoded['homeTitle'], contains('Coupon App'));
        expect(decoded['couponCount'], 2);
        expect(decoded['sessionStatus'], 200);
        expect(decoded['redeemStatus'], 200);
        expect(decoded['redeemBody']['status'], 'redeemed');
      },
    );

    test(
      'generated Lambda handler supports an injected DynamoDB store',
      () async {
        final nodeVersion = await Process.run('node', <String>['--version']);
        if (nodeVersion.exitCode != 0) {
          markTestSkipped('Node.js is not available.');
        }
        final starter = const PublisherBackendStarter();
        await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'aws-lambda',
            storageMode: 'dynamodb',
          ),
        );
        final handlerUri = Uri.file(
          p.join(
            miniProgramRoot.path,
            'backend',
            'aws_lambda',
            'src',
            'handler.mjs',
          ),
        ).toString();

        final result = await _runNodeScript(tempDir, '''
import { handler, setPublisherBackendStoreForTesting } from '$handlerUri';

setPublisherBackendStoreForTesting({
  homeBootstrap: async () => ({ title: 'Dynamo home' }),
  couponsList: async () => ({ coupons: [{ id: 'coupon-10', title: 'Ten' }] }),
  authSession: async () => ({ authenticated: true }),
  redeemCoupon: async (body) => body?.couponId
    ? { statusCode: 200, body: { status: 'redeemed', couponId: body.couponId } }
    : { statusCode: 400, body: { errorCode: 'missing_coupon_id' } },
});

const event = (method, path, body) => ({
  rawPath: `/prod\${path}`,
  requestContext: { stage: 'prod', http: { method } },
  body: body == null ? undefined : JSON.stringify(body),
});
const home = await handler(event('GET', '/home/bootstrap'));
const redeemed = await handler(event('POST', '/coupon/redeem', { couponId: 'coupon-10' }));
const missing = await handler(event('POST', '/coupon/redeem', {}));
console.log(JSON.stringify({
  home: JSON.parse(home.body),
  redeemedStatus: redeemed.statusCode,
  redeemed: JSON.parse(redeemed.body),
  missingStatus: missing.statusCode,
}));
''');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final decoded =
            jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        expect(decoded['home']['title'], 'Dynamo home');
        expect(decoded['redeemedStatus'], 200);
        expect(decoded['redeemed']['couponId'], 'coupon-10');
        expect(decoded['missingStatus'], 400);
      },
    );

    test('deploys AWS Lambda backend with SAM and records outputs', () async {
      final commands = <String>[];
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          commands.add('$executable ${arguments.join(' ')}');
          if (executable == 'aws' &&
              arguments.contains('cloudformation') &&
              arguments.contains('describe-stacks')) {
            return ProcessResult(0, 0, _stackDescribeJson(), '');
          }
          return ProcessResult(0, 0, '{}', '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        clock: () => DateTime.utc(2026, 5, 22, 12),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'aws-lambda',
        ),
      );
      final environment = _awsEnvironment();

      final result = await starter.awsDeploy(
        PublisherBackendAwsDeployRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: environment,
        ),
      );

      expect(
        result.backendBaseUrl,
        'https://abc.execute-api.ap-south-1.amazonaws.com/prod/',
      );
      expect(result.healthy, isTrue);
      expect(commands, contains(contains('sam build --template-file')));
      expect(
        commands,
        contains(
          allOf(
            contains('sam deploy'),
            contains(
              '--stack-name mini-program-publisher-backend-coupon-app-my-aws-prod',
            ),
            contains('--s3-bucket sam-artifacts'),
            contains('--profile my-aws'),
          ),
        ),
      );
      final stateFile = File(
        p.join(
          miniProgramRoot.path,
          '.mini_program',
          'publisher_backend.aws.json',
        ),
      );
      expect(await stateFile.exists(), isTrue);
      expect(
        await stateFile.readAsString(),
        contains('PublisherBackendBaseUrl'),
      );
    });

    test('AWS status reports missing stack without failing', () async {
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(
            0,
            255,
            '',
            'ValidationError: Stack with id test does not exist',
          );
        },
      );

      final result = await starter.awsStatus(
        PublisherBackendAwsStatusRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _awsEnvironment(),
        ),
      );

      expect(result.stackExists, isFalse);
      expect(
        result.stackName,
        'mini-program-publisher-backend-coupon-app-my-aws-prod',
      );
    });

    test('AWS smoke checks read-only backend routes', () async {
      final requestedUris = <Uri>[];
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _stackDescribeJson(), '');
        },
        healthGetter: (uri) async {
          requestedUris.add(uri);
          return http.Response('{"ok":true}', 200);
        },
      );

      final result = await starter.awsSmoke(
        PublisherBackendAwsSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _awsEnvironment(),
        ),
      );

      expect(result.stackExists, isTrue);
      expect(result.passed, isTrue);
      expect(result.backendBaseUrl, endsWith('/prod/'));
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
        '/prod/health',
        '/prod/home/bootstrap',
        '/prod/coupons/list',
        '/prod/auth/session',
      ]);
    });

    test('AWS smoke fails when a route returns non-200', () async {
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _stackDescribeJson(), '');
        },
        healthGetter: (uri) async {
          if (uri.path.endsWith('/coupons/list')) {
            return http.Response('unavailable', 503);
          }
          return http.Response('{"ok":true}', 200);
        },
      );

      final result = await starter.awsSmoke(
        PublisherBackendAwsSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _awsEnvironment(),
        ),
      );

      expect(result.passed, isFalse);
      final coupons = result.routes.singleWhere(
        (route) => route.path == '/coupons/list',
      );
      expect(coupons.statusCode, 503);
      expect(coupons.passed, isFalse);
    });

    test('AWS smoke reports missing stack', () async {
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(
            0,
            255,
            '',
            'ValidationError: Stack with id test does not exist',
          );
        },
      );

      final result = await starter.awsSmoke(
        PublisherBackendAwsSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _awsEnvironment(),
        ),
      );

      expect(result.stackExists, isFalse);
      expect(result.passed, isFalse);
      expect(result.routes, isEmpty);
      expect(result.error, contains('was not found'));
    });

    test('AWS smoke fails when backend base URL output is missing', () async {
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _stackDescribeJsonWithoutBaseUrl(), '');
        },
      );

      final result = await starter.awsSmoke(
        PublisherBackendAwsSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _awsEnvironment(),
        ),
      );

      expect(result.stackExists, isTrue);
      expect(result.backendBaseUrl, isNull);
      expect(result.passed, isFalse);
      expect(result.routes, isEmpty);
      expect(result.error, contains('PublisherBackendBaseUrl'));
    });

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
          final count = joined.contains('APP#coupon_app#REDEMPTIONS') ? 1 : 4;
          return ProcessResult(
            0,
            0,
            jsonEncode(<String, Object?>{'Count': count}),
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

    test(
      'AWS logs resolves Lambda function before tailing CloudWatch',
      () async {
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
      },
    );

    test('runs, serves mock routes, reports status, and stops', () async {
      final starter = const PublisherBackendStarter();
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
        ),
      );
      runningPort = await _freePort();

      final runResult = await starter.run(
        miniProgramRootPath: miniProgramRoot.path,
        port: runningPort!,
      );
      expect(runResult.alreadyRunning, isFalse);
      expect(runResult.state.port, runningPort);

      final health = await http.get(
        Uri.parse('http://127.0.0.1:$runningPort/health'),
      );
      expect(health.statusCode, 200);
      final home = await http.get(
        Uri.parse('http://127.0.0.1:$runningPort/home/bootstrap'),
      );
      expect(home.statusCode, 200);
      expect(home.body, contains('Coupon App backend starter'));
      final coupons = await http.get(
        Uri.parse('http://127.0.0.1:$runningPort/coupons/list'),
      );
      expect(coupons.statusCode, 200);
      expect(coupons.body, contains('imageUrl'));
      final options = await http.Request(
        'OPTIONS',
        Uri.parse('http://127.0.0.1:$runningPort/coupons/list'),
      ).send();
      expect(options.statusCode, HttpStatus.noContent);
      expect(
        options.headers['access-control-allow-headers'],
        contains('x-mini-program-app-id'),
      );
      expect(
        options.headers['access-control-allow-headers'],
        contains('x-mini-program-host-app'),
      );

      final status = await starter.status(
        miniProgramRootPath: miniProgramRoot.path,
      );
      expect(status.hasState, isTrue);
      expect(status.healthy, isTrue);

      final stop = await starter.stop(
        miniProgramRootPath: miniProgramRoot.path,
      );
      runningPort = null;
      expect(stop.stopped, isTrue);
    });
  });
}

CloudEnvironmentConfiguration _awsEnvironment() {
  return CloudEnvironmentConfiguration(
    name: 'my-aws-prod',
    provider: 'aws',
    values: <String, dynamic>{
      'bucket': 'delivery-bucket',
      'region': 'ap-south-1',
      'samS3Bucket': 'sam-artifacts',
      'awsProfile': 'my-aws',
    },
    configuredAtUtc: DateTime.utc(2026).toIso8601String(),
    updatedAtUtc: DateTime.utc(2026).toIso8601String(),
  );
}

String _stackDescribeJson() => jsonEncode(<String, Object?>{
  'Stacks': <Object?>[
    <String, Object?>{
      'StackStatus': 'CREATE_COMPLETE',
      'Outputs': <Object?>[
        <String, Object?>{
          'OutputKey': 'PublisherBackendBaseUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendHealthUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/health',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendFunctionName',
          'OutputValue': 'coupon-function',
        },
      ],
    },
  ],
});

String _stackDescribeJsonWithoutBaseUrl() => jsonEncode(<String, Object?>{
  'Stacks': <Object?>[
    <String, Object?>{
      'StackStatus': 'CREATE_COMPLETE',
      'Outputs': <Object?>[
        <String, Object?>{
          'OutputKey': 'PublisherBackendHealthUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/health',
        },
      ],
    },
  ],
});

String _stackDescribeJsonWithDataTable() => jsonEncode(<String, Object?>{
  'Stacks': <Object?>[
    <String, Object?>{
      'StackStatus': 'CREATE_COMPLETE',
      'Outputs': <Object?>[
        <String, Object?>{
          'OutputKey': 'PublisherBackendBaseUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendHealthUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/health',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendFunctionName',
          'OutputValue': 'coupon-function',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendStorageMode',
          'OutputValue': 'dynamodb',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendDataTableName',
          'OutputValue': 'coupon-data-table',
        },
      ],
    },
  ],
});

Future<ProcessResult> _runNodeScript(Directory tempDir, String source) async {
  final script = File(p.join(tempDir.path, 'node_handler_test.mjs'));
  await script.writeAsString(source);
  return Process.run('node', <String>[script.path]);
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
