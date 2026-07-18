import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

Future<List<File>> listStaticPublishedFiles(String rootPath) async {
  final root = Directory(rootPath);
  if (!await root.exists()) {
    return <File>[];
  }
  return root
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File)
      .cast<File>()
      .toList();
}

List<StaticPublishedFileRecord> buildStaticPublishedFileRecords({
  required String outputPath,
  required List<File> files,
}) {
  files.sort((left, right) => left.path.compareTo(right.path));
  return files
      .map(
        (file) => StaticPublishedFileRecord(
          relativePath: p
              .relative(file.path, from: outputPath)
              .replaceAll('\\', '/'),
          localSourcePath: file.path,
        ),
      )
      .toList(growable: false);
}
