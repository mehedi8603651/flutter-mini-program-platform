import 'dart:convert';
import 'dart:io';

import 'models.dart';

Future<void> validateMiniProgramBuildEntryScreen({
  required String entryScreenJsonPath,
  required String entryScreenId,
  required int? screenSchemaVersion,
}) async {
  Object? decoded;
  try {
    decoded = jsonDecode(await File(entryScreenJsonPath).readAsString());
  } on FormatException catch (error) {
    throw MiniProgramBuildException(
      'Mp entry screen JSON could not be parsed: $entryScreenJsonPath\n'
      '${error.message}',
    );
  }

  if (decoded is! Map) {
    throw MiniProgramBuildException(
      'Mp entry screen JSON must be an object: $entryScreenJsonPath',
    );
  }
  final json = decoded.map((key, value) => MapEntry(key.toString(), value));
  if (json['schemaVersion'] != screenSchemaVersion) {
    throw MiniProgramBuildException(
      'Mp entry screen schemaVersion "${json['schemaVersion']}" does not '
      'match manifest screenSchemaVersion "$screenSchemaVersion": '
      '$entryScreenJsonPath',
    );
  }
  if (json['screenId'] != entryScreenId) {
    throw MiniProgramBuildException(
      'Mp entry screenId "${json['screenId']}" does not match manifest entry '
      '"$entryScreenId": $entryScreenJsonPath',
    );
  }
  if (json['root'] is! Map) {
    throw MiniProgramBuildException(
      'Mp entry screen root must be an object: $entryScreenJsonPath',
    );
  }
}
