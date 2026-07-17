import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('portable artifact implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'artifact_pipeline'),
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
        'build/catalog.dart',
        'build/checksums.dart',
        'build/coordinator.dart',
        'models.dart',
        'shared/constants.dart',
        'shared/data_assets.dart',
        'shared/document_validation.dart',
        'shared/files.dart',
        'shared/json_io.dart',
        'shared/metrics.dart',
        'shared/paths.dart',
        'verify/checksums.dart',
        'verify/coordinator.dart',
        'verify/version.dart',
        'verify/versions.dart',
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
        isNot(contains("import '../mini_program_artifacts.dart'")),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains("import '../../mini_program_artifacts.dart'")),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/artifact_pipeline/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_artifacts.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(75));
    expect(facadeSource, contains('class MiniProgramArtifactBuilder'));
    expect(facadeSource, contains('class MiniProgramArtifactVerifier'));
    expect(facadeSource, contains('buildPortableMiniProgramArtifact'));
    expect(facadeSource, contains('verifyPortableMiniProgramArtifact'));
    expect(facadeSource, isNot(contains('sha256.convert')));
    expect(facadeSource, isNot(contains('jsonDecode')));
  });
}
