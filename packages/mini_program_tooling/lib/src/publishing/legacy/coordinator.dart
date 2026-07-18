import 'dart:io';

import 'package:path/path.dart' as p;

import '../../mini_program_builder.dart';
import 'artifacts.dart';
import 'dependencies.dart';
import 'models.dart';
import 'paths.dart';
import 'validation.dart';

Future<MiniProgramPublishResult> publishLegacyMiniProgram(
  MiniProgramPublishRequest request, {
  required LegacyPublishingDependencies dependencies,
}) async {
  final paths = await resolveLegacyPublishingPaths(request);
  final buildResult = await dependencies.builder.build(
    MiniProgramBuildRequest(
      repoRootPath: paths.repoRootPath,
      miniProgramId: request.miniProgramId,
      miniProgramRootPath: request.miniProgramRootPath,
      mpBuildScriptPath: request.mpBuildScriptPath,
      skipPubGet: request.skipBuildPubGet,
    ),
  );
  final preValidation = await validateLegacyPublishing(
    validator: dependencies.validator,
    stage: LegacyPublishingValidationStage.beforePublish,
    repoRootPath: paths.repoRootPath,
    backendRootPath: paths.backendRootPath,
    miniProgramId: buildResult.miniProgramId,
    externalMiniProgramRootPath: request.miniProgramRootPath,
  );

  final artifactResult = await buildLegacyPublishingArtifact(
    repoRootPath: paths.repoRootPath,
    backendApiPath: paths.backendApiPath,
    buildResult: buildResult,
  );

  final postValidation = await validateLegacyPublishing(
    validator: dependencies.validator,
    stage: LegacyPublishingValidationStage.afterPublish,
    repoRootPath: paths.repoRootPath,
    backendRootPath: paths.backendRootPath,
    miniProgramId: buildResult.miniProgramId,
    externalMiniProgramRootPath: request.miniProgramRootPath,
  );

  final screensDirectoryPath = p.join(
    artifactResult.versionArtifactsPath,
    'screens',
  );
  final copiedScreenCount = await Directory(screensDirectoryPath)
      .list(followLinks: false)
      .where((entity) => entity is File && p.extension(entity.path) == '.json')
      .length;

  return MiniProgramPublishResult(
    repoRootPath: paths.repoRootPath,
    backendRootPath: paths.backendRootPath,
    miniProgramId: buildResult.miniProgramId,
    version: artifactResult.version,
    buildResult: buildResult,
    prePublishValidation: preValidation,
    postPublishValidation: postValidation,
    latestManifestPath: artifactResult.latestManifestPath,
    versionedManifestPath: p.join(
      artifactResult.versionArtifactsPath,
      'manifest.json',
    ),
    screensDirectoryPath: screensDirectoryPath,
    copiedScreenCount: copiedScreenCount,
  );
}
