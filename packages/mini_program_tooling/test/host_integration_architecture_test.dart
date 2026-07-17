import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('host integration implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'host_integration'),
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
        'capabilities/location/android_channel_template.dart',
        'capabilities/location/dart_provider_template.dart',
        'capabilities/location/installer.dart',
        'capabilities/location/source_editors.dart',
        'capabilities/location/source_files.dart',
        'capabilities/models.dart',
        'embedding/android_integration.dart',
        'embedding/dart_templates.dart',
        'embedding/initializer.dart',
        'embedding/models.dart',
        'embedding/pubspec_editor.dart',
        'embedding/readme_template.dart',
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
        isNot(
          contains("import '../../mini_program_embedding_initializer.dart'"),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(
          contains(
            "import '../../mini_program_host_capability_installer.dart'",
          ),
        ),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/host_integration/')));

    final embeddingFacade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'mini_program_embedding_initializer.dart',
      ),
    );
    final capabilityFacade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'mini_program_host_capability_installer.dart',
      ),
    );
    expect(embeddingFacade.readAsLinesSync().length, lessThan(50));
    expect(capabilityFacade.readAsLinesSync().length, lessThan(50));
    expect(
      embeddingFacade.readAsStringSync(),
      contains('initializeMiniProgramEmbedding(request)'),
    );
    expect(
      capabilityFacade.readAsStringSync(),
      contains(
        'location_capability.initializeMiniProgramHostCapability(request)',
      ),
    );
  });
}
