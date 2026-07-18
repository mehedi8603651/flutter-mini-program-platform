import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('partner handoff implementation stays internal and modular', () {
    final packageRoot = Directory.current.path;
    final implementationRoot = Directory(
      path.join(packageRoot, 'lib', 'src', 'partner_handoff'),
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
        'constants.dart',
        'coordinator.dart',
        'errors.dart',
        'files.dart',
        'handoff.dart',
        'models.dart',
        'requested_policy/cache.dart',
        'requested_policy/json_values.dart',
        'requested_policy/permissions.dart',
        'requested_policy/publisher_api.dart',
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
          contains(
            "import 'package:mini_program_tooling/mini_program_tooling.dart'",
          ),
        ),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('mini_program_partner_handoff.dart')),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/partner_handoff/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'mini_program_partner_handoff.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(40));
    expect(facadeSource, contains('class MiniProgramPartnerHandoffController'));
    expect(facadeSource, contains('createMiniProgramPartnerPackage'));
    expect(facadeSource, contains('readPartnerHandoffFile'));
    expect(facadeSource, isNot(contains('jsonDecode')));
    expect(facadeSource, isNot(contains('JsonEncoder')));
    expect(facadeSource, isNot(contains("import 'dart:io'")));
  });
}
