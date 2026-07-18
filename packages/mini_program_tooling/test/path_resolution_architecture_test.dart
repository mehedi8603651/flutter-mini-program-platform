import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('path resolution implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'path_resolution'),
    );
    final implementationFiles =
        implementationRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => path.extension(file.path) == '.dart')
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(
      implementationFiles
          .map(
            (file) => path
                .relative(file.path, from: implementationRoot.path)
                .replaceAll('\\', '/'),
          )
          .toList(),
      <String>[
        'manifest_identity.dart',
        'mini_program_matching.dart',
        'models.dart',
        'normalization.dart',
        'repo_discovery.dart',
        'resolver.dart',
      ],
    );

    for (final file in implementationFiles) {
      final source = file.readAsStringSync();
      expect(
        RegExp(r'^\s*part(?:\s+of)?\s', multiLine: true).hasMatch(source),
        isFalse,
        reason: file.path,
      );
      expect(
        source,
        isNot(
          contains('package:mini_program_tooling/mini_program_tooling.dart'),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('mini_program_path_resolver.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/path_resolution/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_path_resolver.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(60));
    expect(facadeSource, contains('class MiniProgramPathResolver'));
    expect(facadeSource, contains('resolveMiniProgramPaths'));
    expect(facadeSource, contains('resolvePlatformRepoRoot'));
    expect(facadeSource, isNot(contains('jsonDecode')));
    expect(facadeSource, isNot(contains('Directory(')));
    expect(facadeSource, isNot(contains('File(')));
  });
}
