import 'dart:io';

import 'package:path/path.dart' as p;

import 'dependencies.dart';
import 'models.dart';

Future<LocalBackendResetResult> resetTrackedLocalBackendArtifacts(
  LocalBackendDependencies dependencies, {
  required String repoRootPath,
}) async {
  final normalizedRepoRoot = p.normalize(p.absolute(repoRootPath));
  final artifactsState = await dependencies.stateStore
      .readPublishedArtifactsState(normalizedRepoRoot);
  final removedPaths = <String>[];
  final backendApiRoot = p.join(normalizedRepoRoot, 'backend', 'api');
  final manifestRoot = p.join(backendApiRoot, 'manifests');
  final screenRoot = p.join(backendApiRoot, 'screens');

  final latestManifestPaths =
      artifactsState.records
          .map((record) => record.latestManifestPath)
          .toSet()
          .toList()
        ..sort();
  for (final filePath in latestManifestPaths) {
    final normalizedFilePath = p.normalize(p.absolute(filePath));
    _assertContainedPath(path: normalizedFilePath, root: manifestRoot);
    if (await File(normalizedFilePath).exists()) {
      await File(normalizedFilePath).delete();
      removedPaths.add(normalizedFilePath);
    }
    await _pruneEmptyParents(
      startDirectoryPath: p.dirname(normalizedFilePath),
      stopAtRootPath: manifestRoot,
    );
  }

  final versionedManifestPaths =
      artifactsState.records
          .map((record) => record.versionedManifestPath)
          .toSet()
          .toList()
        ..sort();
  for (final filePath in versionedManifestPaths) {
    final normalizedFilePath = p.normalize(p.absolute(filePath));
    _assertContainedPath(path: normalizedFilePath, root: manifestRoot);
    if (await File(normalizedFilePath).exists()) {
      await File(normalizedFilePath).delete();
      removedPaths.add(normalizedFilePath);
    }
    await _pruneEmptyParents(
      startDirectoryPath: p.dirname(normalizedFilePath),
      stopAtRootPath: manifestRoot,
    );
  }

  final screenDirectories =
      artifactsState.records
          .map((record) => record.screensDirectoryPath)
          .toSet()
          .toList()
        ..sort();
  for (final directoryPath in screenDirectories) {
    final normalizedDirectoryPath = p.normalize(p.absolute(directoryPath));
    _assertContainedPath(path: normalizedDirectoryPath, root: screenRoot);
    final directory = Directory(normalizedDirectoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      removedPaths.add(normalizedDirectoryPath);
    }
    await _pruneEmptyParents(
      startDirectoryPath: p.dirname(normalizedDirectoryPath),
      stopAtRootPath: screenRoot,
    );
  }

  await dependencies.stateStore.clearPublishedArtifactsState(
    normalizedRepoRoot,
  );
  return LocalBackendResetResult(removedPaths: removedPaths);
}

Future<void> _pruneEmptyParents({
  required String startDirectoryPath,
  required String stopAtRootPath,
}) async {
  var current = p.normalize(p.absolute(startDirectoryPath));
  final normalizedStopAtRootPath = p.normalize(p.absolute(stopAtRootPath));

  while (p.isWithin(normalizedStopAtRootPath, current) &&
      current != normalizedStopAtRootPath) {
    final directory = Directory(current);
    if (!await directory.exists()) {
      current = p.dirname(current);
      continue;
    }

    final entries = await directory.list(followLinks: false).toList();
    if (entries.isNotEmpty) {
      return;
    }

    await directory.delete();
    current = p.dirname(current);
  }
}

void _assertContainedPath({required String path, required String root}) {
  final normalizedPath = p.normalize(p.absolute(path));
  final normalizedRoot = p.normalize(p.absolute(root));
  if (!p.isWithin(normalizedRoot, normalizedPath) &&
      normalizedPath != normalizedRoot) {
    throw LocalBackendControlException(
      'Local reset path escaped backend root: $normalizedPath',
    );
  }
}
