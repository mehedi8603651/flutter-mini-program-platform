import 'dart:io';

import 'package:path/path.dart' as p;

import '../../mini_program_artifacts.dart';
import '../shared/errors.dart';
import 'cleanup.dart';
import 'dependencies.dart';
import 'files.dart';
import 'instructions.dart';
import 'models.dart';

Future<MiniProgramStaticPublishResult> publishStaticMiniProgram(
  MiniProgramStaticPublishRequest request, {
  required StaticPublishingDependencies dependencies,
}) async {
  final outputPath = p.normalize(p.absolute(request.outputPath));
  final artifactsRoot = p.join(outputPath, 'artifacts');

  if (request.clean) {
    await cleanStaticPublishedApp(
      artifactsRootPath: artifactsRoot,
      requestedAppId: request.miniProgramId,
    );
  }

  late final MiniProgramArtifactBuildResult artifactResult;
  try {
    artifactResult =
        await MiniProgramArtifactBuilder(builder: dependencies.builder).build(
          MiniProgramArtifactBuildRequest(
            repoRootPath: request.repoRootPath,
            miniProgramId: request.miniProgramId,
            miniProgramRootPath: request.miniProgramRootPath,
            artifactsRootPath: artifactsRoot,
            mpBuildScriptPath: request.mpBuildScriptPath,
            skipPubGet: request.skipBuildPubGet,
          ),
        );
  } on MiniProgramArtifactException catch (error) {
    throw MiniProgramPublishException(error.toString());
  }

  await Directory(outputPath).create(recursive: true);
  final instructionsPath = p.join(outputPath, 'PUBLISH_INSTRUCTIONS.md');
  final nojekyllPath = p.join(outputPath, '.nojekyll');
  await File(instructionsPath).writeAsString(
    buildStaticPublishInstructions(
      miniProgramId: artifactResult.buildResult.miniProgramId,
      version: artifactResult.version,
    ),
  );
  await File(nojekyllPath).writeAsString('');

  final files = await listStaticPublishedFiles(artifactResult.appArtifactsPath);
  files.addAll(<File>[File(instructionsPath), File(nojekyllPath)]);
  final writtenFiles = buildStaticPublishedFileRecords(
    outputPath: outputPath,
    files: files,
  );

  return MiniProgramStaticPublishResult(
    outputPath: outputPath,
    miniProgramId: artifactResult.buildResult.miniProgramId,
    version: artifactResult.version,
    buildResult: artifactResult.buildResult,
    manifestLatestPath: artifactResult.latestManifestPath,
    manifestVersionPath: p.join(
      artifactResult.versionArtifactsPath,
      'manifest.json',
    ),
    screensDirectoryPath: p.join(
      artifactResult.versionArtifactsPath,
      'screens',
    ),
    assetsDirectoryPath: p.join(artifactResult.versionArtifactsPath, 'assets'),
    metadataReleasePath: p.join(
      artifactResult.versionArtifactsPath,
      'release.json',
    ),
    metadataCatalogPath: artifactResult.catalogPath,
    instructionsPath: instructionsPath,
    nojekyllPath: nojekyllPath,
    publishedAtUtc: DateTime.now().toUtc().toIso8601String(),
    writtenFiles: writtenFiles,
    cleaned: request.clean,
  );
}
