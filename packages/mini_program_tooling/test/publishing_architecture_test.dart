import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('publishing adapters stay internal and feature-oriented', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'publishing'),
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
        'legacy/artifacts.dart',
        'legacy/coordinator.dart',
        'legacy/dependencies.dart',
        'legacy/models.dart',
        'legacy/paths.dart',
        'legacy/validation.dart',
        'shared/errors.dart',
        'static/cleanup.dart',
        'static/coordinator.dart',
        'static/dependencies.dart',
        'static/files.dart',
        'static/instructions.dart',
        'static/models.dart',
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
        isNot(contains("import '../../mini_program_publisher.dart'")),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains("import '../../mini_program_static_publisher.dart'")),
        reason: file.path,
      );
      final relativePath = path
          .relative(file.path, from: implementationRoot.path)
          .replaceAll('\\', '/');
      if (relativePath.startsWith('static/')) {
        expect(source, isNot(contains("../legacy/")), reason: file.path);
      }
      if (relativePath.startsWith('legacy/')) {
        expect(source, isNot(contains("../static/")), reason: file.path);
      }
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/publishing/')));

    final staticFacade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'mini_program_static_publisher.dart',
      ),
    );
    final staticSource = staticFacade.readAsStringSync();
    expect(staticFacade.readAsLinesSync().length, lessThan(45));
    expect(staticSource, contains('class MiniProgramStaticPublisher'));
    expect(staticSource, contains('publishStaticMiniProgram'));
    expect(staticSource, isNot(contains('Directory(')));
    expect(staticSource, isNot(contains('File(')));
    expect(staticSource, isNot(contains('MiniProgramArtifactBuilder(')));

    final legacyFacade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_publisher.dart'),
    );
    final legacySource = legacyFacade.readAsStringSync();
    expect(legacyFacade.readAsLinesSync().length, lessThan(45));
    expect(legacySource, contains('class MiniProgramPublisher'));
    expect(legacySource, contains('publishLegacyMiniProgram'));
    expect(legacySource, isNot(contains('Directory(')));
    expect(legacySource, isNot(contains('File(')));
    expect(legacySource, isNot(contains('.validate(')));
    expect(legacySource, isNot(contains('MiniProgramArtifactBuilder(')));
  });
}
