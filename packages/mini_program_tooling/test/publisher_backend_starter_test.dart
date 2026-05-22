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

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
