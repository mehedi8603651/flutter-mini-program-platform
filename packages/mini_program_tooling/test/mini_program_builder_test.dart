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

    test('builds with an explicit Stac CLI script path', () async {
      final repoRoot = tempDir.path;
      final miniProgramRoot = p.join(repoRoot, 'mini_programs', 'coupon_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'coupon_center',
      );
      final fakeCliPath = p.join(repoRoot, 'fake_stac_cli.dart');
      await File(fakeCliPath).writeAsString(_fakeStacCliSource);

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(
          repoRootPath: repoRoot,
          miniProgramId: 'coupon_center',
          stacCliScriptPath: fakeCliPath,
          skipPubGet: true,
        ),
      );

      expect(result.cliSource, 'explicit_script');
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
      expect(result.pubGetRan, isFalse);
    });

    test('falls back to the vendored stac-dev CLI path', () async {
      final repoRoot = tempDir.path;
      final miniProgramRoot = p.join(repoRoot, 'mini_programs', 'claim_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'claim_center',
      );

      final vendoredCliPath = p.join(
        repoRoot,
        'stac-dev',
        'packages',
        'stac_cli',
        'bin',
        'stac_cli.dart',
      );
      await Directory(p.dirname(vendoredCliPath)).create(recursive: true);
      await File(vendoredCliPath).writeAsString(_fakeStacCliSource);

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(
          repoRootPath: repoRoot,
          miniProgramId: 'claim_center',
          skipPubGet: true,
        ),
      );

      expect(result.cliSource, 'vendored_script');
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test('supports a standalone mini-program root with repo-root vendored CLI resolution', () async {
      final repoRoot = tempDir.path;
      final standaloneRoot = p.join(tempDir.path, 'standalone_claim_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'claim_center',
      );

      final vendoredCliPath = p.join(
        repoRoot,
        'stac-dev',
        'packages',
        'stac_cli',
        'bin',
        'stac_cli.dart',
      );
      await Directory(p.dirname(vendoredCliPath)).create(recursive: true);
      await File(vendoredCliPath).writeAsString(_fakeStacCliSource);

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(
          repoRootPath: repoRoot,
          miniProgramRootPath: standaloneRoot,
          skipPubGet: true,
        ),
      );

      expect(result.cliSource, 'vendored_script');
      expect(result.miniProgramRootPath, standaloneRoot);
      expect(result.miniProgramId, 'claim_center');
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test('fails when no Stac CLI can be resolved', () async {
      final repoRoot = tempDir.path;
      final miniProgramRoot = p.join(repoRoot, 'mini_programs', 'claim_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'claim_center',
      );

      final builder = MiniProgramBuilder(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
        }) async =>
            ProcessResult(1, 1, '', 'not found'),
      );

      expect(
        () => builder.build(
          MiniProgramBuildRequest(
            repoRootPath: repoRoot,
            miniProgramId: 'claim_center',
            skipPubGet: true,
          ),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });
  });
}

Future<void> _writeMiniProgramFixture(
  String miniProgramRootPath, {
  required String miniProgramId,
}) async {
  await Directory(p.join(miniProgramRootPath, 'stac', 'screens')).create(
    recursive: true,
  );
  await Directory(p.join(miniProgramRootPath, 'lib')).create(recursive: true);

  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "version": "1.0.0",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"]
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
