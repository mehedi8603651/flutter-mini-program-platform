import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('Publisher API contract implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'publisher_backend_contract'),
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
        'files.dart',
        'models.dart',
        'operations.dart',
        'paths.dart',
        'smoke/coordinator.dart',
        'smoke/headers.dart',
        'smoke/response.dart',
        'smoke/transport.dart',
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
        isNot(contains('publisher_backend_contract_controller.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/publisher_backend_contract/')));

    final facade = File(
      path.join(
        packageRoot,
        'lib',
        'src',
        'publisher_backend_contract_controller.dart',
      ),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(70));
    expect(facadeSource, contains('class PublisherBackendContractController'));
    expect(facadeSource, contains('initializePublisherBackendContract'));
    expect(facadeSource, contains('smokePublisherBackendContract'));
    expect(facadeSource, isNot(contains('jsonDecode')));
    expect(facadeSource, isNot(contains('File(')));
    expect(facadeSource, isNot(contains('.get(')));
    expect(facadeSource, isNot(contains('.post(')));
  });
}
