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
      await Directory(
        p.join(tempDir.path, 'backend', 'api'),
      ).create(recursive: true);
      await Directory(
        p.join(tempDir.path, 'mini_programs'),
      ).create(recursive: true);
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

      final result = await const MiniProgramPublisher().publish(
        MiniProgramPublishRequest(
          repoRootPath: tempDir.path,
          miniProgramRootPath: miniProgramRoot,
          skipBuildPubGet: true,
        ),
      );

      expect(result.version, '1.2.0');
      expect(result.backendRootPath, tempDir.path);
      expect(result.prePublishValidation.hasErrors, isFalse);
      expect(result.postPublishValidation.hasErrors, isFalse);
      expect(result.copiedScreenCount, 1);
      expect(await File(result.latestManifestPath).exists(), isTrue);
      expect(await File(result.versionedManifestPath).exists(), isTrue);
      expect(
        await File(
          p.join(result.screensDirectoryPath, '${miniProgramId}_home.json'),
        ).exists(),
        isTrue,
      );

      final latestManifest =
          jsonDecode(await File(result.latestManifestPath).readAsString())
              as Map<String, dynamic>;
      expect(latestManifest['version'], '1.2.0');
    });

    test('publishes Mp screens from mp build output', () async {
      final scaffold = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'mp_coupon_center',
        ),
      );

      final result = await const MiniProgramPublisher().publish(
        MiniProgramPublishRequest(
          repoRootPath: tempDir.path,
          miniProgramRootPath: scaffold.miniProgramRootPath,
        ),
      );

      expect(result.version, '1.0.0');
      expect(result.buildResult.screenFormat, 'mp');
      expect(result.buildResult.screenSchemaVersion, 1);
      expect(result.buildResult.screensDirectoryPath, contains('mp\\.build'));
      expect(result.screensDirectoryPath, isNot(contains('mp\\.build')));
      expect(result.copiedScreenCount, 2);
      expect(
        await File(
          p.join(result.screensDirectoryPath, 'mp_coupon_center_home.json'),
        ).exists(),
        isTrue,
      );
      final latestManifest =
          jsonDecode(await File(result.latestManifestPath).readAsString())
              as Map<String, dynamic>;
      expect(latestManifest['screenFormat'], 'mp');
      expect(latestManifest['screenSchemaVersion'], 1);
    });

    test(
      'publishes to a standalone artifact workspace when provided',
      () async {
        final miniProgramId = 'coupon_center';
        final repoRoot = p.join(tempDir.path, 'repo_root');
        final backendRoot = p.join(tempDir.path, 'backend_workspace');
        final miniProgramRoot = p.join(
          tempDir.path,
          'standalone_coupon_center',
        );
        await Directory(
          p.join(repoRoot, 'mini_programs'),
        ).create(recursive: true);
        await Directory(
          p.join(backendRoot, 'backend', 'api'),
        ).create(recursive: true);
        await _writeMiniProgramFixture(
          miniProgramRoot,
          miniProgramId: miniProgramId,
          version: '1.2.0',
        );

        final result = await const MiniProgramPublisher().publish(
          MiniProgramPublishRequest(
            repoRootPath: repoRoot,
            backendRootPath: backendRoot,
            miniProgramRootPath: miniProgramRoot,
            skipBuildPubGet: true,
          ),
        );

        expect(result.backendRootPath, backendRoot);
        expect(
          result.latestManifestPath,
          p.join(
            backendRoot,
            'backend',
            'api',
            'artifacts',
            miniProgramId,
            'latest.json',
          ),
        );
        expect(await File(result.latestManifestPath).exists(), isTrue);
        expect(
          await File(
            p.join(
              backendRoot,
              'backend',
              'api',
              'artifacts',
              miniProgramId,
              '1.2.0',
              'screens',
              '${miniProgramId}_home.json',
            ),
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            p.join(
              repoRoot,
              'backend',
              'api',
              'artifacts',
              miniProgramId,
              'latest.json',
            ),
          ).exists(),
          isFalse,
        );
      },
    );

    test(
      'stops before publish when pre-publish validation has errors',
      () async {
        final miniProgramId = 'coupon_center';
        final miniProgramRoot = p.join(
          tempDir.path,
          'standalone_coupon_center',
        );
        await _writeMiniProgramFixture(
          miniProgramRoot,
          miniProgramId: miniProgramId,
          version: '1.2.0',
        );

        final rolloutRulesDir = Directory(
          p.join(tempDir.path, 'backend', 'api', 'rollout-rules'),
        );
        await rolloutRulesDir.create(recursive: true);
        await File(
          p.join(rolloutRulesDir.path, '$miniProgramId.json'),
        ).writeAsString('''
{
  "miniProgramId": "$miniProgramId",
  "defaultVersion": "9.9.9",
  "rules": []
}
''');

        expect(
          () => const MiniProgramPublisher().publish(
            MiniProgramPublishRequest(
              repoRootPath: tempDir.path,
              miniProgramRootPath: miniProgramRoot,
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
              'artifacts',
              miniProgramId,
              'latest.json',
            ),
          ).exists(),
          isFalse,
        );
      },
    );
  });
}

Future<void> _writeMiniProgramFixture(
  String miniProgramRootPath, {
  required String miniProgramId,
  required String version,
}) async {
  await Directory(p.join(miniProgramRootPath, 'tool')).create(recursive: true);

  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "version": "$version",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"],
  "screenFormat": "mp",
  "screenSchemaVersion": 1,
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
    p.join(miniProgramRootPath, 'tool', 'build_mp.dart'),
  ).writeAsString('''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  final output = outputIndex == -1 ? 'mp/.build' : arguments[outputIndex + 1];
  final outputDir = Directory(
    joinPaths(output, 'screens'),
  );
  await outputDir.create(recursive: true);
  await File(joinPaths(outputDir.path, '${miniProgramId}_home.json')).writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'screenId': '${miniProgramId}_home',
      'root': <String, Object?>{
        'type': 'text',
        'props': <String, Object?>{'data': 'Hello'},
      },
    }),
  );
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
''');
}
