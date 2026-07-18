import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

Future<void> copyLocalBackendTemplateTree({
  required String sourceRootPath,
  required String destinationRootPath,
  required bool force,
  required List<String> createdPaths,
}) async {
  final destinationRootDirectory = Directory(destinationRootPath);
  await destinationRootDirectory.create(recursive: true);

  final sourceRootDirectory = Directory(sourceRootPath);
  final entities = await sourceRootDirectory
      .list(recursive: true, followLinks: false)
      .toList();
  entities.sort((a, b) => a.path.compareTo(b.path));

  for (final entity in entities) {
    final relativePath = p.relative(entity.path, from: sourceRootPath);
    final destinationPath = p.join(destinationRootPath, relativePath);

    if (entity is Directory) {
      final directory = Directory(destinationPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        createdPaths.add(destinationPath);
      }
      continue;
    }

    if (entity is! File) {
      continue;
    }

    final sourceBytes = await entity.readAsBytes();
    final destinationFile = File(destinationPath);
    final destinationDirectory = Directory(p.dirname(destinationPath));
    await destinationDirectory.create(recursive: true);

    if (await destinationFile.exists()) {
      final existingBytes = await destinationFile.readAsBytes();
      if (localBackendTemplateBytesEqual(existingBytes, sourceBytes)) {
        continue;
      }
      if (!force) {
        throw LocalBackendInitException(
          'Backend init would overwrite an existing file. '
          'Re-run with --force if you want to replace scaffold-managed '
          'files.\n$destinationPath',
        );
      }
    } else {
      createdPaths.add(destinationPath);
    }

    await destinationFile.writeAsBytes(sourceBytes, flush: true);
  }
}

bool localBackendTemplateBytesEqual(List<int> left, List<int> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
