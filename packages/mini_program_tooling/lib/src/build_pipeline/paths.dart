import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

class MiniProgramBuildPaths {
  const MiniProgramBuildPaths({
    required this.miniProgramRootPath,
    required this.manifestPath,
    required this.pubspecPath,
    required this.outputDirectoryPath,
    required this.screensDirectoryPath,
    required this.entryScreenJsonPath,
    required this.assetsDirectoryPath,
  });

  final String miniProgramRootPath;
  final String manifestPath;
  final String pubspecPath;
  final String outputDirectoryPath;
  final String screensDirectoryPath;
  final String entryScreenJsonPath;
  final String assetsDirectoryPath;
}

String? normalizeMiniProgramBuildRepoRootPath(String? repoRootPath) =>
    repoRootPath == null ? null : p.normalize(p.absolute(repoRootPath));

String resolveMiniProgramBuildRootPath({
  required String? repoRootPath,
  required String? miniProgramId,
  required String? miniProgramRootPath,
}) {
  if (miniProgramRootPath != null && miniProgramRootPath.trim().isNotEmpty) {
    return p.normalize(p.absolute(miniProgramRootPath.trim()));
  }

  if (repoRootPath == null ||
      miniProgramId == null ||
      miniProgramId.trim().isEmpty) {
    throw const MiniProgramBuildException(
      'Provide either --mini-program-root or both --repo-root and --id.',
    );
  }

  return p.join(repoRootPath, 'mini_programs', miniProgramId);
}

Future<void> validateMiniProgramBuildProject(String miniProgramRootPath) async {
  if (!await Directory(miniProgramRootPath).exists()) {
    throw MiniProgramBuildException(
      'Mini-program root does not exist: $miniProgramRootPath',
    );
  }

  final manifestPath = p.join(miniProgramRootPath, 'manifest.json');
  final pubspecPath = p.join(miniProgramRootPath, 'pubspec.yaml');
  for (final requiredPath in <String>[manifestPath, pubspecPath]) {
    if (!await File(requiredPath).exists()) {
      throw MiniProgramBuildException(
        'Required file is missing: $requiredPath',
      );
    }
  }
}

Future<String> resolveMiniProgramBuildOutputDirectory({
  required String miniProgramRootPath,
  required String screenFormat,
}) async => p.normalize(p.join(miniProgramRootPath, 'mp', '.build'));

MiniProgramBuildPaths createMiniProgramBuildPaths({
  required String miniProgramRootPath,
  required String outputDirectoryPath,
  required String entryScreenId,
}) {
  final screensDirectoryPath = p.join(outputDirectoryPath, 'screens');
  return MiniProgramBuildPaths(
    miniProgramRootPath: miniProgramRootPath,
    manifestPath: p.join(miniProgramRootPath, 'manifest.json'),
    pubspecPath: p.join(miniProgramRootPath, 'pubspec.yaml'),
    outputDirectoryPath: outputDirectoryPath,
    screensDirectoryPath: screensDirectoryPath,
    entryScreenJsonPath: p.join(screensDirectoryPath, '$entryScreenId.json'),
    assetsDirectoryPath: p.join(miniProgramRootPath, 'assets'),
  );
}
