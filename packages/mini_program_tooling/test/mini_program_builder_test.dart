import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramBuilder', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_builder_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('builds Mp screens with tool/build_mp.dart', () async {
      final root = p.join(tempDir.path, 'mp_coupon_center');
      await _writeMpMiniProgramFixture(root, miniProgramId: 'mp_coupon_center');

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(miniProgramRootPath: root, skipPubGet: true),
      );

      expect(result.screenFormat, 'mp');
      expect(result.screenSchemaVersion, 1);
      expect(result.cliSource, 'mp_build_script');
      expect(
        result.screensDirectoryPath,
        p.join(root, 'mp', '.build', 'screens'),
      );
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
      final json = jsonDecode(
        await File(result.entryScreenJsonPath).readAsString(),
      );
      expect(json['screenId'], 'mp_coupon_center_home');
    });

    test(
      'builds Mp screens from repo-managed mini_programs directory',
      () async {
        final repoRoot = tempDir.path;
        final root = p.join(repoRoot, 'mini_programs', 'claim_center');
        await _writeMpMiniProgramFixture(root, miniProgramId: 'claim_center');

        final result = await const MiniProgramBuilder().build(
          MiniProgramBuildRequest(
            repoRootPath: repoRoot,
            miniProgramId: 'claim_center',
            skipPubGet: true,
          ),
        );

        expect(result.miniProgramRootPath, root);
        expect(result.miniProgramId, 'claim_center');
        expect(await File(result.entryScreenJsonPath).exists(), isTrue);
      },
    );

    test('builds Mp screens with an explicit build script path', () async {
      final root = p.join(tempDir.path, 'mp_claim_center');
      await _writeMpMiniProgramFixture(root, miniProgramId: 'mp_claim_center');
      final explicitScript = p.join(tempDir.path, 'custom_build_mp.dart');
      await File(explicitScript).writeAsString(
        _fakeMpBuildScriptSource(screenId: 'mp_claim_center_home'),
      );

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(
          miniProgramRootPath: root,
          mpBuildScriptPath: explicitScript,
          skipPubGet: true,
        ),
      );

      expect(result.cliSource, 'explicit_mp_build_script');
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test('rejects unsupported screen formats', () async {
      final root = p.join(tempDir.path, 'legacy_flow');
      await _writeMpMiniProgramFixture(
        root,
        miniProgramId: 'legacy_flow',
        screenFormat: 'unsupported',
      );

      await expectLater(
        const MiniProgramBuilder().build(
          MiniProgramBuildRequest(miniProgramRootPath: root, skipPubGet: true),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });

    test('rejects missing Mp build script', () async {
      final root = p.join(tempDir.path, 'missing_script');
      await _writeMpMiniProgramFixture(root, miniProgramId: 'missing_script');
      await File(p.join(root, 'tool', 'build_mp.dart')).delete();

      await expectLater(
        const MiniProgramBuilder().build(
          MiniProgramBuildRequest(miniProgramRootPath: root, skipPubGet: true),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });

    test('rejects Mp builds whose entry screen id does not match', () async {
      final root = p.join(tempDir.path, 'bad_entry');
      await _writeMpMiniProgramFixture(
        root,
        miniProgramId: 'bad_entry',
        generatedScreenId: 'wrong_home',
      );

      await expectLater(
        const MiniProgramBuilder().build(
          MiniProgramBuildRequest(miniProgramRootPath: root, skipPubGet: true),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });

    test('validates statically referenced JSON data assets', () async {
      final root = p.join(tempDir.path, 'weather');
      await _writeMpMiniProgramFixture(
        root,
        miniProgramId: 'weather',
        jsonAsset: 'data/locations.json',
      );
      await Directory(p.join(root, 'assets', 'data')).create(recursive: true);
      await File(
        p.join(root, 'assets', 'data', 'locations.json'),
      ).writeAsString(
        jsonEncode(<String, Object?>{
          'locations': <Object?>[
            <String, Object?>{'name': 'Dhaka'},
          ],
        }),
      );

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(miniProgramRootPath: root, skipPubGet: true),
      );
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test('rejects missing and malformed referenced JSON data assets', () async {
      final missingRoot = p.join(tempDir.path, 'missing_data');
      await _writeMpMiniProgramFixture(
        missingRoot,
        miniProgramId: 'missing_data',
        jsonAsset: 'data/locations.json',
      );
      await expectLater(
        const MiniProgramBuilder().build(
          MiniProgramBuildRequest(
            miniProgramRootPath: missingRoot,
            skipPubGet: true,
          ),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );

      final malformedRoot = p.join(tempDir.path, 'malformed_data');
      await _writeMpMiniProgramFixture(
        malformedRoot,
        miniProgramId: 'malformed_data',
        jsonAsset: 'data/locations.json',
      );
      await Directory(
        p.join(malformedRoot, 'assets', 'data'),
      ).create(recursive: true);
      await File(
        p.join(malformedRoot, 'assets', 'data', 'locations.json'),
      ).writeAsString('{');
      await expectLater(
        const MiniProgramBuilder().build(
          MiniProgramBuildRequest(
            miniProgramRootPath: malformedRoot,
            skipPubGet: true,
          ),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });
  });
}

Future<void> _writeMpMiniProgramFixture(
  String root, {
  required String miniProgramId,
  String screenFormat = 'mp',
  String? generatedScreenId,
  String? jsonAsset,
}) async {
  await Directory(p.join(root, 'tool')).create(recursive: true);
  await File(p.join(root, 'pubspec.yaml')).writeAsString('''
name: ${miniProgramId}_mini_program
publish_to: none
version: 0.1.0
environment:
  sdk: ^3.10.0
''');
  await File(p.join(root, 'manifest.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'id': miniProgramId,
      'version': '1.0.0',
      'entry': '${miniProgramId}_home',
      'contractVersion': '1.0.0',
      'sdkVersionRange': '>=1.0.0 <2.0.0',
      'requiredCapabilities': <String>['analytics'],
      'screenFormat': screenFormat,
      'screenSchemaVersion': 1,
    }),
  );
  await File(p.join(root, 'tool', 'build_mp.dart')).writeAsString(
    _fakeMpBuildScriptSource(
      screenId: generatedScreenId ?? '${miniProgramId}_home',
      jsonAsset: jsonAsset,
    ),
  );
}

String _fakeMpBuildScriptSource({
  required String screenId,
  String? jsonAsset,
}) =>
    '''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  final output = outputIndex == -1 ? 'mp/.build' : arguments[outputIndex + 1];
  final screenDirectory = Directory('\$output/screens');
  await screenDirectory.create(recursive: true);
  await File('\$output/screens/$screenId.json').writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'screenId': '$screenId',
      'root': <String, Object?>{
        'type': '${jsonAsset == null ? 'text' : 'button'}',
        'props': <String, Object?>{
          ${jsonAsset == null ? "'data': 'Hello'," : "'label': 'Load', 'action': <String, Object?>{'type': 'data.loadJsonAsset', 'props': <String, Object?>{'id': 'locations', 'asset': '$jsonAsset', 'ttlMs': 1000, 'forceRefresh': false}},"}
        },
        'children': <Object?>[],
      },
    }),
  );
}
''';
