import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AwsCloudPublisher', () {
    late Directory tempDir;
    late Directory miniProgramRoot;
    late String manifestPath;
    late String screensDirectoryPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_aws_publish_',
      );
      miniProgramRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await Directory(
        p.join(miniProgramRoot.path, 'assets'),
      ).create(recursive: true);
      await Directory(
        p.join(miniProgramRoot.path, 'stac', '.build', 'screens'),
      ).create(recursive: true);

      manifestPath = p.join(miniProgramRoot.path, 'manifest.json');
      screensDirectoryPath = p.join(
        miniProgramRoot.path,
        'stac',
        '.build',
        'screens',
      );

      await File(manifestPath).writeAsString('''
{
  "id": "coupon_center",
  "version": "1.2.3",
  "entry": "coupon_center_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics"],
  "cachePolicy": {
    "manifest": {"mode": "staleWhileError", "maxStaleSeconds": 3600},
    "entryScreen": {"mode": "staleWhileError", "maxStaleSeconds": 1800}
  }
}
''');
      await File(
        p.join(screensDirectoryPath, 'coupon_center_home.json'),
      ).writeAsString('{}');
      await File(
        p.join(miniProgramRoot.path, 'assets', 'icon.png'),
      ).writeAsBytes(<int>[0, 1, 2, 3]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('uploads immutable artifacts and metadata through aws cli', () async {
      final invocations = <List<String>>[];
      final publisher = AwsCloudPublisher(
        builder: _FakeMiniProgramBuilder(
          MiniProgramBuildResult(
            repoRootPath: tempDir.path,
            miniProgramId: 'coupon_center',
            miniProgramRootPath: miniProgramRoot.path,
            cliSource: 'fake',
            invocation: const <String>['dart', 'fake'],
            outputDirectoryPath: p.join(miniProgramRoot.path, 'stac', '.build'),
            screensDirectoryPath: screensDirectoryPath,
            entryScreenJsonPath: p.join(
              screensDirectoryPath,
              'coupon_center_home.json',
            ),
            pubGetRan: false,
          ),
        ),
        shellRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              invocations.add(<String>[executable, ...arguments]);
              if (arguments.contains('get-bucket-versioning')) {
                return ProcessResult(1, 0, '{"Status":"Enabled"}', '');
              }
              if (arguments.contains('put-object')) {
                final keyIndex = arguments.indexOf('--key');
                final key = keyIndex == -1
                    ? 'unknown'
                    : arguments[keyIndex + 1];
                return ProcessResult(
                  1,
                  0,
                  '{"VersionId":"${key.replaceAll('/', '_')}_v"}',
                  '',
                );
              }
              return ProcessResult(1, 1, '', 'unexpected command');
            },
      );

      final result = await publisher.publish(
        MiniProgramCloudPublishRequest(
          repoRootPath: tempDir.path,
          environment: CloudEnvironmentConfiguration(
            name: 'my-aws-prod',
            provider: 'aws',
            values: <String, dynamic>{
              'bucket': 'mini-program-prod',
              'region': 'us-east-1',
              'artifactsPrefix': 'artifacts',
              'metadataPrefix': 'metadata',
              'cloudFrontBaseUrl': 'https://d111111abcdef8.cloudfront.net',
              'apiBaseUrl': 'https://api.example.com',
              'awsProfile': 'prod',
            },
            configuredAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
            updatedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
          ),
          miniProgramId: 'coupon_center',
          miniProgramRootPath: miniProgramRoot.path,
        ),
      );

      expect(result.provider, 'aws');
      expect(result.environmentName, 'my-aws-prod');
      expect(result.bucketName, 'mini-program-prod');
      expect(result.region, 'us-east-1');
      expect(result.manifestKey, 'artifacts/coupon_center/1.2.3/manifest.json');
      expect(result.screensPrefixKey, 'artifacts/coupon_center/1.2.3/screens');
      expect(result.assetsPrefixKey, 'artifacts/coupon_center/1.2.3/assets');
      expect(
        result.metadataReleaseKey,
        'metadata/releases/coupon_center/1.2.3.json',
      );
      expect(result.metadataCatalogKey, 'metadata/catalog/coupon_center.json');
      expect(result.uploadedObjects.length, 5);
      expect(
        invocations.first,
        containsAll(<String>[
          'aws',
          '--region',
          'us-east-1',
          '--profile',
          'prod',
          's3api',
          'get-bucket-versioning',
        ]),
      );
      expect(
        invocations.any(
          (invocation) => invocation.contains(
            'artifacts/coupon_center/1.2.3/manifest.json',
          ),
        ),
        isTrue,
      );
      expect(
        invocations.any(
          (invocation) =>
              invocation.contains('metadata/catalog/coupon_center.json'),
        ),
        isTrue,
      );
    });

    test('fails when aws bucket versioning is not enabled', () async {
      final publisher = AwsCloudPublisher(
        builder: _FakeMiniProgramBuilder(
          MiniProgramBuildResult(
            repoRootPath: tempDir.path,
            miniProgramId: 'coupon_center',
            miniProgramRootPath: miniProgramRoot.path,
            cliSource: 'fake',
            invocation: const <String>['dart', 'fake'],
            outputDirectoryPath: p.join(miniProgramRoot.path, 'stac', '.build'),
            screensDirectoryPath: screensDirectoryPath,
            entryScreenJsonPath: p.join(
              screensDirectoryPath,
              'coupon_center_home.json',
            ),
            pubGetRan: false,
          ),
        ),
        shellRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              if (arguments.contains('get-bucket-versioning')) {
                return ProcessResult(1, 0, '{}', '');
              }
              return ProcessResult(1, 0, '{}', '');
            },
      );

      expect(
        () => publisher.publish(
          MiniProgramCloudPublishRequest(
            repoRootPath: tempDir.path,
            environment: CloudEnvironmentConfiguration(
              name: 'my-aws-prod',
              provider: 'aws',
              values: <String, dynamic>{
                'bucket': 'mini-program-prod',
                'region': 'us-east-1',
                'artifactsPrefix': 'artifacts',
                'metadataPrefix': 'metadata',
              },
              configuredAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
              updatedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
            ),
            miniProgramId: 'coupon_center',
            miniProgramRootPath: miniProgramRoot.path,
          ),
        ),
        throwsA(
          isA<MiniProgramPublishException>().having(
            (error) => error.message,
            'message',
            contains('does not have versioning enabled'),
          ),
        ),
      );
    });
  });
}

class _FakeMiniProgramBuilder extends MiniProgramBuilder {
  const _FakeMiniProgramBuilder(this.result);

  final MiniProgramBuildResult result;

  @override
  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) async {
    return result;
  }
}
