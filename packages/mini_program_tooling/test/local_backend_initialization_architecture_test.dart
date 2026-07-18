import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('local backend initialization stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'local_backend_initialization'),
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
        'models.dart',
        'paths.dart',
        'state_persistence.dart',
        'template_copy.dart',
        'template_discovery.dart',
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
        RegExp(
          r"^\s*import 'package:mini_program_tooling/mini_program_tooling.dart';",
          multiLine: true,
        ).hasMatch(source),
        isFalse,
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('local_backend_initializer.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/local_backend_initialization/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'local_backend_initializer.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(45));
    expect(facadeSource, contains('class LocalBackendInitializer'));
    expect(facadeSource, contains('initializeLocalBackendWorkspace'));
    expect(facadeSource, isNot(contains('Directory(')));
    expect(facadeSource, isNot(contains('File(')));
    expect(facadeSource, isNot(contains('Isolate.')));
  });
}
