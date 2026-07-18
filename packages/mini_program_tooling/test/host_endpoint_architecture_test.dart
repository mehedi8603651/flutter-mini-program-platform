import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('host endpoint implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'host_endpoint'),
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
        'endpoint_file.dart',
        'json_values.dart',
        'models.dart',
        'policy_document.dart',
        'policy_resolver.dart',
        'records.dart',
        'registry_file.dart',
        'runner.dart',
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
          contains('package:mini_program_tooling/mini_program_tooling.dart'),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('mini_program_host_controller.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/host_endpoint/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_host_controller.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(50));
    expect(facadeSource, contains('runMiniProgramHost('));
    expect(facadeSource, contains('addMiniProgramHostEndpoint('));
    expect(facadeSource, isNot(contains('JsonEncoder')));
    expect(facadeSource, isNot(contains('StringBuffer')));
  });
}
