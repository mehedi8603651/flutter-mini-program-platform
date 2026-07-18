import 'dart:convert';
import 'dart:io';

import 'models.dart';

Future<MiniProgramBuildManifest> loadMiniProgramBuildManifest({
  required String manifestPath,
  required String? requestedMiniProgramId,
}) async {
  final manifest =
      jsonDecode(await File(manifestPath).readAsString())
          as Map<String, dynamic>;
  final miniProgramId = '${manifest['id'] ?? ''}'.trim();
  if (miniProgramId.isEmpty) {
    throw MiniProgramBuildException(
      'Manifest is missing a usable id: $manifestPath',
    );
  }
  if (requestedMiniProgramId != null &&
      requestedMiniProgramId.trim().isNotEmpty &&
      requestedMiniProgramId != miniProgramId) {
    throw MiniProgramBuildException(
      'Manifest id "$miniProgramId" does not match requested id '
      '"$requestedMiniProgramId".',
    );
  }

  final entryScreenId = manifest['entry'] as String?;
  if (entryScreenId == null || entryScreenId.trim().isEmpty) {
    throw MiniProgramBuildException(
      'Manifest is missing a usable entry screen: $manifestPath',
    );
  }
  final screenFormat = resolveMiniProgramBuildScreenFormat(
    manifest,
    manifestPath,
  );
  final screenSchemaVersion = resolveMiniProgramBuildScreenSchemaVersion(
    manifest,
    manifestPath,
    screenFormat: screenFormat,
  );
  return MiniProgramBuildManifest(
    miniProgramId: miniProgramId,
    entryScreenId: entryScreenId,
    screenFormat: screenFormat,
    screenSchemaVersion: screenSchemaVersion,
  );
}

String resolveMiniProgramBuildScreenFormat(
  Map<String, dynamic> manifest,
  String manifestPath,
) {
  final rawValue = manifest['screenFormat'];
  final screenFormat = rawValue == null ? 'mp' : '$rawValue'.trim();
  if (screenFormat.isEmpty) {
    throw MiniProgramBuildException(
      'Manifest screenFormat must not be empty: $manifestPath',
    );
  }
  if (screenFormat == 'mp') {
    return screenFormat;
  }
  throw MiniProgramBuildException(
    'Unsupported manifest screenFormat "$screenFormat": $manifestPath',
  );
}

int? resolveMiniProgramBuildScreenSchemaVersion(
  Map<String, dynamic> manifest,
  String manifestPath, {
  required String screenFormat,
}) {
  final rawValue = manifest['screenSchemaVersion'];
  if (rawValue == null) {
    return 1;
  }
  if (rawValue is! int || rawValue <= 0) {
    throw MiniProgramBuildException(
      'Manifest screenSchemaVersion must be a positive integer: '
      '$manifestPath',
    );
  }
  if (rawValue != 1) {
    throw MiniProgramBuildException(
      'Unsupported Mp screenSchemaVersion "$rawValue": $manifestPath',
    );
  }
  return rawValue;
}
