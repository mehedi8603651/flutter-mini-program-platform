import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('delivery validation implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'delivery_validation'),
    );
    final implementationFiles =
        implementationRoot
            .listSync()
            .whereType<File>()
            .where((file) => path.extension(file.path) == '.dart')
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(
      implementationFiles.map((file) => path.basename(file.path)).toList(),
      <String>[
        'authored_manifests.dart',
        'capability_policies.dart',
        'json_reader.dart',
        'manifest_validation.dart',
        'published_manifests.dart',
        'rollout_rules.dart',
        'secure_api_policies.dart',
        'shared_validation.dart',
        'validation_context.dart',
      ],
    );

    for (final file in implementationFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('part of ')), reason: file.path);
      expect(source, isNot(contains("import '../delivery_validator.dart'")));
      expect(
        source,
        isNot(
          contains("package:mini_program_tooling/mini_program_tooling.dart"),
        ),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains("src/delivery_validation/")));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'delivery_validator.dart'),
    );
    expect(facade.readAsLinesSync().length, lessThan(250));
    expect(
      facade.readAsStringSync(),
      contains('class DeliveryRepositoryValidator'),
    );
  });
}
