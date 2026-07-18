import 'dart:io';

import 'package:path/path.dart' as p;

import 'dependencies.dart';
import 'models.dart';

Future<void> assertLocalBackendPaths({
  required String serviceDirectoryPath,
  required String apiRootPath,
  required String serverScriptPath,
}) async {
  if (!await Directory(serviceDirectoryPath).exists()) {
    throw LocalBackendControlException(
      'Local artifact service was not found: $serviceDirectoryPath',
    );
  }
  if (!await Directory(apiRootPath).exists()) {
    throw LocalBackendControlException(
      'Local artifact API root was not found: $apiRootPath',
    );
  }
  if (!await File(serverScriptPath).exists()) {
    throw LocalBackendControlException(
      'Local artifact host entrypoint was not found: $serverScriptPath',
    );
  }
}

Future<void> ensureLocalBackendPackageConfig(
  LocalBackendDependencies dependencies,
  String serviceDirectoryPath,
) async {
  final pubspecPath = p.join(serviceDirectoryPath, 'pubspec.yaml');
  final packageConfigPath = p.join(
    serviceDirectoryPath,
    '.dart_tool',
    'package_config.json',
  );
  if (!await File(pubspecPath).exists() ||
      await File(packageConfigPath).exists()) {
    return;
  }

  final result = await dependencies.shellRunner(
    Platform.resolvedExecutable,
    const <String>['pub', 'get'],
    workingDirectory: serviceDirectoryPath,
  );
  if (result.exitCode == 0) {
    return;
  }

  final stdoutText = '${result.stdout}'.trim();
  final stderrText = '${result.stderr}'.trim();
  throw LocalBackendControlException(
    [
      'Failed to prepare backend/local_backend_service before launch.',
      'Command: ${Platform.resolvedExecutable} pub get',
      if (stdoutText.isNotEmpty) 'stdout:\n$stdoutText',
      if (stderrText.isNotEmpty) 'stderr:\n$stderrText',
    ].join('\n'),
  );
}
