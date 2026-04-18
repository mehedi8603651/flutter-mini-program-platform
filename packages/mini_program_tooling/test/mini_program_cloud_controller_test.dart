import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramCloudController', () {
    late Directory tempDir;
    late ResolvedLocalCliEnvironmentState resolvedEnvironmentState;
    late CloudEnvironmentConfiguration environment;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_cloud_controller_',
      );
      final workspaceRoot = p.join(tempDir.path, 'workspace');
      await Directory(workspaceRoot).create(recursive: true);
      resolvedEnvironmentState = ResolvedLocalCliEnvironmentState(
        rootPath: workspaceRoot,
        filePath: p.join(workspaceRoot, '.mini_program', 'env.json'),
        scope: 'local',
        state: LocalCliEnvironmentState(
          schemaVersion: 2,
          repoRootPath: null,
          activeEnvironment: 'my-aws-prod',
          cloudEnvironments: <CloudEnvironmentConfiguration>[],
          initializedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
          updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        ),
      );
      environment = CloudEnvironmentConfiguration(
        name: 'my-aws-prod',
        provider: 'aws',
        values: <String, dynamic>{
          'bucket': 'mini-program-prod',
          'region': 'ap-south-1',
          'artifactsPrefix': 'artifacts',
          'metadataPrefix': 'metadata',
        },
        configuredAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
        updatedAtUtc: DateTime.utc(2026, 4, 19).toIso8601String(),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('deploy generates backend project and runs sam build/deploy', () async {
      final invocations = <List<String>>[];
      final controller = MiniProgramCloudController(
        processRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async {
              invocations.add(<String>[executable, ...arguments]);
              if (executable == 'sam' && arguments.contains('build')) {
                return ProcessResult(1, 0, 'built', '');
              }
              if (executable == 'sam' && arguments.contains('deploy')) {
                return ProcessResult(1, 0, 'deployed', '');
              }
              if (executable == 'aws' &&
                  arguments.contains('describe-stacks')) {
                return ProcessResult(
                  1,
                  0,
                  jsonEncode(<String, Object?>{
                    'Stacks': <Object?>[
                      <String, Object?>{
                        'StackStatus': 'CREATE_COMPLETE',
                        'Outputs': <Object?>[
                          <String, Object?>{
                            'OutputKey': 'BackendApiBaseUrl',
                            'OutputValue':
                                'https://abc123.execute-api.ap-south-1.amazonaws.com/prod/api/',
                          },
                          <String, Object?>{
                            'OutputKey': 'HealthUrl',
                            'OutputValue':
                                'https://abc123.execute-api.ap-south-1.amazonaws.com/prod/health',
                          },
                        ],
                      },
                    ],
                  }),
                  '',
                );
              }
              return ProcessResult(1, 1, '', 'unexpected command');
            },
        httpClient: MockClient((http.Request request) async {
          expect(
            request.url.toString(),
            'https://abc123.execute-api.ap-south-1.amazonaws.com/prod/health',
          );
          return http.Response('{"status":"ok"}', 200);
        }),
      );

      final result = await controller.deploy(
        MiniProgramCloudDeployRequest(
          resolvedEnvironmentState: resolvedEnvironmentState,
          environment: environment,
        ),
      );

      expect(result.stackName, 'mini-program-cloud-my-aws-prod');
      expect(result.apiBaseUrl, contains('/prod/api/'));
      expect(result.healthy, isTrue);
      expect(
        await File(
          p.join(
            resolvedEnvironmentState.rootPath,
            '.mini_program',
            'cloud',
            'aws_backend',
            'template.yaml',
          ),
        ).exists(),
        isTrue,
      );
      expect(
        invocations.any(
          (invocation) =>
              invocation.first == 'sam' && invocation.contains('build'),
        ),
        isTrue,
      );
      expect(
        invocations.any(
          (invocation) =>
              invocation.first == 'sam' && invocation.contains('deploy'),
        ),
        isTrue,
      );
    });

    test(
      'rollback rewrites catalog metadata to the requested version',
      () async {
        String? uploadedCatalogBody;
        final controller = MiniProgramCloudController(
          processRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                Map<String, String>? environment,
              }) async {
                if (executable != 'aws') {
                  return ProcessResult(1, 1, '', 'unexpected executable');
                }
                if (arguments.contains('get-object')) {
                  final key = arguments[arguments.indexOf('--key') + 1];
                  final destinationPath =
                      arguments[arguments.indexOf('--key') + 2];
                  if (key.endsWith('1.0.0.json')) {
                    await File(destinationPath).writeAsString(
                      jsonEncode(<String, Object?>{
                        'version': '1.0.0',
                        'artifacts': <String, Object?>{
                          'manifestKey':
                              'artifacts/coupon_center/1.0.0/manifest.json',
                        },
                      }),
                    );
                  } else if (key.endsWith('coupon_center.json')) {
                    await File(destinationPath).writeAsString(
                      jsonEncode(<String, Object?>{
                        'schemaVersion': 1,
                        'provider': 'aws',
                        'environment': 'my-aws-prod',
                        'miniProgramId': 'coupon_center',
                        'latestVersion': '1.2.3',
                        'releaseKey':
                            'metadata/releases/coupon_center/1.2.3.json',
                        'updatedAtUtc': DateTime.utc(
                          2026,
                          4,
                          18,
                        ).toIso8601String(),
                      }),
                    );
                  } else {
                    return ProcessResult(1, 1, '', 'unexpected object key');
                  }
                  return ProcessResult(1, 0, '{}', '');
                }
                if (arguments.contains('put-object')) {
                  final bodyPath = arguments[arguments.indexOf('--body') + 1];
                  uploadedCatalogBody = await File(bodyPath).readAsString();
                  return ProcessResult(1, 0, '{"VersionId":"abc"}', '');
                }
                return ProcessResult(1, 1, '', 'unexpected command');
              },
        );

        final result = await controller.rollback(
          MiniProgramCloudRollbackRequest(
            resolvedEnvironmentState: resolvedEnvironmentState,
            environment: environment,
            miniProgramId: 'coupon_center',
            version: '1.0.0',
          ),
        );

        final uploadedCatalogJson = jsonDecode(uploadedCatalogBody!);
        expect(result.version, '1.0.0');
        expect(uploadedCatalogJson['latestVersion'], '1.0.0');
        expect(
          uploadedCatalogJson['releaseKey'],
          'metadata/releases/coupon_center/1.0.0.json',
        );
      },
    );
  });
}
