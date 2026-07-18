import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('development build implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'build_pipeline'),
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
        'commands.dart',
        'coordinator.dart',
        'data_assets.dart',
        'manifest.dart',
        'models.dart',
        'paths.dart',
        'process.dart',
        'screen_validation.dart',
        'specification.dart',
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
          contains(
            "import 'package:mini_program_tooling/mini_program_tooling.dart'",
          ),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('mini_program_builder.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/build_pipeline/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_builder.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(40));
    expect(facadeSource, contains('class MiniProgramBuilder'));
    expect(facadeSource, contains('buildMiniProgramDevelopmentOutput'));
    expect(facadeSource, isNot(contains('jsonDecode')));
    expect(facadeSource, isNot(contains('Process.run')));
    expect(facadeSource, isNot(contains('File(')));
    expect(facadeSource, isNot(contains('Directory(')));
  });
}
