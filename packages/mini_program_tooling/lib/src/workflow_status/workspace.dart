import 'dart:io';

import 'package:path/path.dart' as p;

Future<Map<String, Object?>> inspectWorkflowWorkspace(
  String workspacePath,
) async {
  final directory = Directory(workspacePath);
  final exists = await directory.exists();
  final manifestExists = await File(
    p.join(workspacePath, 'manifest.json'),
  ).exists();
  final pubspecExists = await File(
    p.join(workspacePath, 'pubspec.yaml'),
  ).exists();
  final runtimeSetupExists = await File(
    p.join(
      workspacePath,
      'lib',
      'mini_program',
      'mini_program_runtime_setup.dart',
    ),
  ).exists();
  final type = !exists
      ? 'unknown'
      : manifestExists
      ? 'mini_program'
      : pubspecExists && runtimeSetupExists
      ? 'host_app'
      : 'unknown';
  return <String, Object?>{
    'path': workspacePath,
    'exists': exists,
    'type': type,
  };
}
