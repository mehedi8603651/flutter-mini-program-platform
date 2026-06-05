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
      final miniProgramRoot = p.join(
        repoRoot,
        'mini_programs',
        'coupon_center',
      );
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

      final builder = MiniProgramBuilder(
        managedStacBuilder: const _MissingManagedStacBuilder(),
      );
      final result = await builder.build(
        MiniProgramBuildRequest(
          repoRootPath: repoRoot,
          miniProgramId: 'claim_center',
          skipPubGet: true,
        ),
      );

      expect(result.cliSource, 'vendored_script');
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test(
      'supports a standalone mini-program root with repo-root vendored CLI resolution',
      () async {
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

        final builder = MiniProgramBuilder(
          managedStacBuilder: const _MissingManagedStacBuilder(),
        );
        final result = await builder.build(
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
      },
    );

    test('uses the managed pinned Stac builder by default', () async {
      final standaloneRoot = p.join(tempDir.path, 'standalone_coupon_center');
      await _writeMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'coupon_center',
      );
      final fakeCliPath = p.join(tempDir.path, 'managed_fake_stac_cli.dart');
      await File(fakeCliPath).writeAsString(_fakeStacCliSource);

      final builder = MiniProgramBuilder(
        managedStacBuilder: _FakeManagedStacBuilder(fakeCliPath),
      );
      final result = await builder.build(
        MiniProgramBuildRequest(
          miniProgramRootPath: standaloneRoot,
          skipPubGet: true,
        ),
      );

      expect(result.cliSource, 'managed_pinned_stac');
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test('builds Mp screens with tool/build_mp.dart', () async {
      final standaloneRoot = p.join(tempDir.path, 'mp_coupon_center');
      await _writeMpMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'mp_coupon_center',
      );

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(
          miniProgramRootPath: standaloneRoot,
          skipPubGet: true,
        ),
      );

      expect(result.screenFormat, 'mp');
      expect(result.screenSchemaVersion, 1);
      expect(result.cliSource, 'mp_build_script');
      expect(
        result.screensDirectoryPath,
        p.join(standaloneRoot, 'mp', '.build', 'screens'),
      );
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test('builds Mp screens with an explicit build script path', () async {
      final standaloneRoot = p.join(tempDir.path, 'mp_claim_center');
      await _writeMpMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'mp_claim_center',
      );
      final explicitScript = p.join(tempDir.path, 'custom_build_mp.dart');
      await File(explicitScript).writeAsString(
        _fakeMpBuildScriptSource.replaceAll(
          '%%SCREEN_ID%%',
          'mp_claim_center_home',
        ),
      );

      final result = await const MiniProgramBuilder().build(
        MiniProgramBuildRequest(
          miniProgramRootPath: standaloneRoot,
          mpBuildScriptPath: explicitScript,
          skipPubGet: true,
        ),
      );

      expect(result.cliSource, 'explicit_mp_build_script');
      expect(await File(result.entryScreenJsonPath).exists(), isTrue);
    });

    test('rejects Mp manifests without screenSchemaVersion', () async {
      final standaloneRoot = p.join(tempDir.path, 'mp_bad_schema');
      await _writeMpMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'mp_bad_schema',
        includeSchemaVersion: false,
      );

      expect(
        () => const MiniProgramBuilder().build(
          MiniProgramBuildRequest(
            miniProgramRootPath: standaloneRoot,
            skipPubGet: true,
          ),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });

    test('rejects Mp builds whose entry screen id does not match', () async {
      final standaloneRoot = p.join(tempDir.path, 'mp_bad_entry');
      await _writeMpMiniProgramFixture(
        standaloneRoot,
        miniProgramId: 'mp_bad_entry',
        outputScreenId: 'wrong_home',
      );

      expect(
        () => const MiniProgramBuilder().build(
          MiniProgramBuildRequest(
            miniProgramRootPath: standaloneRoot,
            skipPubGet: true,
          ),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });

    test('rejects unsupported screen formats', () async {
      final standaloneRoot = p.join(tempDir.path, 'future_screen');
      await _writeUnsupportedFormatMiniProgramFixture(standaloneRoot);

      expect(
        () => const MiniProgramBuilder().build(
          MiniProgramBuildRequest(
            miniProgramRootPath: standaloneRoot,
            skipPubGet: true,
          ),
        ),
        throwsA(isA<MiniProgramBuildException>()),
      );
    });

    test('fails when no Stac CLI can be resolved', () async {
      final repoRoot = tempDir.path;
      final miniProgramRoot = p.join(repoRoot, 'mini_programs', 'claim_center');
      await _writeMiniProgramFixture(
        miniProgramRoot,
        miniProgramId: 'claim_center',
      );

      final builder = MiniProgramBuilder(
        managedStacBuilder: const _MissingManagedStacBuilder(),
        processRunner:
            (
              String executable,
              List<String> arguments, {
              String? workingDirectory,
              Map<String, String>? environment,
            }) async => ProcessResult(1, 1, '', 'not found'),
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
  await Directory(
    p.join(miniProgramRootPath, 'stac', 'screens'),
  ).create(recursive: true);
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

Future<void> _writeMpMiniProgramFixture(
  String miniProgramRootPath, {
  required String miniProgramId,
  bool includeSchemaVersion = true,
  String? outputScreenId,
}) async {
  await Directory(p.join(miniProgramRootPath, 'tool')).create(recursive: true);
  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "$miniProgramId",
  "version": "1.0.0",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=0.4.0 <0.5.0",
  "requiredCapabilities": ["analytics"],
  "screenFormat": "mp"${includeSchemaVersion ? ',\n  "screenSchemaVersion": 1' : ''}
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
  ).writeAsString(
    _fakeMpBuildScriptSource.replaceAll(
      '%%SCREEN_ID%%',
      outputScreenId ?? '${miniProgramId}_home',
    ),
  );
}

Future<void> _writeUnsupportedFormatMiniProgramFixture(
  String miniProgramRootPath,
) async {
  await Directory(miniProgramRootPath).create(recursive: true);
  await File(p.join(miniProgramRootPath, 'manifest.json')).writeAsString('''
{
  "id": "future_screen",
  "version": "1.0.0",
  "entry": "future_screen_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=0.4.0 <0.5.0",
  "requiredCapabilities": ["analytics"],
  "screenFormat": "future",
  "screenSchemaVersion": 1
}
''');
}

const String _fakeMpBuildScriptSource = r'''
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final outputIndex = arguments.indexOf('--output');
  if (outputIndex == -1 || outputIndex == arguments.length - 1) {
    stderr.writeln('missing --output');
    exitCode = 1;
    return;
  }

  final outputDirectory = arguments[outputIndex + 1];
  final screensDirectory = Directory(joinPaths(outputDirectory, 'screens'));
  await screensDirectory.create(recursive: true);
  final screen = <String, Object?>{
    'schemaVersion': 1,
    'screenId': '%%SCREEN_ID%%',
    'root': <String, Object?>{
      'type': 'text',
      'props': <String, Object?>{'data': 'Hello'},
      'children': <Object?>[],
    },
  };
  await File(
    joinPaths(screensDirectory.path, '%%SCREEN_ID%%.json'),
  ).writeAsString(jsonEncode(screen));
}

String joinPaths(String first, String second) {
  return <String>[first, second].join(Platform.pathSeparator);
}
''';

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

class _FakeManagedStacBuilder extends ManagedStacBuilder {
  const _FakeManagedStacBuilder(this.entrypointPath);

  final String entrypointPath;

  @override
  Future<ManagedStacBuilderStatus> inspect() async {
    return const ManagedStacBuilderStatus(
      pinnedVersion: ManagedStacBuilder.pinnedVersion,
      templateRootPath: 'template',
      cacheRootPath: 'cache',
      bundledTemplateAvailable: true,
      cachePrepared: true,
      dependenciesResolved: true,
    );
  }

  @override
  Future<ManagedStacBuilderResolution> ensureReady() async {
    return ManagedStacBuilderResolution(
      pinnedVersion: ManagedStacBuilder.pinnedVersion,
      packageRootPath: p.dirname(entrypointPath),
      entrypointPath: entrypointPath,
    );
  }
}

class _MissingManagedStacBuilder extends ManagedStacBuilder {
  const _MissingManagedStacBuilder();

  @override
  Future<ManagedStacBuilderStatus> inspect() async {
    return const ManagedStacBuilderStatus(
      pinnedVersion: ManagedStacBuilder.pinnedVersion,
      templateRootPath: null,
      cacheRootPath: 'cache',
      bundledTemplateAvailable: false,
      cachePrepared: false,
      dependenciesResolved: false,
    );
  }
}
