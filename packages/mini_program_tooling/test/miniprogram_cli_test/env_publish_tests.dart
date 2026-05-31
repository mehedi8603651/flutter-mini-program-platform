part of '../miniprogram_cli_test.dart';

void _registerEnvPublishTests() {
  test(
    'publish --target cloud uses the active named cloud environment',
    () async {
      final standaloneRoot = p.join(tempDir.path, 'coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
        version: '1.2.3',
      );
      final envState = LocalCliEnvironmentState(
        schemaVersion: 2,
        repoRootPath: repoRoot.path,
        activeEnvironment: 'my-aws-prod',
        cloudEnvironments: <CloudEnvironmentConfiguration>[
          CloudEnvironmentConfiguration(
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
        ],
        initializedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
        updatedAtUtc: DateTime.utc(2026, 4, 18).toIso8601String(),
      );
      await stateStore.writeEnvironmentState(standaloneRoot, envState);
      final cloudPublisher = _FakeMiniProgramCloudPublisher();

      final exitCode = await MiniprogramCli(
        stateStore: stateStore,
        stdoutSink: StringBuffer(),
        stderrSink: StringBuffer(),
        cloudPublisher: cloudPublisher,
        workingDirectory: standaloneRoot,
      ).run(<String>['publish', '--target', 'cloud']);

      expect(exitCode, 0);
      expect(cloudPublisher.lastRequest, isNotNull);
      expect(cloudPublisher.lastRequest!.environment.name, 'my-aws-prod');
      expect(cloudPublisher.lastRequest!.environment.provider, 'aws');
      expect(cloudPublisher.lastRequest!.miniProgramId, 'coupon_center');
      expect(
        cloudPublisher.lastRequest!.miniProgramRootPath,
        p.normalize(p.absolute(standaloneRoot)),
      );
    },
  );
}
