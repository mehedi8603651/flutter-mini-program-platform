import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';
import 'normalization.dart';

Future<String?> resolvePlatformRepoRoot({
  String? explicitRepoRootPath,
  String? currentWorkingDirectory,
  String? additionalSearchPath,
  bool required = false,
}) async {
  if (explicitRepoRootPath != null && explicitRepoRootPath.trim().isNotEmpty) {
    final normalizedRepoRoot = normalizeAbsolutePath(explicitRepoRootPath);
    if (!await looksLikePlatformRepoRoot(normalizedRepoRoot)) {
      throw MiniProgramPathResolutionException(
        'Repo root does not look like the platform repository: '
        '$normalizedRepoRoot',
      );
    }
    return normalizedRepoRoot;
  }

  final startDirectories = <String>{
    normalizeWorkingDirectory(currentWorkingDirectory),
    if (additionalSearchPath != null && additionalSearchPath.trim().isNotEmpty)
      normalizeAbsolutePath(additionalSearchPath),
  };

  for (final startDirectory in startDirectories) {
    final discovered = await discoverPlatformRepoRoot(
      startDirectory: startDirectory,
    );
    if (discovered != null) {
      return discovered;
    }
  }

  if (required) {
    throw const MiniProgramPathResolutionException(
      'Could not find the platform repo root. Provide --repo-root or run the '
      'command from inside the platform repository.',
    );
  }

  return null;
}

Future<String?> discoverPlatformRepoRoot({
  required String startDirectory,
}) async {
  var current = normalizeAbsolutePath(startDirectory);

  while (true) {
    if (await looksLikePlatformRepoRoot(current)) {
      return current;
    }

    final parent = p.dirname(current);
    if (parent == current) {
      return null;
    }
    current = parent;
  }
}

Future<bool> looksLikePlatformRepoRoot(String directoryPath) async {
  final miniProgramsRoot = Directory(p.join(directoryPath, 'mini_programs'));
  final backendApiRoot = Directory(p.join(directoryPath, 'backend', 'api'));
  final toolingPackage = File(
    p.join(directoryPath, 'packages', 'mini_program_tooling', 'pubspec.yaml'),
  );

  return await miniProgramsRoot.exists() &&
      await backendApiRoot.exists() &&
      await toolingPackage.exists();
}
