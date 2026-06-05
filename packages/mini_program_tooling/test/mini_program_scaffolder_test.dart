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
      await Directory(
        p.join(tempDir.path, 'mini_programs'),
      ).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates an Mp scaffold by default', () async {
      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'mp_coupon_center',
          backendTemplate: 'mock',
        ),
      );

      final root = result.miniProgramRootPath;
      final manifest = await _readManifest(root);
      final pubspec = await File(p.join(root, 'pubspec.yaml')).readAsString();
      final program = await File(
        p.join(root, 'mp', 'program.dart'),
      ).readAsString();
      final home = await File(
        p.join(root, 'mp', 'screens', 'mp_coupon_center_home.dart'),
      ).readAsString();
      final buildScript = await File(
        p.join(root, 'tool', 'build_mp.dart'),
      ).readAsString();
      final gitignore = await File(p.join(root, '.gitignore')).readAsString();

      expect(result.screenFormat, 'mp');
      expect(manifest['screenFormat'], 'mp');
      expect(manifest['screenSchemaVersion'], 1);
      expect(manifest['entry'], 'mp_coupon_center_home');
      expect(manifest['requiredCapabilities'], <String>['analytics']);
      expect(pubspec, contains('mini_program_ui:'));
      expect(program, contains("'mp_coupon_center_home':"));
      expect(program, contains("'mp_coupon_center_details':"));
      expect(buildScript, contains('writeMpBuildOutput(miniProgram'));
      expect(home, contains('Mp.backendBuilder('));
      expect(home, contains("endpoint: 'home/bootstrap'"));
      expect(home, contains('Mp.pagedBackendBuilder('));
      expect(home, contains("endpoint: 'coupons/page'"));
      expect(home, contains('Mp.backend.loadMore('));
      expect(home, contains('Mp.authBuilder('));
      expect(
        home,
        contains("Mp.navigation.openScreen('mp_coupon_center_details')"),
      );
      expect(gitignore, contains('mp/.build/'));
      expect(
        await File(
          p.join(root, 'backend', 'mock', 'data', 'coupons_list.json'),
        ).exists(),
        isTrue,
      );
    });

    test('orders capabilities and uses noCache for secure_api', () async {
      final result = await const MiniProgramScaffolder().scaffold(
        MiniProgramScaffoldRequest(
          repoRootPath: tempDir.path,
          miniProgramId: 'claim_center',
          capabilities: const <String>{
            'secure_api',
            'analytics',
            'native_navigation',
          },
        ),
      );

      final manifest = await _readManifest(result.miniProgramRootPath);
      expect(manifest['requiredCapabilities'], <String>[
        'analytics',
        'secure_api',
        'native_navigation',
      ]);
      expect(
        (manifest['cachePolicy'] as Map<String, dynamic>)['manifest']
            as Map<String, dynamic>,
        containsPair('mode', 'noCache'),
      );
    });

    test(
      'supports standalone output root outside repo mini_programs',
      () async {
        final standaloneRoot = p.join(tempDir.path, 'standalone_coupon_center');

        final result = await const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            miniProgramId: 'coupon_center',
            outputRootPath: standaloneRoot,
          ),
        );

        expect(result.repoRootPath, isNull);
        expect(result.miniProgramRootPath, standaloneRoot);
        expect(
          await File(p.join(standaloneRoot, 'manifest.json')).exists(),
          isTrue,
        );
        expect(
          await File(p.join(standaloneRoot, 'tool', 'build_mp.dart')).exists(),
          isTrue,
        );
      },
    );

    test('fails on non-Mp screen formats', () async {
      expect(
        () => const MiniProgramScaffolder().scaffold(
          MiniProgramScaffoldRequest(
            repoRootPath: tempDir.path,
            miniProgramId: 'legacy_program',
            screenFormat: 'unsupported',
          ),
        ),
        throwsA(isA<MiniProgramScaffoldException>()),
      );
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

      final manifest = await _readManifest(targetDir.path);
      expect(result.miniProgramId, 'coupon_center');
      expect(manifest['id'], 'coupon_center');
      expect(manifest['screenFormat'], 'mp');
    });
  });
}

Future<Map<String, dynamic>> _readManifest(String root) async {
  return jsonDecode(await File(p.join(root, 'manifest.json')).readAsString())
      as Map<String, dynamic>;
}
