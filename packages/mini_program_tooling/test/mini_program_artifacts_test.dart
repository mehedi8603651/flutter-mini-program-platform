import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('portable mini-program artifacts', () {
    late Directory tempDirectory;
    late String miniProgramRoot;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_artifacts_',
      );
      miniProgramRoot = p.join(tempDirectory.path, 'calculator');
      await _writeFixture(miniProgramRoot, version: '1.0.0');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('builds and verifies a deterministic canonical bundle', () async {
      final result = await const MiniProgramArtifactBuilder().build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );

      expect(result.created, isTrue);
      expect(result.latestUpdated, isTrue);
      expect(
        result.versionArtifactsPath,
        p.join(miniProgramRoot, 'artifacts', 'calculator', '1.0.0'),
      );
      expect(
        await File(
          p.join(result.versionArtifactsPath, 'manifest.json'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(
            result.versionArtifactsPath,
            'screens',
            'calculator_home.json',
          ),
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(result.versionArtifactsPath, 'assets', 'keypad.txt'),
        ).readAsString(),
        'asset-data',
      );
      expect(
        await File(
          p.join(
            result.versionArtifactsPath,
            'assets',
            'data',
            'locations.json',
          ),
        ).exists(),
        isTrue,
      );
      final checksums =
          jsonDecode(
                await File(
                  p.join(result.versionArtifactsPath, 'checksums.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(
        (checksums['files'] as List).whereType<Map>().any(
          (record) => record['path'] == 'assets/data/locations.json',
        ),
        isTrue,
      );

      final latest =
          jsonDecode(await File(result.latestManifestPath).readAsString())
              as Map<String, dynamic>;
      expect(latest['artifactLayoutVersion'], 1);
      expect(latest['version'], '1.0.0');
      expect(
        await Directory(p.join(result.appArtifactsPath, '.staging')).exists(),
        isFalse,
      );

      final verified = await const MiniProgramArtifactVerifier().verify(
        MiniProgramArtifactVerifyRequest(miniProgramRootPath: miniProgramRoot),
      );
      expect(verified.latestVersion, '1.0.0');
      expect(verified.versions, <String>['1.0.0']);
      expect(verified.fileCount, greaterThanOrEqualTo(5));
      expect(verified.totalBytes, greaterThan(0));
    });

    test('identical version rebuild is a no-op', () async {
      final builder = const MiniProgramArtifactBuilder();
      final first = await builder.build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );
      final firstChecksums = await File(
        p.join(first.versionArtifactsPath, 'checksums.json'),
      ).readAsString();

      final second = await builder.build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );

      expect(second.created, isFalse);
      expect(second.latestUpdated, isFalse);
      expect(
        await File(
          p.join(second.versionArtifactsPath, 'checksums.json'),
        ).readAsString(),
        firstChecksums,
      );
    });

    test('different content under the same version is rejected', () async {
      final builder = const MiniProgramArtifactBuilder();
      await builder.build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );
      await _writeBuildScript(miniProgramRoot, label: 'Changed');

      await expectLater(
        builder.build(
          MiniProgramArtifactBuildRequest(
            miniProgramRootPath: miniProgramRoot,
            skipPubGet: true,
          ),
        ),
        throwsA(
          isA<MiniProgramArtifactException>().having(
            (error) => error.code,
            'code',
            MiniProgramArtifactErrorCodes.versionConflict,
          ),
        ),
      );
    });

    test('new versions are preserved and latest advances', () async {
      final builder = const MiniProgramArtifactBuilder();
      await builder.build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );
      await _setVersion(miniProgramRoot, '1.1.0');
      await _writeBuildScript(miniProgramRoot, label: 'Version 1.1');
      final second = await builder.build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );

      expect(second.latestUpdated, isTrue);
      final verified = await const MiniProgramArtifactVerifier().verify(
        MiniProgramArtifactVerifyRequest(miniProgramRootPath: miniProgramRoot),
      );
      expect(verified.latestVersion, '1.1.0');
      expect(verified.versions, <String>['1.0.0', '1.1.0']);
    });

    test('building an older version does not move latest backward', () async {
      final builder = const MiniProgramArtifactBuilder();
      await _setVersion(miniProgramRoot, '2.0.0');
      await builder.build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );
      await _setVersion(miniProgramRoot, '1.5.0');
      await _writeBuildScript(miniProgramRoot, label: 'Historical');
      final historical = await builder.build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );

      expect(historical.latestUpdated, isFalse);
      final verified = await const MiniProgramArtifactVerifier().verify(
        MiniProgramArtifactVerifyRequest(miniProgramRootPath: miniProgramRoot),
      );
      expect(verified.latestVersion, '2.0.0');
      expect(verified.versions, <String>['1.5.0', '2.0.0']);
    });

    test('verify rejects changed artifact content', () async {
      final result = await const MiniProgramArtifactBuilder().build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );
      await File(
        p.join(result.versionArtifactsPath, 'screens', 'calculator_home.json'),
      ).writeAsString('{}');

      await expectLater(
        const MiniProgramArtifactVerifier().verify(
          MiniProgramArtifactVerifyRequest(
            miniProgramRootPath: miniProgramRoot,
          ),
        ),
        throwsA(
          isA<MiniProgramArtifactException>().having(
            (error) => error.code,
            'code',
            MiniProgramArtifactErrorCodes.checksumMismatch,
          ),
        ),
      );
    });

    test('verify rejects latest pointing to missing content', () async {
      final result = await const MiniProgramArtifactBuilder().build(
        MiniProgramArtifactBuildRequest(
          miniProgramRootPath: miniProgramRoot,
          skipPubGet: true,
        ),
      );
      final latest =
          jsonDecode(await File(result.latestManifestPath).readAsString())
              as Map<String, dynamic>;
      latest['version'] = '9.0.0';
      await File(result.latestManifestPath).writeAsString(jsonEncode(latest));

      await expectLater(
        const MiniProgramArtifactVerifier().verify(
          MiniProgramArtifactVerifyRequest(
            miniProgramRootPath: miniProgramRoot,
          ),
        ),
        throwsA(
          isA<MiniProgramArtifactException>().having(
            (error) => error.code,
            'code',
            MiniProgramArtifactErrorCodes.latestInvalid,
          ),
        ),
      );
    });
  });
}

