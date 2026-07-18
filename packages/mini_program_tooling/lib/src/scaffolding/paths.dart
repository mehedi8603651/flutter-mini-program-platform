import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

Future<String> resolveMiniProgramScaffoldRootPath({
  required String? repoRootPath,
  required String? outputRootPath,
  required String miniProgramId,
}) async {
  if (outputRootPath != null && outputRootPath.trim().isNotEmpty) {
    return p.normalize(p.absolute(outputRootPath.trim()));
  }

  if (repoRootPath == null || repoRootPath.trim().isEmpty) {
    throw const MiniProgramScaffoldException(
      'Provide either --repo-root or --output-root.',
    );
  }

  final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
  if (!await Directory(normalizedRepoRoot).exists()) {
    throw MiniProgramScaffoldException(
      'Repo root does not exist: $normalizedRepoRoot',
    );
  }

  final miniProgramsRootPath = p.join(normalizedRepoRoot, 'mini_programs');
  if (!await Directory(miniProgramsRootPath).exists()) {
    throw MiniProgramScaffoldException(
      'Repo root is missing mini_programs/: $normalizedRepoRoot',
    );
  }

  return p.join(miniProgramsRootPath, miniProgramId);
}

Future<bool> scaffoldDirectoryHasEntries(Directory directory) async {
  await for (final _ in directory.list(followLinks: false)) {
    return true;
  }
  return false;
}
