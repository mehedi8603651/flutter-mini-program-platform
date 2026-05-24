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
      final handler = await File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'aws_lambda',
          'src',
          'handler.mjs',
        ),
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
      expect(handler, contains('ConsistentRead: true'));
      expect(handler, contains('LastEvaluatedKey'));
    });

    test(
      'scaffolds Firebase Functions Firestore files and respects force',
      () async {
        final starter = const PublisherBackendStarter();
        final result = await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'firestore',
          ),
        );

        expect(result.template, 'firebase-functions');
        expect(result.storageMode, 'firestore');
        final backendRoot = p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
        );
        expect(
          await File(p.join(backendRoot, 'firebase.json')).exists(),
          isTrue,
        );
        expect(
          await File(p.join(backendRoot, 'functions', 'index.js')).exists(),
          isTrue,
        );
        expect(
          await File(p.join(backendRoot, 'functions', 'router.js')).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(backendRoot, 'functions', 'firestore_store.js'),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(backendRoot, 'functions', 'data', 'coupons_list.json'),
          ).exists(),
          isTrue,
        );

        final firebaseJson = await File(
          p.join(backendRoot, 'firebase.json'),
        ).readAsString();
        final packageJson = await File(
          p.join(backendRoot, 'functions', 'package.json'),
        ).readAsString();
        final index = await File(
          p.join(backendRoot, 'functions', 'index.js'),
        ).readAsString();
        final store = await File(
          p.join(backendRoot, 'functions', 'firestore_store.js'),
        ).readAsString();
        final router = await File(
          p.join(backendRoot, 'functions', 'router.js'),
        ).readAsString();
        final readme = File(p.join(backendRoot, 'README.md'));

        expect(firebaseJson, contains('"functions"'));
        expect(packageJson, contains('"node": "22"'));
        expect(packageJson, contains('"firebase-functions": "^7.2.5"'));
        expect(packageJson, contains('"firebase-admin": "^13.10.0"'));
        expect(index, contains("firebase-functions/v2/https"));
        expect(index, contains('createFirestorePublisherBackendStore'));
        expect(store, contains("collection('miniPrograms')"));
        expect(store, contains("collection('redemptions')"));
        expect(router, contains('access-control-allow-origin'));
        expect(
          await readme.readAsString(),
          contains('Storage mode: Firestore'),
        );

        await readme.writeAsString('custom');
        expect(
          () => starter.scaffold(
            PublisherBackendScaffoldRequest(
              miniProgramRootPath: miniProgramRoot.path,
              template: 'firebase-functions',
              storageMode: 'firestore',
            ),
          ),
          throwsA(isA<PublisherBackendException>()),
        );
        await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'firestore',
            force: true,
          ),
        );
        expect(
          await readme.readAsString(),
          contains('Firebase publisher backend'),
        );
      },
    );

    test('rejects invalid publisher backend storage combinations', () {
      final starter = const PublisherBackendStarter();
      expect(
        () => starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'dynamodb',
          ),
        ),
        throwsA(isA<PublisherBackendException>()),
      );
      expect(
        () => starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'aws-lambda',
            storageMode: 'firestore',
          ),
        ),
        throwsA(isA<PublisherBackendException>()),
      );
      expect(
        () => starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'mock',
            storageMode: 'firestore',
          ),
        ),
        throwsA(isA<PublisherBackendException>()),
      );
    });

    test(
      'generated Firebase router serves read and redeem routes with fake store',
      () async {
        final nodeVersion = await Process.run('node', <String>['--version']);
        if (nodeVersion.exitCode != 0) {
          markTestSkipped('Node.js is not available.');
        }
        final starter = const PublisherBackendStarter();
        await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'firestore',
          ),
        );
        final routerUri = Uri.file(
          p.join(
            miniProgramRoot.path,
            'backend',
            'firebase_functions',
            'functions',
            'router.js',
          ),
        ).toString();

        final result = await _runNodeScript(tempDir, '''
import { createPublisherBackendHandler } from '$routerUri';

const coupons = new Set(['coupon-10']);
const redemptions = new Set();
const handler = createPublisherBackendHandler({
  clock: () => new Date('2026-05-23T12:00:00.000Z'),
  store: {
    homeBootstrap: async () => ({ title: 'Firebase home' }),
    couponsList: async () => ({ coupons: [{ id: 'coupon-10', title: 'Ten' }] }),
    authSession: async () => ({ authenticated: true }),
    redeemCoupon: async ({ couponId, userId }) => {
      if (!coupons.has(couponId)) {
        return { statusCode: 404, body: { errorCode: 'coupon_not_found' } };
      }
      const key = userId + ':' + couponId;
      if (redemptions.has(key)) {
        return { statusCode: 200, body: { status: 'already_redeemed', couponId, userId } };
      }
      redemptions.add(key);
      return { statusCode: 200, body: { status: 'redeemed', couponId, userId } };
    },
  },
});

async function call(method, path, body) {
  const response = {
    statusCode: 200,
    headers: {},
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; },
    end(body) { this.body = body ? JSON.parse(body) : null; },
  };
  await handler({ method, path, body }, response);
  return { statusCode: response.statusCode, body: response.body };
}

const health = await call('GET', '/health');
const home = await call('GET', '/home/bootstrap');
const couponsList = await call('GET', '/coupons/list');
const session = await call('GET', '/auth/session');
const missingCouponId = await call('POST', '/coupon/redeem', {});
const unknownCoupon = await call('POST', '/coupon/redeem', { couponId: 'missing' });
const redeemed = await call('POST', '/coupon/redeem', { couponId: 'coupon-10', userId: 'user-1' });
const duplicate = await call('POST', '/coupon/redeem', { couponId: 'coupon-10', userId: 'user-1' });

console.log(JSON.stringify({
  health,
  home,
  couponsList,
  session,
  missingCouponId,
  unknownCoupon,
  redeemed,
  duplicate,
}));
''');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final decoded =
            jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        expect(decoded['health']['statusCode'], 200);
        expect(decoded['home']['body']['title'], 'Firebase home');
        expect(decoded['couponsList']['body']['coupons'], hasLength(1));
        expect(decoded['session']['body']['authenticated'], isTrue);
        expect(decoded['missingCouponId']['statusCode'], 400);
        expect(decoded['unknownCoupon']['statusCode'], 404);
        expect(decoded['redeemed']['body']['status'], 'redeemed');
        expect(decoded['duplicate']['body']['status'], 'already_redeemed');
      },
    );

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

    test('deploys Firebase Functions backend and records outputs', () async {
      final commands = <String>[];
      final workingDirectories = <String?>[];
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          commands.add('$executable ${arguments.join(' ')}');
          workingDirectories.add(workingDirectory);
          return ProcessResult(0, 0, '', '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
        clock: () => DateTime.utc(2026, 5, 24, 12),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseDeploy(
        PublisherBackendFirebaseDeployRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      expect(result.projectId, 'coupon-prod');
      expect(result.region, 'asia-south1');
      expect(result.functionName, 'publisherBackend');
      expect(
        result.backendBaseUrl,
        'https://asia-south1-coupon-prod.cloudfunctions.net/publisherBackend/',
      );
      expect(result.healthUrl, endsWith('/publisherBackend/health'));
      expect(result.dependenciesInstalled, isTrue);
      expect(result.healthy, isTrue);
      expect(commands, contains('npm install'));
      expect(
        commands,
        contains(
          'firebase deploy --only functions:publisherBackend --project coupon-prod',
        ),
      );
      expect(
        workingDirectories,
        contains(
          p.join(
            miniProgramRoot.path,
            'backend',
            'firebase_functions',
            'functions',
          ),
        ),
      );

      final envFile = File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
          '.env',
        ),
      );
      expect(await envFile.exists(), isTrue);
      final envText = await envFile.readAsString();
      expect(envText, contains('PUBLISHER_BACKEND_REGION=asia-south1'));
      expect(envText, isNot(contains('FUNCTION_REGION=')));
      expect(envText, contains('MINI_PROGRAM_ID=coupon_app'));

      final stateFile = File(
        p.join(
          miniProgramRoot.path,
          '.mini_program',
          'publisher_backend.firebase.json',
        ),
      );
      expect(await stateFile.exists(), isTrue);
      expect(await stateFile.readAsString(), contains('coupon-prod'));
    });

    test('Firebase deploy preserves unrelated env keys', () async {
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      await Directory(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
          'node_modules',
        ),
      ).create(recursive: true);
      final envFile = File(
        p.join(
          miniProgramRoot.path,
          'backend',
          'firebase_functions',
          'functions',
          '.env',
        ),
      );
      await envFile.writeAsString(
        'CUSTOM_VALUE=keep\nFUNCTION_REGION=old\nPUBLISHER_BACKEND_REGION=old\nMINI_PROGRAM_ID=old\n',
      );

      await starter.firebaseDeploy(
        PublisherBackendFirebaseDeployRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      final envText = await envFile.readAsString();
      expect(envText, contains('CUSTOM_VALUE=keep'));
      expect(envText, contains('PUBLISHER_BACKEND_REGION=asia-south1'));
      expect(envText, contains('MINI_PROGRAM_ID=coupon_app'));
      expect(envText, isNot(contains('FUNCTION_REGION=old')));
      expect(envText, isNot(contains('PUBLISHER_BACKEND_REGION=old')));
      expect(envText, isNot(contains('MINI_PROGRAM_ID=old')));
    });

    test('Firebase deploy fails when scaffold is missing', () async {
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          return ProcessResult(0, 0, '', '');
        },
      );

      expect(
        () => starter.firebaseDeploy(
          PublisherBackendFirebaseDeployRequest(
            miniProgramRootPath: miniProgramRoot.path,
            environment: _firebaseEnvironment(),
          ),
        ),
        throwsA(isA<PublisherBackendException>()),
      );
    });

    test('Firebase status and outputs use configured function URL', () async {
      final starter = PublisherBackendStarter(
        healthGetter: (uri) async => http.Response('{"ok":true}', 200),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      final environment = _firebaseEnvironment(
        values: <String, dynamic>{
          'projectId': 'coupon-prod',
          'region': 'us-central1',
          'functionName': 'publisherBackend',
          'functionUrl':
              'https://custom-functions.example.com/publisherBackend',
        },
      );

      final status = await starter.firebaseStatus(
        PublisherBackendFirebaseStatusRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: environment,
        ),
      );
      final outputs = await starter.firebaseOutputs(
        PublisherBackendFirebaseOutputsRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: environment,
        ),
      );

      expect(status.scaffoldExists, isTrue);
      expect(status.healthy, isTrue);
      expect(
        status.backendBaseUrl,
        'https://custom-functions.example.com/publisherBackend/',
      );
      expect(
        status.healthUrl,
        'https://custom-functions.example.com/publisherBackend/health',
      );
      expect(
        outputs.outputs['PublisherBackendBaseUrl'],
        'https://custom-functions.example.com/publisherBackend/',
      );
      expect(outputs.outputs['PublisherBackendStorageMode'], 'firestore');
    });

    test('Firebase smoke checks read-only backend routes', () async {
      final requestedUris = <Uri>[];
      final starter = PublisherBackendStarter(
        healthGetter: (uri) async {
          requestedUris.add(uri);
          return http.Response('{"ok":true}', 200);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseSmoke(
        PublisherBackendFirebaseSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      expect(result.passed, isTrue);
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
        '/publisherBackend/health',
        '/publisherBackend/home/bootstrap',
        '/publisherBackend/coupons/list',
        '/publisherBackend/auth/session',
      ]);
    });

    test(
      'Firebase write smoke verifies Firestore redemption document',
      () async {
        final requestedPosts = <Uri>[];
        final requestedFirestoreReads = <Uri>[];
        final requestBodies = <Object?>[];
        final starter = PublisherBackendStarter(
          healthGetter: (uri) async => http.Response('{"ok":true}', 200),
          postRequester: (uri, {headers, body}) async {
            requestedPosts.add(uri);
            requestBodies.add(body);
            return http.Response(
              jsonEncode(<String, Object?>{
                'status': 'redeemed',
                'couponId': 'coupon-20',
                'userId': 'preview-user',
              }),
              200,
            );
          },
          firebaseAccessTokenProvider: () async => 'firebase-token',
          httpRequester: (method, uri, {headers, body}) async {
            requestedFirestoreReads.add(uri);
            return http.Response(
              _firestoreDocumentJson(<String, Object?>{
                'status': 'redeemed',
                'couponId': 'coupon-20',
                'userId': 'preview-user',
                'redeemedAtUtc': '2026-05-24T12:00:00Z',
              }),
              200,
            );
          },
        );
        await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'firestore',
          ),
        );

        final result = await starter.firebaseSmoke(
          PublisherBackendFirebaseSmokeRequest(
            miniProgramRootPath: miniProgramRoot.path,
            environment: _firebaseEnvironment(),
            includeWrite: true,
            writeCouponId: 'coupon-20',
            writeUserId: 'preview-user',
          ),
        );

        expect(result.includeWrite, isTrue);
        expect(result.passed, isTrue);
        final writeRoute = result.routes.last;
        expect(writeRoute.method, 'POST');
        expect(writeRoute.path, '/coupon/redeem');
        expect(writeRoute.statusCode, 200);
        expect(writeRoute.responseStatus, 'redeemed');
        expect(writeRoute.redemptionVerified, isTrue);
        expect(
          writeRoute.redemptionDocumentPath,
          'miniPrograms/coupon_app/redemptions/preview-user_coupon-20',
        );
        expect(requestedPosts.single.path, '/publisherBackend/coupon/redeem');
        expect(
          jsonDecode(requestBodies.single.toString()),
          containsPair('couponId', 'coupon-20'),
        );
        expect(
          requestedFirestoreReads.single.path,
          contains(
            '/miniPrograms/coupon_app/redemptions/preview-user_coupon-20',
          ),
        );
      },
    );

    test(
      'Firebase write smoke fails when redemption verification fails',
      () async {
        final starter = PublisherBackendStarter(
          healthGetter: (uri) async => http.Response('{"ok":true}', 200),
          postRequester: (uri, {headers, body}) async {
            return http.Response(
              jsonEncode(<String, Object?>{'status': 'redeemed'}),
              200,
            );
          },
          firebaseAccessTokenProvider: () async => 'firebase-token',
          httpRequester: (method, uri, {headers, body}) async =>
              http.Response('{}', 404),
          delay: (duration) async {},
        );
        await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'firestore',
          ),
        );

        final result = await starter.firebaseSmoke(
          PublisherBackendFirebaseSmokeRequest(
            miniProgramRootPath: miniProgramRoot.path,
            environment: _firebaseEnvironment(),
            includeWrite: true,
          ),
        );

        expect(result.passed, isFalse);
        final writeRoute = result.routes.last;
        expect(writeRoute.responseStatus, 'redeemed');
        expect(writeRoute.redemptionVerified, isFalse);
        expect(writeRoute.verificationError, contains('not found'));
        expect(writeRoute.error, contains('verification failed'));
      },
    );

    test('Firebase smoke fails when a route returns non-200', () async {
      final starter = PublisherBackendStarter(
        healthGetter: (uri) async {
          if (uri.path.endsWith('/coupons/list')) {
            return http.Response('unavailable', 503);
          }
          return http.Response('{"ok":true}', 200);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseSmoke(
        PublisherBackendFirebaseSmokeRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      expect(result.passed, isFalse);
      final coupons = result.routes.singleWhere(
        (route) => route.path == '/coupons/list',
      );
      expect(coupons.statusCode, 503);
      expect(coupons.passed, isFalse);
    });

    test('Firebase seed writes Firestore starter documents', () async {
      final requests = <Map<String, Object?>>[];
      final starter = PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          requests.add(<String, Object?>{
            'method': method,
            'uri': uri.toString(),
            'headers': headers,
            'body': body,
          });
          return http.Response('{}', 200);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseSeed(
        PublisherBackendFirebaseSeedRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      expect(result.seeded, isTrue);
      expect(result.itemCount, 4);
      expect(result.couponCount, 2);
      expect(
        requests.map((request) => request['method']),
        everyElement('PATCH'),
      );
      expect(
        requests.map((request) => request['uri'].toString()),
        contains(contains('/documents/miniPrograms/coupon_app/home/bootstrap')),
      );
      expect(
        requests.map((request) => request['uri'].toString()),
        contains(
          contains('/documents/miniPrograms/coupon_app/coupons/coupon-10'),
        ),
      );
      final firstBody =
          jsonDecode(requests.first['body']! as String) as Map<String, dynamic>;
      expect(firstBody['fields'], contains('title'));
      final headers = requests.first['headers']! as Map<String, String>;
      expect(headers['authorization'], 'Bearer firebase-token');
    });

    test('Firebase data status counts Firestore collections', () async {
      final requestedPaths = <String>[];
      final starter = PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          requestedPaths.add(uri.path);
          if (uri.path.endsWith('/home')) {
            return http.Response(_firestoreDocumentsJson(1), 200);
          }
          if (uri.path.endsWith('/sessions')) {
            return http.Response(_firestoreDocumentsJson(1), 200);
          }
          if (uri.path.endsWith('/coupons')) {
            return http.Response(_firestoreDocumentsJson(2), 200);
          }
          if (uri.path.endsWith('/redemptions')) {
            return http.Response(_firestoreDocumentsJson(3), 200);
          }
          return http.Response('{}', 404);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseDataStatus(
        PublisherBackendFirebaseDataStatusRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      expect(result.available, isTrue);
      expect(result.homeRecordCount, 1);
      expect(result.authSessionCount, 1);
      expect(result.couponCount, 2);
      expect(result.redemptionCount, 3);
      expect(result.appRecordCount, 4);
      expect(requestedPaths, hasLength(4));
    });

    test('Firebase data export writes logical app records only', () async {
      final starter = PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/home')) {
            return http.Response(
              _firestoreDocumentsJsonFrom(
                'coupon_app',
                'home',
                <String, Map<String, Object?>>{
                  'bootstrap': <String, Object?>{
                    'title': 'Firebase home',
                    'enabled': true,
                    'count': 2,
                    'price': 4.5,
                    'tags': <Object?>['one', null],
                    'meta': <String, Object?>{'tier': 'gold'},
                    'nothing': null,
                    'createdAt': _firestoreTimestamp('2026-05-24T12:00:00Z'),
                  },
                },
              ),
              200,
            );
          }
          if (uri.path.endsWith('/sessions')) {
            return http.Response(
              _firestoreDocumentsJsonFrom(
                'coupon_app',
                'sessions',
                <String, Map<String, Object?>>{
                  'demo': <String, Object?>{'authenticated': true},
                },
              ),
              200,
            );
          }
          if (uri.path.endsWith('/coupons')) {
            return http.Response(
              _firestoreDocumentsJsonFrom(
                'coupon_app',
                'coupons',
                <String, Map<String, Object?>>{
                  'coupon-10': <String, Object?>{'id': 'coupon-10'},
                  'coupon-20': <String, Object?>{'id': 'coupon-20'},
                },
              ),
              200,
            );
          }
          if (uri.path.endsWith('/redemptions')) {
            return http.Response(
              _firestoreDocumentsJsonFrom(
                'coupon_app',
                'redemptions',
                <String, Map<String, Object?>>{
                  'user_coupon': <String, Object?>{'couponId': 'coupon-10'},
                },
              ),
              200,
            );
          }
          return http.Response('{}', 404);
        },
        clock: () => DateTime.utc(2026, 5, 24, 12),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      final outputPath = p.join(tempDir.path, 'firebase-export.json');

      final result = await starter.firebaseDataExport(
        PublisherBackendFirebaseDataExportRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
          outputPath: outputPath,
        ),
      );

      expect(result.exported, isTrue);
      expect(result.appRecordCount, 4);
      expect(result.redemptionCount, 0);
      final export =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      expect(export['command'], 'publisher-backend firebase data export');
      expect(export['includeRedemptions'], isFalse);
      final records = export['records'] as List<dynamic>;
      expect(records, hasLength(4));
      expect(
        records.map((record) => record['collection']),
        isNot(contains('redemptions')),
      );
      final home =
          records.singleWhere((record) => record['collection'] == 'home')
              as Map<String, dynamic>;
      final data = home['data'] as Map<String, dynamic>;
      expect(data['title'], 'Firebase home');
      expect(data['enabled'], isTrue);
      expect(data['count'], 2);
      expect(data['price'], 4.5);
      expect(data['tags'], <Object?>['one', null]);
      expect(data['meta'], <String, Object?>{'tier': 'gold'});
      expect(data['nothing'], isNull);
      expect(data['createdAt'], '2026-05-24T12:00:00Z');
    });

    test('Firebase data export includes redemptions when requested', () async {
      final starter = PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/home') ||
              uri.path.endsWith('/sessions') ||
              uri.path.endsWith('/coupons')) {
            return http.Response(_firestoreDocumentsJson(0), 200);
          }
          if (uri.path.endsWith('/redemptions')) {
            return http.Response(
              _firestoreDocumentsJsonFrom(
                'coupon_app',
                'redemptions',
                <String, Map<String, Object?>>{
                  'preview-user_coupon-10': <String, Object?>{
                    'status': 'redeemed',
                    'couponId': 'coupon-10',
                    'userId': 'preview-user',
                    'redeemedAtUtc': '2026-05-24T12:00:00Z',
                  },
                },
              ),
              200,
            );
          }
          return http.Response('{}', 404);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseDataExport(
        PublisherBackendFirebaseDataExportRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
          outputPath: p.join(tempDir.path, 'firebase-export.json'),
          includeRedemptions: true,
        ),
      );

      expect(result.exported, isTrue);
      expect(result.redemptionCount, 1);
      expect(result.itemCount, 1);
    });

    test(
      'Firebase data import dry-run validates and skips redemptions',
      () async {
        final requests = <String>[];
        final starter = PublisherBackendStarter(
          firebaseAccessTokenProvider: () async => 'firebase-token',
          httpRequester: (method, uri, {headers, body}) async {
            requests.add(method);
            return http.Response('{}', 200);
          },
        );
        await starter.scaffold(
          PublisherBackendScaffoldRequest(
            miniProgramRootPath: miniProgramRoot.path,
            template: 'firebase-functions',
            storageMode: 'firestore',
          ),
        );
        final inputPath = p.join(tempDir.path, 'firebase-export.json');
        await File(inputPath).writeAsString(
          jsonEncode(_firebaseExportFixture(includeRedemption: true)),
        );

        final result = await starter.firebaseDataImport(
          PublisherBackendFirebaseDataImportRequest(
            miniProgramRootPath: miniProgramRoot.path,
            environment: _firebaseEnvironment(),
            inputPath: inputPath,
            dryRun: true,
          ),
        );

        expect(result.succeeded, isTrue);
        expect(result.imported, isFalse);
        expect(result.appRecordCount, 1);
        expect(result.redemptionCount, 0);
        expect(result.skippedRedemptionCount, 1);
        expect(requests, isEmpty);
      },
    );

    test('Firebase data import upserts records and redemptions', () async {
      final requests = <Map<String, Object?>>[];
      final starter = PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          requests.add(<String, Object?>{
            'method': method,
            'uri': uri.toString(),
            'body': body,
          });
          return http.Response('{}', 200);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );
      final inputPath = p.join(tempDir.path, 'firebase-export.json');
      await File(inputPath).writeAsString(
        jsonEncode(_firebaseExportFixture(includeRedemption: true)),
      );

      final result = await starter.firebaseDataImport(
        PublisherBackendFirebaseDataImportRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
          inputPath: inputPath,
          includeRedemptions: true,
        ),
      );

      expect(result.imported, isTrue);
      expect(result.itemCount, 2);
      expect(
        requests.map((request) => request['method']),
        everyElement('PATCH'),
      );
      expect(
        requests.map((request) => request['uri'].toString()),
        contains(contains('/miniPrograms/coupon_app/redemptions/user_coupon')),
      );
      final body =
          jsonDecode(requests.first['body']! as String) as Map<String, dynamic>;
      expect(body['fields'], contains('title'));
    });

    test('Firebase data redemptions filters and limits records', () async {
      final starter = PublisherBackendStarter(
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/redemptions')) {
            return http.Response(
              _firestoreDocumentsJsonFrom(
                'coupon_app',
                'redemptions',
                <String, Map<String, Object?>>{
                  'a': <String, Object?>{
                    'status': 'redeemed',
                    'couponId': 'coupon-10',
                    'userId': 'preview-user',
                    'redeemedAtUtc': '2026-05-24T10:00:00Z',
                  },
                  'b': <String, Object?>{
                    'status': 'redeemed',
                    'couponId': 'coupon-10',
                    'userId': 'preview-user',
                    'redeemedAtUtc': '2026-05-24T12:00:00Z',
                  },
                  'c': <String, Object?>{
                    'status': 'redeemed',
                    'couponId': 'coupon-20',
                    'userId': 'preview-user',
                    'redeemedAtUtc': '2026-05-24T11:00:00Z',
                  },
                },
              ),
              200,
            );
          }
          return http.Response('{}', 404);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseDataRedemptions(
        PublisherBackendFirebaseDataRedemptionsRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
          couponId: 'coupon-10',
          userId: 'preview-user',
          limit: 1,
        ),
      );

      expect(result.available, isTrue);
      expect(result.matchedCount, 2);
      expect(result.returnedCount, 1);
      expect(
        (result.records.single['data'] as Map)['redeemedAtUtc'],
        '2026-05-24T12:00:00Z',
      );
    });

    test('Firebase destroy blocks when Firestore data exists', () async {
      var shellCalled = false;
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          shellCalled = true;
          return ProcessResult(0, 0, '', '');
        },
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async {
          if (uri.path.endsWith('/home')) {
            return http.Response(_firestoreDocumentsJson(1), 200);
          }
          return http.Response(_firestoreDocumentsJson(0), 200);
        },
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseDestroy(
        PublisherBackendFirebaseDestroyRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
        ),
      );

      expect(result.deleted, isFalse);
      expect(result.blockedByData, isTrue);
      expect(result.error, contains('--confirm-data-loss'));
      expect(shellCalled, isFalse);
    });

    test('Firebase destroy proceeds with data confirmation', () async {
      final commands = <String>[];
      final starter = PublisherBackendStarter(
        shellRunner: (executable, arguments, {workingDirectory}) async {
          commands.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
        firebaseAccessTokenProvider: () async => 'firebase-token',
        httpRequester: (method, uri, {headers, body}) async =>
            http.Response(_firestoreDocumentsJson(0), 200),
        clock: () => DateTime.utc(2026, 5, 24, 12),
      );
      await starter.scaffold(
        PublisherBackendScaffoldRequest(
          miniProgramRootPath: miniProgramRoot.path,
          template: 'firebase-functions',
          storageMode: 'firestore',
        ),
      );

      final result = await starter.firebaseDestroy(
        PublisherBackendFirebaseDestroyRequest(
          miniProgramRootPath: miniProgramRoot.path,
          environment: _firebaseEnvironment(),
          confirmDataLoss: true,
        ),
      );

      expect(result.deleted, isTrue);
      expect(result.deletedAtUtc, '2026-05-24T12:00:00.000Z');
      expect(
        commands,
        contains(
          'firebase functions:delete publisherBackend --region asia-south1 --project coupon-prod --force',
        ),
      );
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
        queryCommands.any(
          (command) => command.contains('--exclusive-start-key'),
        ),
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
      expect(
        commands.any((command) => command.contains('delete-stack')),
        isTrue,
      );
      expect(
        commands.any((command) => command.contains('stack-delete-complete')),
        isTrue,
      );
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

CloudEnvironmentConfiguration _firebaseEnvironment({
  Map<String, dynamic>? values,
}) {
  return CloudEnvironmentConfiguration(
    name: 'my-firebase-prod',
    provider: 'firebase',
    values:
        values ??
        <String, dynamic>{
          'projectId': 'coupon-prod',
          'region': 'asia-south1',
          'functionName': 'publisherBackend',
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

Map<String, Object?> _plainExportItem({
  required String pk,
  required String sk,
  required String recordType,
  required Map<String, Object?> payload,
}) {
  return <String, Object?>{
    'pk': pk,
    'sk': sk,
    'recordType': recordType,
    'payload': payload,
    'updatedAtUtc': '2026-05-23T12:00:00.000Z',
  };
}

Map<String, Object?> _redemptionItem({
  required String couponId,
  required String userId,
  required String createdAtUtc,
}) {
  return <String, Object?>{
    'pk': 'APP#coupon_app#REDEMPTIONS',
    'sk': 'USER#$userId#COUPON#$couponId',
    'recordType': 'redemption',
    'couponId': couponId,
    'userId': userId,
    'payload': <String, Object?>{
      'status': 'redeemed',
      'couponId': couponId,
      'userId': userId,
      'redeemedAtUtc': createdAtUtc,
    },
    'createdAtUtc': createdAtUtc,
  };
}

Map<String, Object?> _dynamoDbItem({
  required String pk,
  required String sk,
  required String recordType,
  required Map<String, Object?> payload,
}) {
  return <String, Object?>{
    'pk': pk,
    'sk': sk,
    'recordType': recordType,
    'payload': payload,
    'updatedAtUtc': '2026-05-23T12:00:00.000Z',
  };
}

String _dynamoDbQueryItemsJson(List<Map<String, Object?>> items) {
  return jsonEncode(<String, Object?>{
    'Items': items
        .map(
          (item) => item.map(
            (key, value) => MapEntry(key, _toDynamoDbTestAttribute(value)),
          ),
        )
        .toList(),
  });
}

String _firestoreDocumentsJson(int count) {
  return jsonEncode(<String, Object?>{
    'documents': List<Object?>.generate(
      count,
      (index) => <String, Object?>{
        'name': 'projects/test/databases/(default)/documents/doc-$index',
      },
    ),
  });
}

String _firestoreDocumentsJsonFrom(
  String appId,
  String collection,
  Map<String, Map<String, Object?>> documents,
) {
  return jsonEncode(<String, Object?>{
    'documents': documents.entries
        .map(
          (entry) => <String, Object?>{
            'name':
                'projects/test/databases/(default)/documents/miniPrograms/$appId/$collection/${entry.key}',
            'fields': entry.value.map(
              (key, value) => MapEntry(key, _toFirestoreTestValue(value)),
            ),
          },
        )
        .toList(),
  });
}

String _firestoreDocumentJson(Map<String, Object?> fields) {
  return jsonEncode(<String, Object?>{
    'fields': fields.map(
      (key, value) => MapEntry(key, _toFirestoreTestValue(value)),
    ),
  });
}

Map<String, Object?> _firebaseExportFixture({required bool includeRedemption}) {
  return <String, Object?>{
    'schemaVersion': 1,
    'command': 'publisher-backend firebase data export',
    'provider': 'firebase',
    'environmentName': 'my-firebase-prod',
    'projectId': 'coupon-prod',
    'region': 'asia-south1',
    'functionName': 'publisherBackend',
    'miniProgramId': 'coupon_app',
    'storageMode': 'firestore',
    'includeRedemptions': includeRedemption,
    'records': <Object?>[
      <String, Object?>{
        'recordType': 'home',
        'collection': 'home',
        'documentId': 'bootstrap',
        'documentPath': 'miniPrograms/coupon_app/home/bootstrap',
        'data': <String, Object?>{'title': 'Imported home'},
      },
      if (includeRedemption)
        <String, Object?>{
          'recordType': 'redemption',
          'collection': 'redemptions',
          'documentId': 'user_coupon',
          'documentPath': 'miniPrograms/coupon_app/redemptions/user_coupon',
          'data': <String, Object?>{
            'status': 'redeemed',
            'couponId': 'coupon-10',
            'userId': 'preview-user',
            'redeemedAtUtc': '2026-05-24T12:00:00Z',
          },
        },
    ],
  };
}

_TestFirestoreTimestamp _firestoreTimestamp(String value) =>
    _TestFirestoreTimestamp(value);

class _TestFirestoreTimestamp {
  const _TestFirestoreTimestamp(this.value);

  final String value;
}

Map<String, Object?> _toFirestoreTestValue(Object? value) {
  if (value == null) {
    return const <String, Object?>{'nullValue': null};
  }
  if (value is bool) {
    return <String, Object?>{'booleanValue': value};
  }
  if (value is int) {
    return <String, Object?>{'integerValue': value.toString()};
  }
  if (value is num) {
    return <String, Object?>{'doubleValue': value};
  }
  if (value is String) {
    return <String, Object?>{'stringValue': value};
  }
  if (value is _TestFirestoreTimestamp) {
    return <String, Object?>{'timestampValue': value.value};
  }
  if (value is List) {
    return <String, Object?>{
      'arrayValue': <String, Object?>{
        'values': value.map(_toFirestoreTestValue).toList(),
      },
    };
  }
  if (value is Map) {
    return <String, Object?>{
      'mapValue': <String, Object?>{
        'fields': value.map(
          (key, nestedValue) =>
              MapEntry(key.toString(), _toFirestoreTestValue(nestedValue)),
        ),
      },
    };
  }
  return <String, Object?>{'stringValue': value.toString()};
}

Map<String, Object?> _toDynamoDbTestAttribute(Object? value) {
  if (value == null) {
    return const <String, Object?>{'NULL': true};
  }
  if (value is bool) {
    return <String, Object?>{'BOOL': value};
  }
  if (value is num) {
    return <String, Object?>{'N': value.toString()};
  }
  if (value is String) {
    return <String, Object?>{'S': value};
  }
  if (value is List) {
    return <String, Object?>{'L': value.map(_toDynamoDbTestAttribute).toList()};
  }
  if (value is Map) {
    return <String, Object?>{
      'M': value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _toDynamoDbTestAttribute(nestedValue)),
      ),
    };
  }
  return <String, Object?>{'S': value.toString()};
}

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
