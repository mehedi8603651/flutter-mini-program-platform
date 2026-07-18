import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('doctor implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'doctor'),
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
        'backend_checks.dart',
        'command_probes.dart',
        'coordinator.dart',
        'dependencies.dart',
        'models.dart',
        'repository_checks.dart',
        'workspace_checks.dart',
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
        isNot(contains('miniprogram_doctor.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/doctor/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'miniprogram_doctor.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(60));
    expect(facadeSource, contains('class MiniprogramDoctor'));
    expect(facadeSource, contains('diagnoseMiniprogramEnvironment'));
    expect(facadeSource, isNot(contains('Process.run')));
    expect(facadeSource, isNot(contains('Directory(')));
    expect(facadeSource, isNot(contains('File(')));
  });
}
