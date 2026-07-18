import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('CLI runtime stays internal and uses normal Dart libraries', () {
    final packageRoot = Directory.current.path;
    final cliRoot = Directory(path.join(packageRoot, 'lib', 'src', 'cli'));
    final cliFiles =
        cliRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => path.extension(file.path) == '.dart')
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(
      cliFiles
          .map(
            (file) => path
                .relative(file.path, from: cliRoot.path)
                .replaceAll('\\', '/'),
          )
          .toList(),
      <String>[
        'artifact_commands.dart',
        'backend_commands.dart',
        'command_imports.dart',
        'context.dart',
        'core_commands.dart',
        'env_commands.dart',
        'host_partner_commands.dart',
        'json_output_helpers.dart',
        'miniprogram_cli_constants.dart',
        'private_models.dart',
        'publisher_backend_commands.dart',
        'publisher_backend_contract_commands.dart',
        'publisher_backend_output_helpers.dart',
        'result_formatters.dart',
        'runtime.dart',
        'shared_helpers.dart',
        'support.dart',
        'usage_helpers.dart',
        'workflow_commands.dart',
      ],
    );

    for (final file in cliFiles) {
      final source = file.readAsStringSync();
      expect(
        RegExp(r'^\s*part(?:\s+of)?\s', multiLine: true).hasMatch(source),
        isFalse,
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('miniprogram_cli.dart')),
        reason: file.path,
      );
      expect(
        source,
        isNot(
          contains(
            "import 'package:mini_program_tooling/mini_program_tooling.dart';",
          ),
        ),
        reason: file.path,
      );
    }

    final publicBarrel = File(
      path.join(packageRoot, 'lib', 'mini_program_tooling.dart'),
    ).readAsStringSync();
    expect(publicBarrel, isNot(contains('src/cli/')));

    final facade = File(
      path.join(packageRoot, 'lib', 'src', 'miniprogram_cli.dart'),
    );
    final facadeSource = facade.readAsStringSync();
    expect(facade.readAsLinesSync().length, lessThan(90));
    expect(facadeSource, contains('class MiniprogramCli'));
    expect(facadeSource, contains('CliDependencies('));
    expect(facadeSource, contains('runMiniprogramCli('));
    expect(facadeSource, isNot(contains('switch (arguments.first)')));
    expect(facadeSource, isNot(contains('.writeln(')));
    expect(facadeSource, isNot(contains(' catch ')));

    final runtime = File(
      path.join(packageRoot, 'lib', 'src', 'cli', 'runtime.dart'),
    ).readAsStringSync();
    expect(runtime, contains('switch (arguments.first)'));
    expect(runtime, contains('on FormatException catch'));
    expect(runtime, contains('return 64;'));
    expect(runtime, contains('return 1;'));

    for (final commandFileName in <String>[
      'artifact_commands.dart',
      'backend_commands.dart',
      'core_commands.dart',
      'env_commands.dart',
      'host_partner_commands.dart',
      'publisher_backend_commands.dart',
      'publisher_backend_contract_commands.dart',
      'workflow_commands.dart',
    ]) {
      final source = File(
        path.join(packageRoot, 'lib', 'src', 'cli', commandFileName),
      ).readAsStringSync();
      expect(source, contains(' on CliContext {'), reason: commandFileName);
      expect(
        source,
        contains("import 'support.dart';"),
        reason: commandFileName,
      );
    }
  });
}
