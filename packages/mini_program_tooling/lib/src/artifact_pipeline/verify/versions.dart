import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

import '../models.dart';
import '../shared/document_validation.dart';

Future<List<String>> discoverVerifiedArtifactVersions(
  String appArtifactsPath,
) async {
  final versions = <Version, String>{};
  await for (final entity in Directory(
    appArtifactsPath,
  ).list(followLinks: false)) {
    if (entity is Link) {
      throw MiniProgramArtifactException(
        code: MiniProgramArtifactErrorCodes.pathUnsafe,
        message: 'Symbolic links are not allowed in artifacts: ${entity.path}',
      );
    }
    if (entity is! Directory || path.basename(entity.path).startsWith('.')) {
      continue;
    }
    final rawVersion = path.basename(entity.path);
    versions[parseArtifactVersion(rawVersion, entity.path)] = rawVersion;
  }
  final sorted = versions.keys.toList()..sort();
  return sorted.map((version) => versions[version]!).toList(growable: false);
}
