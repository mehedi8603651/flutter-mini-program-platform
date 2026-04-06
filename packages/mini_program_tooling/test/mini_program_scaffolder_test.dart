import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramScaffolder', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_scaffold_',
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

    test('creates a buildable starter scaffold with default capabilities', () async {
      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'coupon_center',
        ),
      );

      final miniProgramRoot = p.join(tempDir.path, 'mini_programs', 'coupon_center');
      final manifest = jsonDecode(
        await File(p.join(miniProgramRoot, 'manifest.json')).readAsString(),
      ) as Map<String, dynamic>;
      final screenFile = File(
        p.join(miniProgramRoot, 'stac', 'screens', 'coupon_center_home.dart'),
      );
      final helperFile = File(
        p.join(miniProgramRoot, 'lib', 'host_action_helpers.dart'),
      );

      expect(result.miniProgramId, 'coupon_center');
      expect(manifest['entry'], 'coupon_center_home');
      expect(
        manifest['requiredCapabilities'],
        <String>['analytics', 'native_navigation'],
      );
      expect(
        (manifest['cachePolicy'] as Map<String, dynamic>)['manifest']
            as Map<String, dynamic>,
        containsPair('mode', 'staleWhileError'),
      );

      final screenSource = await screenFile.readAsString();
      final helperSource = await helperFile.readAsString();
      expect(screenSource, contains("@StacScreen(screenName: 'coupon_center_home')"));
      expect(
        screenSource,
        contains(
          "import 'package:coupon_center_mini_program/host_action_helpers.dart';",
        ),
      );
      expect(screenSource, contains('hostTrackEventAction('));
      expect(screenSource, contains('Track starter event (logs only)'));
      expect(screenSource, contains('hostOpenNativeScreenAction('));
      expect(screenSource, contains('Open sample native screen'));
      expect(screenSource, isNot(contains('jsonData:')));
      expect(screenSource, isNot(contains('hostCallSecureApiAction(')));
      expect(helperSource, contains('StacAction hostTrackEventAction('));
      expect(helperSource, contains("'action': 'trackEvent'"));
      expect(helperSource, contains('StacAction hostOpenNativeScreenAction('));
      expect(helperSource, contains("'action': 'openNativeScreen'"));
      expect(helperSource, contains("'route': route"));
      expect(helperSource, contains('StacAction hostCallSecureApiAction('));
      expect(helperSource, contains("'action': 'callSecureApi'"));

      expect(
        await File(p.join(miniProgramRoot, 'pubspec.yaml')).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(miniProgramRoot, 'lib', 'default_stac_options.dart'),
        ).exists(),
        isTrue,
      );
      expect(await helperFile.exists(), isTrue);
      expect(result.createdPaths, isNotEmpty);
    });

    test('uses noCache and secure API starter action when secure_api is requested', () async {
      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'claim_center',
          capabilities: const <String>{'analytics', 'secure_api'},
        ),
      );

      final manifest = jsonDecode(
        await File(
          p.join(result.miniProgramRootPath, 'manifest.json'),
        ).readAsString(),
      ) as Map<String, dynamic>;
      final screenSource = await File(
        p.join(result.miniProgramRootPath, 'stac', 'screens', 'claim_center_home.dart'),
      ).readAsString();
      final helperSource = await File(
        p.join(result.miniProgramRootPath, 'lib', 'host_action_helpers.dart'),
      ).readAsString();

      expect(
        manifest['requiredCapabilities'],
        <String>['analytics', 'secure_api'],
      );
      expect(
        (manifest['cachePolicy'] as Map<String, dynamic>)['manifest']
            as Map<String, dynamic>,
        containsPair('mode', 'noCache'),
      );
      expect(screenSource, contains('hostCallSecureApiAction('));
      expect(screenSource, isNot(contains('hostOpenNativeScreenAction(')));
      expect(helperSource, contains("'action': 'callSecureApi'"));
    });

    test('supports standalone output root outside repo mini_programs', () async {
      final standaloneRoot = p.join(tempDir.path, 'standalone_coupon_center');

      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          miniProgramId: 'coupon_center',
          outputRootPath: standaloneRoot,
        ),
      );

      expect(result.repoRootPath, isNull);
      expect(result.miniProgramRootPath, standaloneRoot);
      expect(await File(p.join(standaloneRoot, 'manifest.json')).exists(), isTrue);

      final readme = await File(p.join(standaloneRoot, 'README.md')).readAsString();
      expect(readme, contains('-MiniProgramRoot <mini-program-root> -RepoRoot <repo-root>'));
    });

    test('fails on unknown capability values', () async {
      expect(
        () => const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: tempDir.path,
            miniProgramId: 'broken_program',
            capabilities: <String>{'analytics', 'camera'},
          ),
        ),
        throwsA(isA<MiniProgramScaffoldException>()),
      );
    });

    test('fails when target exists and force is false', () async {
      final targetDir = Directory(
        p.join(tempDir.path, 'mini_programs', 'coupon_center'),
      );
      await targetDir.create(recursive: true);
      await File(p.join(targetDir.path, 'manifest.json')).writeAsString('{}');

      expect(
        () => const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: tempDir.path,
            miniProgramId: 'coupon_center',
          ),
        ),
        throwsA(isA<MiniProgramScaffoldException>()),
      );
    });

    test('overwrites scaffold-managed files when force is true', () async {
      final targetDir = Directory(
        p.join(tempDir.path, 'mini_programs', 'coupon_center'),
      );
      await targetDir.create(recursive: true);
      await File(p.join(targetDir.path, 'manifest.json')).writeAsString('{}');

      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'coupon_center',
          force: true,
        ),
      );

      final manifestSource = await File(
        p.join(targetDir.path, 'manifest.json'),
      ).readAsString();

      expect(result.miniProgramId, 'coupon_center');
      expect(manifestSource, contains('"id": "coupon_center"'));
    });
  });
}
