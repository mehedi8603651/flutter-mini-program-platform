import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramPathResolver', () {
    late Directory tempDir;
    late Directory repoRoot;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_path_resolver_',
      );
      repoRoot = Directory(p.join(tempDir.path, 'repo'));
      await Directory(
        p.join(repoRoot.path, 'mini_programs', 'coupon_center'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'backend', 'api'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'packages', 'mini_program_tooling'),
      ).create(recursive: true);
      await File(
        p.join(repoRoot.path, 'packages', 'mini_program_tooling', 'pubspec.yaml'),
      ).writeAsString('name: mini_program_tooling');
      await File(
        p.join(repoRoot.path, 'mini_programs', 'coupon_center', 'manifest.json'),
      ).writeAsString('{"id":"coupon_center"}');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves repo-managed mini-program when repo root is known', () async {
      final result = await const MiniProgramPathResolver().resolve(
        miniProgramId: 'coupon_center',
        repoRootPath: repoRoot.path,
      );

      expect(result.repoRootPath, repoRoot.path);
      expect(
        result.miniProgramRootPath,
        p.join(repoRoot.path, 'mini_programs', 'coupon_center'),
      );
      expect(result.isRepoManaged, isTrue);
    });

    test('resolves standalone ./<id> when working outside the repo', () async {
      final standaloneRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await standaloneRoot.create(recursive: true);
      await File(p.join(standaloneRoot.path, 'manifest.json')).writeAsString(
        '{"id":"coupon_center"}',
      );

      final result = await const MiniProgramPathResolver().resolve(
        miniProgramId: 'coupon_center',
        currentWorkingDirectory: tempDir.path,
      );

      expect(result.repoRootPath, isNull);
      expect(result.miniProgramRootPath, standaloneRoot.path);
      expect(result.isRepoManaged, isFalse);
    });

    test('infers the mini-program id from the current working directory', () async {
      final standaloneRoot = Directory(p.join(tempDir.path, 'coupon_center'));
      await standaloneRoot.create(recursive: true);
      await File(p.join(standaloneRoot.path, 'manifest.json')).writeAsString(
        '{"id":"coupon_center"}',
      );

      final inferredId = await const MiniProgramPathResolver().inferMiniProgramId(
        currentWorkingDirectory: standaloneRoot.path,
      );

      expect(inferredId, 'coupon_center');
    });

    test('discovers repo root from a nested working directory', () async {
      final nestedDir = Directory(
        p.join(repoRoot.path, 'hosts', 'super_app_host', 'lib'),
      );
      await nestedDir.create(recursive: true);

      final repoRootPath = await const MiniProgramPathResolver().resolveRepoRoot(
        currentWorkingDirectory: nestedDir.path,
        required: true,
      );

      expect(repoRootPath, repoRoot.path);
    });
  });
}
