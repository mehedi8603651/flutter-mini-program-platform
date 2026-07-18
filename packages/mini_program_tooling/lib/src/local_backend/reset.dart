import 'dart:io';

import 'package:path/path.dart' as p;

import '../local_state/models.dart';
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
  final artifactsRoot = p.join(backendApiRoot, 'artifacts');

  final latestManifestPaths =
      artifactsState.records
          .map((record) => record.latestManifestPath)
          .toSet()
          .toList()
        ..sort();
  for (final filePath in latestManifestPaths) {
    final normalizedFilePath = p.normalize(p.absolute(filePath));
    final containingRoot = _requireContainedRoot(
      path: normalizedFilePath,
      roots: <String>[manifestRoot, artifactsRoot],
    );
    if (await File(normalizedFilePath).exists()) {
      await File(normalizedFilePath).delete();
      removedPaths.add(normalizedFilePath);
    }
    await _pruneEmptyParents(
      startDirectoryPath: p.dirname(normalizedFilePath),
      stopAtRootPath: containingRoot,
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
    final containingRoot = _requireContainedRoot(
      path: normalizedFilePath,
      roots: <String>[manifestRoot, artifactsRoot],
    );
    if (await File(normalizedFilePath).exists()) {
      await File(normalizedFilePath).delete();
      removedPaths.add(normalizedFilePath);
    }
    await _pruneEmptyParents(
      startDirectoryPath: p.dirname(normalizedFilePath),
      stopAtRootPath: containingRoot,
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
    final containingRoot = _requireContainedRoot(
      path: normalizedDirectoryPath,
      roots: <String>[screenRoot, artifactsRoot],
    );
    final directory = Directory(normalizedDirectoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      removedPaths.add(normalizedDirectoryPath);
    }
    await _pruneEmptyParents(
      startDirectoryPath: p.dirname(normalizedDirectoryPath),
      stopAtRootPath: containingRoot,
    );
  }

  await _removeCanonicalArtifactRemainders(
    records: artifactsState.records,
    backendApiRoot: backendApiRoot,
    artifactsRoot: artifactsRoot,
    removedPaths: removedPaths,
  );

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

String _requireContainedRoot({
  required String path,
  required List<String> roots,
}) {
  final normalizedPath = p.normalize(p.absolute(path));
  for (final root in roots) {
    final normalizedRoot = p.normalize(p.absolute(root));
    if (p.isWithin(normalizedRoot, normalizedPath) ||
        normalizedPath == normalizedRoot) {
      return normalizedRoot;
    }
  }
  throw LocalBackendControlException(
    'Local reset path escaped backend root: $normalizedPath',
  );
}

Future<void> _removeCanonicalArtifactRemainders({
  required List<PublishedLocalArtifactRecord> records,
  required String backendApiRoot,
  required String artifactsRoot,
  required List<String> removedPaths,
}) async {
  final canonicalRecords = records.where(
    (record) =>
        _isCanonicalArtifactRecord(record, backendApiRoot: backendApiRoot),
  );
  final versionRoots =
      canonicalRecords
          .map(
            (record) => p.dirname(
              p.normalize(p.absolute(record.versionedManifestPath)),
            ),
          )
          .toSet()
          .toList()
        ..sort();
  for (final versionRoot in versionRoots) {
    _requireContainedRoot(path: versionRoot, roots: <String>[artifactsRoot]);
    final directory = Directory(versionRoot);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      removedPaths.add(versionRoot);
    }
  }

  final appRoots =
      canonicalRecords
          .map((record) => p.join(artifactsRoot, record.miniProgramId))
          .toSet()
          .toList()
        ..sort();
  for (final appRoot in appRoots) {
    _requireContainedRoot(path: appRoot, roots: <String>[artifactsRoot]);
    final appDirectory = Directory(appRoot);
    if (!await appDirectory.exists()) {
      continue;
    }
    final remainingVersionDirectories = await appDirectory
        .list(followLinks: false)
        .where(
          (entity) =>
              entity is Directory && p.basename(entity.path) != '.staging',
        )
        .toList();
    if (remainingVersionDirectories.isNotEmpty) {
      continue;
    }
    final catalogPath = p.join(appRoot, 'catalog.json');
    final catalogFile = File(catalogPath);
    if (await catalogFile.exists()) {
      await catalogFile.delete();
      removedPaths.add(catalogPath);
    }
    final stagingDirectory = Directory(p.join(appRoot, '.staging'));
    if (await stagingDirectory.exists() &&
        await stagingDirectory.list(followLinks: false).isEmpty) {
      await stagingDirectory.delete();
    }
    if (await appDirectory.exists() &&
        await appDirectory.list(followLinks: false).isEmpty) {
      await appDirectory.delete();
    }
  }
}

bool _isCanonicalArtifactRecord(
  PublishedLocalArtifactRecord record, {
  required String backendApiRoot,
}) {
  final appRoot = p.join(backendApiRoot, 'artifacts', record.miniProgramId);
  final versionRoot = p.join(appRoot, record.version);
  return p.equals(
        p.normalize(p.absolute(record.latestManifestPath)),
        p.join(appRoot, 'latest.json'),
      ) &&
      p.equals(
        p.normalize(p.absolute(record.versionedManifestPath)),
        p.join(versionRoot, 'manifest.json'),
      ) &&
      p.equals(
        p.normalize(p.absolute(record.screensDirectoryPath)),
        p.join(versionRoot, 'screens'),
      );
}
