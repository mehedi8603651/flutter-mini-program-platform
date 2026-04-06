import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramPublisher', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_publisher_',
      );
      await Directory(p.join(tempDir.path, 'backend', 'api')).create(
        recursive: true,
      );
      await Directory(p.join(tempDir.path, 'mini_programs')).create(
        recursive: true,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('builds, validates, and publishes a mini-program', () async {
      final miniProgramId = 'coupon_center';
      final miniProgramRoot = p.join(tempDir.path, 'standalone_coupon_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: miniProgramId,
        version: '1.2.0',
      );

      final fakeCliPath = p.join(tempDir.path, 'fake_stac_cli.dart');
      await File(fakeCliPath).writeAsString(_fakeStacCliSource);

      final result = await const MiniProgramPublisher().publish(
        MiniProgramPublishRequest(
          repoRootPath: tempDir.path,
          miniProgramRootPath: miniProgramRoot,
          stacCliScriptPath: fakeCliPath,
          skipBuildPubGet: true,
        ),
      );

      expect(result.version, '1.2.0');
      expect(result.prePublishValidation.hasErrors, isFalse);
      expect(result.postPublishValidation.hasErrors, isFalse);
      expect(result.copiedScreenCount, 1);
      expect(await File(result.latestManifestPath).exists(), isTrue);
      expect(await File(result.versionedManifestPath).exists(), isTrue);
      expect(
        await File(
          p.join(
            result.screensDirectoryPath,
            '${miniProgramId}_home.json',
          ),
        ).exists(),
        isTrue,
      );

      final latestManifest = jsonDecode(
        await File(result.latestManifestPath).readAsString(),
      ) as Map<String, dynamic>;
      expect(latestManifest['version'], '1.2.0');
    });

    test('stops before publish when pre-publish validation has errors', () async {
      final miniProgramId = 'coupon_center';
      final miniProgramRoot = p.join(tempDir.path, 'standalone_coupon_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: miniProgramId,
        version: '1.2.0',
      );

      final rolloutRulesDir = Directory(
        p.join(tempDir.path, 'backend', 'api', 'rollout-rules'),
      );
      await rolloutRulesDir.create(recursive: true);
      await File(p.join(rolloutRulesDir.path, '$miniProgramId.json')).writeAsString('''
{
  "miniProgramId": "$miniProgramId",
  "defaultVersion": "9.9.9",
  "rules": []
}
''');

      final fakeCliPath = p.join(tempDir.path, 'fake_stac_cli.dart');
      await File(fakeCliPath).writeAsString(_fakeStacCliSource);

      expect(
        () => const MiniProgramPublisher().publish(
          MiniProgramPublishRequest(
            repoRootPath: tempDir.path,
            miniProgramRootPath: miniProgramRoot,
            stacCliScriptPath: fakeCliPath,
            skipBuildPubGet: true,
          ),
        ),
        throwsA(isA<MiniProgramPublishException>()),
      );

      expect(
        await File(
          p.join(
            tempDir.path,
            'backend',
            'api',
            'manifests',
            miniProgramId,
            'latest.json',
          ),
        ).exists(),
        isFalse,
      );
    });
  });
}

Future<void> _writeMiniProgramFixture(
  String miniProgramRootPath, {
  required String miniProgramId,
  required String version,
}) async {
  await Directory(p.join(miniProgramRootPath, 'stac', 'screens')).create(
    recursive: true,
  );
  await Directory(p.join(miniProgramRootPath, 'lib')).create(recursive: true);

  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "version": "$version",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"],
  "cachePolicy": {
    "manifest": {"mode": "staleWhileError", "maxStaleSeconds": 3600},
    "entryScreen": {"mode": "staleWhileError", "maxStaleSeconds": 1800}
  }
}
''');

  await File(p.join(miniProgramRootPath, 'pubspec.yaml')).writeAsString('''
name: ${miniProgramId}_mini_program
publish_to: none
version: 0.1.0

environment:
  sdk: ^3.10.0
''');

  await File(
    p.join(miniProgramRootPath, 'lib', 'default_stac_options.dart'),
  ).writeAsString('''
import 'package:stac_core/stac_core.dart';

StacOptions get defaultStacOptions => const StacOptions(
  name: '$miniProgramId',
  description: 'Fixture',
  projectId: '${miniProgramId}_local',
  sourceDir: 'stac',
  outputDir: 'stac/.build',
);
''');
}

const String _fakeStacCliSource = r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final projectIndex = arguments.indexOf('--project');
  if (projectIndex == -1 || projectIndex == arguments.length - 1) {
    stderr.writeln('missing --project');
    exitCode = 1;
    return;
  }

  final projectRoot = arguments[projectIndex + 1];
  final manifest = jsonDecode(
    await File(joinPaths(projectRoot, 'manifest.json')).readAsString(),
  ) as Map<String, dynamic>;
  final entry = manifest['entry'] as String;
  final outputDir = Directory(
    joinPaths(projectRoot, 'stac', '.build', 'screens'),
  );
  await outputDir.create(recursive: true);
  await File(joinPaths(outputDir.path, '$entry.json')).writeAsString('{}');
}

String joinPaths(String first, String second, [String? third, String? fourth]) {
  final values = <String>[first, second];
  if (third != null) {
    values.add(third);
  }
  if (fourth != null) {
    values.add(fourth);
  }

  return values.join(Platform.pathSeparator);
}
''';
