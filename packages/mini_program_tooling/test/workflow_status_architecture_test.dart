import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('workflow status implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'workflow_status'),
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
        'assessment.dart',
        'backend_usage.dart',
        'coordinator.dart',
        'dependencies.dart',
        'environment_backend.dart',
        'host_app.dart',
        'metadata.dart',
        'mini_program.dart',
        'models.dart',
        'publisher_backend.dart',
        'validation.dart',
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
        isNot(contains('mini_program_workflow_status.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/workflow_status/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_workflow_status.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(60));
    expect(facadeSource, contains('MiniProgramWorkflowStatusController'));
    expect(facadeSource, contains('inspectMiniProgramWorkflowStatus'));
    expect(facadeSource, isNot(contains('jsonDecode')));
    expect(facadeSource, isNot(contains('Directory(')));
    expect(facadeSource, isNot(contains('File(')));
    expect(facadeSource, isNot(contains('RegExp(')));
  });
}
