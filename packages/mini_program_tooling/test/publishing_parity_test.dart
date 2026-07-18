import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('publishing parity', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_tooling_publishing_parity_',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('static instructions and written-file ordering stay stable', () async {
      final miniProgramRoot = Directory(
        p.join(tempDirectory.path, 'mini_program'),
      );
      final screensPath = p.join(
        miniProgramRoot.path,
        'mp',
        '.build',
        'screens',
      );
      await Directory(screensPath).create(recursive: true);
      await File(p.join(miniProgramRoot.path, 'manifest.json')).writeAsString(
        '''
{
  "id": "weather",
  "version": "2.3.4",
  "entry": "weather_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": []
}
''',
      );
      await File(p.join(screensPath, 'weather_home.json')).writeAsString(
        '{"schemaVersion":1,"screenId":"weather_home",'
        '"root":{"type":"text","props":{"data":"Weather"}}}',
      );
      final outputPath = p.join(tempDirectory.path, 'public');
      final result =
          await MiniProgramStaticPublisher(
            builder: _PublishingFakeBuilder(
              MiniProgramBuildResult(
                repoRootPath: tempDirectory.path,
                miniProgramRootPath: miniProgramRoot.path,
                miniProgramId: 'weather',
                outputDirectoryPath: p.join(
                  miniProgramRoot.path,
                  'mp',
                  '.build',
                ),
                screensDirectoryPath: screensPath,
                entryScreenJsonPath: p.join(screensPath, 'weather_home.json'),
                cliSource: 'test',
                invocation: const <String>['dart', 'test'],
                pubGetRan: false,
              ),
            ),
          ).publish(
            MiniProgramStaticPublishRequest(
              repoRootPath: tempDirectory.path,
              outputPath: outputPath,
              miniProgramId: 'weather',
            ),
          );

      expect(
        await File(result.instructionsPath).readAsString(),
        '''# MiniProgram Static Artifacts

This directory contains the portable artifact bundle for `weather`
version `2.3.4` under `artifacts/weather/2.3.4/`.

Upload the `artifacts/` directory to any public static file host. Upload the
immutable version directory first and `artifacts/weather/latest.json`
last. GitHub Pages users should retain the generated `.nojekyll` marker.

Public artifacts must never contain secrets, private user data, authentication
state, payment data, or server-side business rules.
''',
      );
      expect(await File(result.nojekyllPath).readAsBytes(), isEmpty);
      final relativePaths = result.writtenFiles
          .map((record) => record.relativePath)
          .toList();
      expect(relativePaths, orderedEquals(<String>[...relativePaths]..sort()));
      expect(relativePaths, contains('.nojekyll'));
      expect(relativePaths, contains('PUBLISH_INSTRUCTIONS.md'));
      expect(
        relativePaths,
        contains('artifacts/weather/2.3.4/screens/weather_home.json'),
      );
      expect(
        () => result.writtenFiles.add(
          const StaticPublishedFileRecord(
            relativePath: 'extra',
            localSourcePath: 'extra',
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('static clean containment failure keeps its exact message', () async {
      final outputPath = p.normalize(
        p.absolute(p.join(tempDirectory.path, 'public')),
      );
      final escapedPath = p.normalize(p.absolute(outputPath));

      await expectLater(
        () =>
            MiniProgramStaticPublisher(
              builder: const _PublishingThrowingBuilder(),
            ).publish(
              MiniProgramStaticPublishRequest(
                repoRootPath: tempDirectory.path,
                outputPath: outputPath,
                miniProgramId: '..',
                clean: true,
              ),
            ),
        throwsA(
          isA<MiniProgramPublishException>().having(
            (error) => error.message,
            'message',
            'Static publish target escaped output root: $escapedPath',
          ),
        ),
      );
    });

    test('legacy result JSON keeps its stable property order', () {
      const buildResult = MiniProgramBuildResult(
        repoRootPath: 'repo',
        miniProgramRootPath: 'mini_program',
        miniProgramId: 'weather',
        outputDirectoryPath: 'build',
        screensDirectoryPath: 'build/screens',
        entryScreenJsonPath: 'build/screens/home.json',
        cliSource: 'test',
        invocation: <String>['dart', 'test'],
        pubGetRan: false,
      );
      const validation = DeliveryValidationReport(
        repoRootPath: 'repo',
        messages: <DeliveryValidationMessage>[],
      );
      const result = MiniProgramPublishResult(
        repoRootPath: 'repo',
        backendRootPath: 'backend',
        miniProgramId: 'weather',
        version: '2.3.4',
        buildResult: buildResult,
        prePublishValidation: validation,
        postPublishValidation: validation,
        latestManifestPath: 'latest.json',
        versionedManifestPath: '2.3.4/manifest.json',
        screensDirectoryPath: '2.3.4/screens',
        copiedScreenCount: 2,
      );

      expect(result.toJson().keys.toList(), <String>[
        'repoRootPath',
        'backendRootPath',
        'miniProgramId',
        'version',
        'buildResult',
        'prePublishValidation',
        'postPublishValidation',
        'latestManifestPath',
        'versionedManifestPath',
        'screensDirectoryPath',
        'copiedScreenCount',
      ]);
    });

    test('missing legacy workspace keeps its exact failure', () async {
      final repoRoot = p.normalize(p.absolute(tempDirectory.path));
      final expectedApiPath = p.join(repoRoot, 'backend', 'api');

      await expectLater(
        () => const MiniProgramPublisher().publish(
          MiniProgramPublishRequest(repoRootPath: repoRoot),
        ),
        throwsA(
          isA<MiniProgramPublishException>().having(
            (error) => error.message,
            'message',
            'Artifact workspace API root does not exist: $expectedApiPath',
          ),
        ),
      );
    });
  });
}

class _PublishingFakeBuilder extends MiniProgramBuilder {
  const _PublishingFakeBuilder(this.result);

  final MiniProgramBuildResult result;

  @override
  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) async =>
      result;
}

class _PublishingThrowingBuilder extends MiniProgramBuilder {
  const _PublishingThrowingBuilder();

  @override
  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) =>
      throw StateError('builder must not run');
}