Future<void> _writeFixture(String root, {required String version}) async {
  await Directory(p.join(root, 'tool')).create(recursive: true);
  await Directory(p.join(root, 'assets')).create(recursive: true);
  await File(p.join(root, 'assets', 'keypad.txt')).writeAsString('asset-data');
  await Directory(p.join(root, 'assets', 'data')).create(recursive: true);
  await File(p.join(root, 'assets', 'data', 'locations.json')).writeAsString(
    jsonEncode(<String, Object?>{
      'locations': <Object?>[
        <String, Object?>{'name': 'Dhaka'},
      ],
    }),
  );
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: calculator_fixture
publish_to: none
version: 0.1.0
environment:
  sdk: ^3.10.0
''');
  await File(p.join(root, 'manifest.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'id': 'calculator',
      'version': version,
      'entry': 'calculator_home',
      'contractVersion': '1.0.0',
      'sdkVersionRange': '>=1.0.0 <2.0.0',
      'requiredCapabilities': <String>[],
      'screenFormat': 'mp',
      'screenSchemaVersion': 1,
    }),
  );
  await _writeBuildScript(root, label: 'Calculator');
}

Future<void> _setVersion(String root, String version) async {
  final manifestFile = File(p.join(root, 'manifest.json'));
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  manifest['version'] = version;
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
}

Future<void> _writeBuildScript(String root, {required String label}) async {
  await File(p.join(root, 'tool', 'build_mp.dart')).writeAsString('''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  final output = outputIndex == -1 ? 'mp/.build' : arguments[outputIndex + 1];
  final screens = Directory('\$output/screens');
  await screens.create(recursive: true);
  await File('\$output/screens/calculator_home.json').writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'screenId': 'calculator_home',
      'root': <String, Object?>{
        'type': 'button',
        'props': <String, Object?>{
          'label': '$label',
          'action': <String, Object?>{
            'type': 'data.loadJsonAsset',
            'props': <String, Object?>{
              'id': 'locations',
              'asset': 'data/locations.json',
              'ttlMs': 2592000000,
              'forceRefresh': false,
            },
          },
        },
        'children': <Object?>[],
      },
    }),
  );
}
''');
}
