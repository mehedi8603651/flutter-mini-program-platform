import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

Future<String> validateHostProject(
  String rawProjectRootPath, {
  required bool requireRuntimeSetup,
}) async {
  final projectRootPath = p.normalize(p.absolute(rawProjectRootPath));
  final projectDirectory = Directory(projectRootPath);
  if (!await projectDirectory.exists()) {
    throw MiniProgramHostException(
      'Flutter host project root does not exist: $projectRootPath',
    );
  }

  final pubspecFile = File(p.join(projectRootPath, 'pubspec.yaml'));
  if (!await pubspecFile.exists()) {
    throw MiniProgramHostException(
      'Flutter host project is missing pubspec.yaml: $projectRootPath',
    );
  }

  if (requireRuntimeSetup) {
    final generatedRuntimeSetup = File(
      p.join(
        projectRootPath,
        'lib',
        'mini_program',
        'mini_program_runtime_setup.dart',
      ),
    );
    if (!await generatedRuntimeSetup.exists()) {
      throw const MiniProgramHostException(
        'The generated mini-program embedding adapter was not found. Run '
        '`miniprogram embed init` in the host Flutter app first.',
      );
    }
  }

  return projectRootPath;
}

void validateHostIdentifier(String value, String label) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed == '.' ||
      trimmed == '..' ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
    throw MiniProgramHostException('$label is invalid: $value');
  }
}

void validateHostEndpointUri(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw MiniProgramHostException(
      'Mini-program endpoint API base URL must be absolute: $uri',
    );
  }
}

String normalizeHostEndpointUri(Uri uri) =>
    uri.toString().replaceFirst(RegExp(r'/+$'), '');
