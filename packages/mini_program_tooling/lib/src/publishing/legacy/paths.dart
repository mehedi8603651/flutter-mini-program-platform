import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';

class LegacyPublishingPaths {
  const LegacyPublishingPaths({
    required this.repoRootPath,
    required this.backendRootPath,
    required this.backendApiPath,
  });

  final String repoRootPath;
  final String backendRootPath;
  final String backendApiPath;
}

Future<LegacyPublishingPaths> resolveLegacyPublishingPaths(
  MiniProgramPublishRequest request,
) async {
  final repoRootPath = p.normalize(p.absolute(request.repoRootPath));
  final backendRootPath = p.normalize(
    p.absolute(request.backendRootPath ?? request.repoRootPath),
  );
  final backendApiPath = p.join(backendRootPath, 'backend', 'api');
  if (!await Directory(backendApiPath).exists()) {
    throw MiniProgramPublishException(
      'Artifact workspace API root does not exist: $backendApiPath',
    );
  }

  return LegacyPublishingPaths(
    repoRootPath: repoRootPath,
    backendRootPath: backendRootPath,
    backendApiPath: backendApiPath,
  );
}
