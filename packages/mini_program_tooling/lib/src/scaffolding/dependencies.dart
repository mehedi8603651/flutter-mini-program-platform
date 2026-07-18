import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

Future<String> resolveScaffoldMiniProgramUiDependency() async {
  final toolingUri = await Isolate.resolvePackageUri(
    Uri.parse('package:mini_program_tooling/mini_program_tooling.dart'),
  );
  if (toolingUri != null && toolingUri.isScheme('file')) {
    final toolingPackageRoot = p.dirname(p.dirname(toolingUri.toFilePath()));
    final candidate = p.normalize(
      p.join(p.dirname(toolingPackageRoot), 'mini_program_ui'),
    );
    if (await File(p.join(candidate, 'pubspec.yaml')).exists()) {
      return '''
  mini_program_ui:
    path: ${scaffoldYamlSingleQuote(candidate)}
''';
    }
  }

  return '''
  mini_program_ui: ^0.1.12
''';
}

Future<String> resolveScaffoldDependencyOverrides() async {
  final toolingUri = await Isolate.resolvePackageUri(
    Uri.parse('package:mini_program_tooling/mini_program_tooling.dart'),
  );
  if (toolingUri == null || !toolingUri.isScheme('file')) {
    return '';
  }

  final toolingPackageRoot = p.dirname(p.dirname(toolingUri.toFilePath()));
  final contractsPath = p.normalize(
    p.join(p.dirname(toolingPackageRoot), 'mini_program_contracts'),
  );
  if (!await File(p.join(contractsPath, 'pubspec.yaml')).exists()) {
    return '';
  }

  return '''

dependency_overrides:
  mini_program_contracts:
    path: ${scaffoldYamlSingleQuote(contractsPath)}
''';
}

String scaffoldYamlSingleQuote(String value) =>
    "'${value.replaceAll("'", "''")}'";
