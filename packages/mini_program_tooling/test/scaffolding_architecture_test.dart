import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('scaffolding implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'scaffolding'),
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
        'coordinator.dart',
        'dependencies.dart',
        'managed_files.dart',
        'models.dart',
        'paths.dart',
        'templates/dart_sources.dart',
        'templates/manifest.dart',
        'templates/project_files.dart',
        'validation.dart',
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
        isNot(contains('mini_program_scaffolder.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/scaffolding/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_scaffolder.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(40));
    expect(facadeSource, contains('class MiniProgramScaffolder'));
    expect(facadeSource, contains('scaffoldMiniProgram(request)'));
    expect(facadeSource, isNot(contains('JsonEncoder')));
    expect(facadeSource, isNot(contains('File(')));
    expect(facadeSource, isNot(contains('Directory(')));
    expect(facadeSource, isNot(contains('MpProgram(')));

    final dependencySource = File(
      path.join(implementationRoot.path, 'dependencies.dart'),
    ).readAsStringSync();
    expect(dependencySource, contains('mini_program_ui: ^0.2.0'));
  });
}
