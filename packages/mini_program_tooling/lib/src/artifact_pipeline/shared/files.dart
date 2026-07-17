import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../models.dart';
import 'paths.dart';

Future<List<File>> listArtifactFiles(
  String directoryPath, {
  required bool recursive,
  bool required = false,
}) async {
  final directory = Directory(directoryPath);
  if (!await directory.exists()) {
    if (required) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.fileMissing,
        message: 'Required artifact directory was not found: $directoryPath',
      );
    }
    return <File>[];
  }
  final files = <File>[];
  await for (final entity in directory.list(
    recursive: recursive,
    followLinks: false,
  )) {
    if (entity is Link) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.pathUnsafe,
        message: 'Symbolic links are not allowed in artifacts: ${entity.path}',
      );
    }
    if (entity is File) {
      files.add(entity);
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

Future<void> copyArtifactDirectoryFiles({
  required String sourceRoot,
  required String targetRoot,
}) async {
  final files = await listArtifactFiles(sourceRoot, recursive: true);
  for (final file in files) {
    final relativePath = path.relative(file.path, from: sourceRoot);
    final targetPath = path.normalize(path.join(targetRoot, relativePath));
    assertArtifactPathContained(targetPath, targetRoot);
    await Directory(path.dirname(targetPath)).create(recursive: true);
    await file.copy(targetPath);
  }
}

Future<bool> artifactDirectoriesEqual(String leftPath, String rightPath) async {
  final leftFiles = await listArtifactFiles(leftPath, recursive: true);
  final rightFiles = await listArtifactFiles(rightPath, recursive: true);
  final leftByPath = <String, File>{
    for (final file in leftFiles)
      relativePortableArtifactPath(file.path, leftPath): file,
  };
  final rightByPath = <String, File>{
    for (final file in rightFiles)
      relativePortableArtifactPath(file.path, rightPath): file,
  };
  if (leftByPath.length != rightByPath.length ||
      !leftByPath.keys.toSet().containsAll(rightByPath.keys)) {
    return false;
  }
  for (final path in leftByPath.keys) {
    final left = leftByPath[path]!;
    final right = rightByPath[path]!;
    if (await left.length() != await right.length()) {
      return false;
    }
    if (sha256.convert(await left.readAsBytes()) !=
        sha256.convert(await right.readAsBytes())) {
      return false;
    }
  }
  return true;
}
