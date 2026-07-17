import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models.dart';

Future<Map<String, dynamic>> readArtifactJsonMap(
  String filePath, {
  required String code,
  required String label,
}) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.fileMissing,
      message: '$label was not found: $filePath',
    );
  }
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw MiniProgramArtifactException(
        code: code,
        message: '$label must be a JSON object: $filePath',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  } on FormatException catch (error) {
    throw MiniProgramArtifactException(
      code: code,
      message: '$label contains invalid JSON: $filePath\n${error.message}',
    );
  }
}

Future<void> writeCanonicalArtifactJson(
  String filePath,
  Map<String, Object?> json,
) async {
  await Directory(path.dirname(filePath)).create(recursive: true);
  await File(
    filePath,
  ).writeAsString('${canonicalArtifactJson(json)}\n', flush: true);
}

Future<bool> writeCanonicalArtifactJsonAtomic(
  String filePath,
  Map<String, Object?> json,
) async {
  await Directory(path.dirname(filePath)).create(recursive: true);
  final contents = '${canonicalArtifactJson(json)}\n';
  final target = File(filePath);
  if (await target.exists() && await target.readAsString() == contents) {
    return false;
  }
  final temporaryPath =
      '$filePath.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}';
  final temporaryFile = File(temporaryPath);
  await temporaryFile.writeAsString(contents, flush: true);
  try {
    await temporaryFile.rename(filePath);
  } on FileSystemException {
    if (await target.exists()) {
      await target.delete();
    }
    await temporaryFile.rename(filePath);
  }
  return true;
}

String canonicalArtifactJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return <String, Object?>{
      for (final entry in entries) entry.key: _canonicalize(entry.value),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
