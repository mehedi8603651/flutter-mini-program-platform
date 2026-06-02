part of '../publisher_backend_starter_test.dart';

void _registerAwsCloudTests() {
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
    expect(await stateFile.readAsString(), contains('PublisherBackendBaseUrl'));
  });

  test('deploy waits through cold-start health failures', () async {
    final commands = <String>[];
    var healthCalls = 0;
    var now = DateTime.utc(2026, 5, 22, 12);
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        commands.add('$executable ${arguments.join(' ')}');
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJson(), '');
        }
        return ProcessResult(0, 0, '{}', '');
      },
      healthGetter: (uri) async {
        healthCalls++;
        return healthCalls == 1
            ? http.Response('warming', 503)
            : http.Response('{"ok":true}', 200);
      },
      clock: () => now,
      delay: (duration) async {
        now = now.add(duration);
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
      ),
    );

    final result = await starter.awsDeploy(
      PublisherBackendAwsDeployRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.healthy, isTrue);
    expect(result.healthStatusCode, 200);
    expect(healthCalls, 2);
    expect(commands, contains(contains('sam deploy')));
  });

  test('deploy reports unhealthy after the retry window', () async {
    var now = DateTime.utc(2026, 5, 22, 12);
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        if (arguments.contains('describe-stacks')) {
          return ProcessResult(0, 0, _stackDescribeJson(), '');
        }
        return ProcessResult(0, 0, '{}', '');
      },
      healthGetter: (uri) async => http.Response('warming', 503),
      clock: () => now,
      delay: (duration) async {
        now = now.add(const Duration(seconds: 46));
      },
    );
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
        template: 'aws-lambda',
      ),
    );

    final result = await starter.awsDeploy(
      PublisherBackendAwsDeployRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
      ),
    );

    expect(result.healthy, isFalse);
    expect(result.healthStatusCode, 503);
    expect(result.healthError, contains('503'));
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
    expect(result.includeWrite, isFalse);
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

  test('AWS smoke optionally verifies coupon redeem writes', () async {
    for (final responseStatus in <String>['redeemed', 'already_redeemed']) {
      final requestedPosts = <Uri>[];
      final requestBodies = <Object?>[];
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, _stackDescribeJson(), '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        postRequester: (uri, {headers, body}) async {
          requestedPosts.add(uri);
          requestBodies.add(body);
          return http.Response(
            jsonEncode(<String, Object?>{
              'status': responseStatus,
              'couponId': 'coupon-20',
              'userId': 'smoke-user',
            }),
            200,
          );
        },
      );

      final result = await starter.awsSmoke(
        PublisherBackendAwsSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _awsEnvironment(),
          includeWrite: true,
          writeCouponId: 'coupon-20',
          writeUserId: 'smoke-user',
        ),
      );

      expect(result.includeWrite, isTrue);
      expect(result.passed, isTrue);
      final writeRoute = result.routes.last;
      expect(writeRoute.method, 'POST');
      expect(writeRoute.path, '/coupon/redeem');
      expect(writeRoute.statusCode, 200);
      expect(writeRoute.responseStatus, responseStatus);
      expect(requestedPosts.single.path, '/prod/coupon/redeem');
      expect(
        jsonDecode(requestBodies.single.toString()),
        containsPair('couponId', 'coupon-20'),
      );
    }
  });

  test('AWS write smoke fails on malformed success bodies', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, _stackDescribeJson(), '');
      },
      healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      postRequester: (uri, {headers, body}) async {
        return http.Response('not json', 200);
      },
    );

    final result = await starter.awsSmoke(
      PublisherBackendAwsSmokeRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        includeWrite: true,
      ),
    );

    expect(result.passed, isFalse);
    final writeRoute = result.routes.last;
    expect(writeRoute.statusCode, 200);
    expect(writeRoute.responseStatus, isNull);
    expect(writeRoute.error, contains('redeemed status'));
  });

  test('AWS write smoke fails on non-200 redeem responses', () async {
    final starter = PublisherBackendStarter(
      shellRunner: (executable, arguments, {workingDirectory}) async {
        return ProcessResult(0, 0, _stackDescribeJson(), '');
      },
      healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      postRequester: (uri, {headers, body}) async {
        return http.Response(
          jsonEncode(<String, Object?>{'errorCode': 'coupon_not_found'}),
          404,
        );
      },
    );

    final result = await starter.awsSmoke(
      PublisherBackendAwsSmokeRequest(
        miniProgramRootPath: miniProgramRoot.path,
        environment: _awsEnvironment(),
        includeWrite: true,
      ),
    );

    expect(result.passed, isFalse);
    final writeRoute = result.routes.last;
    expect(writeRoute.statusCode, 404);
    expect(writeRoute.error, contains('404'));
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
}
