import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import '../models.dart';
import '../shared/document_validation.dart';
import '../shared/json_io.dart';

Future<Version?> readExistingLatestArtifactVersion(
  String latestPath, {
  required String expectedAppId,
}) async {
  final latestFile = File(latestPath);
  if (!await latestFile.exists()) {
    return null;
  }
  final latest = await readArtifactJsonMap(
    latestPath,
    code: MiniProgramArtifactErrorCodes.latestInvalid,
    label: 'Existing latest manifest',
  );
  final id = '${latest['id'] ?? ''}'.trim();
  if (id != expectedAppId) {
    throw MiniProgramArtifactException(
      code: MiniProgramArtifactErrorCodes.latestInvalid,
      message:
          'Existing latest manifest appId "$id" does not match '
          '"$expectedAppId".',
    );
  }
  return parseArtifactVersion('${latest['version'] ?? ''}', latestPath);
}

Future<List<String>> discoverBuildArtifactVersions(
  String appArtifactsPath,
) async {
  final versions = <Version, String>{};
  await for (final entity in Directory(
    appArtifactsPath,
  ).list(followLinks: false)) {
    if (entity is! Directory || path.basename(entity.path).startsWith('.')) {
      continue;
    }
    final rawVersion = path.basename(entity.path);
    try {
      versions[Version.parse(rawVersion)] = rawVersion;
    } on FormatException {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.structureInvalid,
        message: 'Unexpected directory in app artifacts: ${entity.path}',
      );
    }
  }
  final sorted = versions.keys.toList()..sort();
  return sorted.map((version) => versions[version]!).toList(growable: false);
}
