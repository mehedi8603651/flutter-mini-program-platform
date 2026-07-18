import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('path resolution parity', () {
    late Directory tempDirectory;
    late Directory repoRoot;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mini_program_path_parity_',
      );
      repoRoot = Directory(p.join(tempDirectory.path, 'repo'));
      await Directory(
        p.join(repoRoot.path, 'mini_programs'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'backend', 'api'),
      ).create(recursive: true);
      await Directory(
        p.join(repoRoot.path, 'packages', 'mini_program_tooling'),
      ).create(recursive: true);
      await File(
        p.join(
          repoRoot.path,
          'packages',
          'mini_program_tooling',
          'pubspec.yaml',
        ),
      ).writeAsString('name: mini_program_tooling');
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'explicit mini-program root wins over repo and current roots',
      () async {
        final explicitRoot = await _writeMiniProgram(
          p.join(tempDirectory.path, 'explicit'),
          'calculator',
        );
        await _writeMiniProgram(
          p.join(repoRoot.path, 'mini_programs', 'calculator'),
          'calculator',
        );
        final currentRoot = await _writeMiniProgram(
          p.join(tempDirectory.path, 'current'),
          'calculator',
        );

        final result = await const MiniProgramPathResolver().resolve(
          miniProgramId: 'calculator',
          miniProgramRootPath: explicitRoot.path,
          repoRootPath: repoRoot.path,
          currentWorkingDirectory: currentRoot.path,
        );

        expect(result.miniProgramRootPath, explicitRoot.path);
        expect(result.checkedPaths, <String>[
          '--mini-program-root: ${explicitRoot.path}',
        ]);
      },
    );

    test('invalid explicit mini-program root fails without fallback', () async {
      final explicitRoot = Directory(p.join(tempDirectory.path, 'explicit'));
      await explicitRoot.create(recursive: true);
      final currentRoot = await _writeMiniProgram(
        p.join(tempDirectory.path, 'current'),
        'calculator',
      );

      expect(
        () => const MiniProgramPathResolver().resolve(
          miniProgramId: 'calculator',
          miniProgramRootPath: explicitRoot.path,
          currentWorkingDirectory: currentRoot.path,
        ),
        throwsA(
          isA<MiniProgramPathResolutionException>().having(
            (error) => error.message,
            'message',
            'No usable manifest.json matching "calculator" was found under '
                '${explicitRoot.path}.',
          ),
        ),
      );
    });

    test('unresolved error preserves candidate order and text', () async {
      final currentRoot = Directory(p.join(tempDirectory.path, 'current'));
      await currentRoot.create(recursive: true);
      final repoCandidate = p.join(
        repoRoot.path,
        'mini_programs',
        'missing_app',
      );
      final nestedCandidate = p.join(currentRoot.path, 'missing_app');

      expect(
        () => const MiniProgramPathResolver().resolve(
          miniProgramId: 'missing_app',
          repoRootPath: repoRoot.path,
          currentWorkingDirectory: currentRoot.path,
        ),
        throwsA(
          isA<MiniProgramPathResolutionException>().having(
            (error) => error.message,
            'message',
            'Could not resolve mini-program "missing_app". Checked:\n'
                '- --repo-root + mini_programs/<id>: $repoCandidate\n'
                '- current directory: ${currentRoot.path}\n'
                '- ./<id>: $nestedCandidate',
          ),
        ),
      );
    });

    test('invalid explicit repo root preserves the stable error', () async {
      final invalidRoot = Directory(p.join(tempDirectory.path, 'invalid'));
      await invalidRoot.create(recursive: true);

      expect(
        () => const MiniProgramPathResolver().resolveRepoRoot(
          explicitRepoRootPath: invalidRoot.path,
        ),
        throwsA(
          isA<MiniProgramPathResolutionException>().having(
            (error) => error.message,
            'message',
            'Repo root does not look like the platform repository: '
                '${invalidRoot.path}',
          ),
        ),
      );
    });
  });
}

Future<Directory> _writeMiniProgram(String rootPath, String appId) async {
  final root = Directory(rootPath);
  await root.create(recursive: true);
  await File(
    p.join(root.path, 'manifest.json'),
  ).writeAsString('{"id":"$appId"}');
  return root;
}
