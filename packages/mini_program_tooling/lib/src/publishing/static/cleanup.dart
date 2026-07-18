import 'dart:io';

import 'package:path/path.dart' as p;

import '../shared/errors.dart';

Future<void> cleanStaticPublishedApp({
  required String artifactsRootPath,
  required String? requestedAppId,
}) async {
  final normalizedAppId = requestedAppId?.trim();
  if (normalizedAppId == null || normalizedAppId.isEmpty) {
    return;
  }

  final appArtifactsPath = p.join(artifactsRootPath, normalizedAppId);
  assertStaticPublishTargetContained(
    candidatePath: appArtifactsPath,
    rootPath: artifactsRootPath,
  );
  final appArtifacts = Directory(appArtifactsPath);
  if (await appArtifacts.exists()) {
    await appArtifacts.delete(recursive: true);
  }
}

void assertStaticPublishTargetContained({
  required String candidatePath,
  required String rootPath,
}) {
  final candidate = p.normalize(p.absolute(candidatePath));
  final root = p.normalize(p.absolute(rootPath));
  if (candidate != root && !p.isWithin(root, candidate)) {
    throw MiniProgramPublishException(
      'Static publish target escaped output root: $candidate',
    );
  }
}
