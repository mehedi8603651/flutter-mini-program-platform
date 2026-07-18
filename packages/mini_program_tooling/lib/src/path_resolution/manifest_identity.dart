import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<String?> readMiniProgramManifestId(String rootPath) async {
  final rootDirectory = Directory(rootPath);
  if (!await rootDirectory.exists()) {
    return null;
  }

  final manifestFile = File(p.join(rootPath, 'manifest.json'));
  if (!await manifestFile.exists()) {
    return null;
  }

  try {
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) {
      return null;
    }

    final manifest = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final manifestId = '${manifest['id'] ?? ''}'.trim();
    return manifestId.isEmpty ? null : manifestId;
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }
}
