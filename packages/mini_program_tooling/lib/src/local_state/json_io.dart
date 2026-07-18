import 'dart:convert';
import 'dart:io';

import 'models.dart';

const _prettyJsonEncoder = JsonEncoder.withIndent('  ');

Future<Map<String, dynamic>> readLocalStateJsonObject(File file) async {
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw LocalCliStateException(
        'State file is not a JSON object: ${file.path}',
      );
    }

    return decoded.map((key, value) => MapEntry(key.toString(), value));
  } on FormatException catch (error) {
    throw LocalCliStateException(
      'State file contains invalid JSON: ${file.path}\n${error.message}',
    );
  } on FileSystemException catch (error) {
    throw LocalCliStateException(
      'Failed to read state file: ${file.path}\n$error',
    );
  }
}

Future<void> writeLocalStateJsonObject(File file, Map<String, dynamic> json) =>
    file.writeAsString(_prettyJsonEncoder.convert(json));
