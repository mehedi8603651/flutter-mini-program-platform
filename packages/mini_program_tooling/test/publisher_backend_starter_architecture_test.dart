import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('Publisher backend implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'publisher_backend'),
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
        'dependencies.dart',
        'generated_files.dart',
        'generated_files/mock_templates.dart',
        'health.dart',
        'launcher.dart',
        'lifecycle.dart',
        'models.dart',
        'process_control.dart',
        'state_store.dart',
        'urls.dart',
        'workspace.dart',
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
        isNot(contains('publisher_backend_starter.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/publisher_backend/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'publisher_backend_starter.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(100));
    expect(facadeSource, contains('class PublisherBackendStarter'));
    expect(facadeSource, contains('PublisherBackendLifecycle'));
    expect(facadeSource, contains('PublisherBackendWorkspace'));
    expect(facadeSource, isNot(contains('Process.run')));
    expect(facadeSource, isNot(contains('Process.start')));
    expect(facadeSource, isNot(contains('File(')));
    expect(facadeSource, isNot(contains('Platform.')));
  });
}
