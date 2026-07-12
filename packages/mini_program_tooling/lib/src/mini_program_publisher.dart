import 'dart:io';

import 'package:path/path.dart' as p;

import 'delivery_validation.dart';
import 'delivery_validator.dart';
import 'mini_program_artifacts.dart';
import 'mini_program_builder.dart';

class MiniProgramPublishRequest {
  const MiniProgramPublishRequest({
    required this.repoRootPath,
    this.backendRootPath,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.mpBuildScriptPath,
    this.skipBuildPubGet = false,
  });

  final String repoRootPath;
  final String? backendRootPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
  final String? mpBuildScriptPath;
  final bool skipBuildPubGet;
}

class MiniProgramPublishResult {
  const MiniProgramPublishResult({
    required this.repoRootPath,
    required this.backendRootPath,
    required this.miniProgramId,
    required this.version,
    required this.buildResult,
    required this.prePublishValidation,
    required this.postPublishValidation,
    required this.latestManifestPath,
    required this.versionedManifestPath,
    required this.screensDirectoryPath,
    required this.copiedScreenCount,
  });

  final String repoRootPath;
  final String backendRootPath;
  final String miniProgramId;
  final String version;
  final MiniProgramBuildResult buildResult;
  final DeliveryValidationReport prePublishValidation;
  final DeliveryValidationReport postPublishValidation;
  final String latestManifestPath;
  final String versionedManifestPath;
  final String screensDirectoryPath;
  final int copiedScreenCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoRootPath': repoRootPath,
    'backendRootPath': backendRootPath,
    'miniProgramId': miniProgramId,
    'version': version,
    'buildResult': buildResult.toJson(),
    'prePublishValidation': prePublishValidation.toJson(),
    'postPublishValidation': postPublishValidation.toJson(),
    'latestManifestPath': latestManifestPath,
    'versionedManifestPath': versionedManifestPath,
    'screensDirectoryPath': screensDirectoryPath,
    'copiedScreenCount': copiedScreenCount,
  };
}

class MiniProgramPublishException implements Exception {
  const MiniProgramPublishException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramPublisher {
  const MiniProgramPublisher({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
  }) : _builder = builder,
       _validator = validator;

  final MiniProgramBuilder _builder;
  final DeliveryRepositoryValidator _validator;

  Future<MiniProgramPublishResult> publish(
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

    final buildResult = await _builder.build(
      MiniProgramBuildRequest(
        repoRootPath: repoRootPath,
        miniProgramId: request.miniProgramId,
        miniProgramRootPath: request.miniProgramRootPath,
        mpBuildScriptPath: request.mpBuildScriptPath,
        skipPubGet: request.skipBuildPubGet,
      ),
    );
    final preValidation = await _validator.validate(
      repoRootPath: backendRootPath,
      authoredRepoRootPath: repoRootPath,
      backendRootPath: backendRootPath,
      miniProgramId: buildResult.miniProgramId,
      externalMiniProgramRootPath: request.miniProgramRootPath,
    );
    if (preValidation.hasErrors) {
      throw MiniProgramPublishException(
        'Delivery validation failed before publish for '
        '${buildResult.miniProgramId}.\n'
        '${formatDeliveryValidationReport(preValidation)}',
      );
    }

    late final MiniProgramArtifactBuildResult artifactResult;
    try {
      artifactResult =
          await MiniProgramArtifactBuilder(
            builder: _CompletedMiniProgramBuilder(buildResult),
          ).build(
            MiniProgramArtifactBuildRequest(
              repoRootPath: repoRootPath,
              miniProgramId: buildResult.miniProgramId,
              miniProgramRootPath: buildResult.miniProgramRootPath,
              artifactsRootPath: p.join(backendApiPath, 'artifacts'),
              skipPubGet: true,
            ),
          );
    } on MiniProgramArtifactException catch (error) {
      throw MiniProgramPublishException(error.toString());
    }

    final postValidation = await _validator.validate(
      repoRootPath: backendRootPath,
      authoredRepoRootPath: repoRootPath,
      backendRootPath: backendRootPath,
      miniProgramId: buildResult.miniProgramId,
      externalMiniProgramRootPath: request.miniProgramRootPath,
    );
    if (postValidation.hasErrors) {
      throw MiniProgramPublishException(
        'Delivery validation failed after publish for '
        '${buildResult.miniProgramId}.\n'
        '${formatDeliveryValidationReport(postValidation)}',
      );
    }

    final screensDirectoryPath = p.join(
      artifactResult.versionArtifactsPath,
      'screens',
    );
    final copiedScreenCount = await Directory(screensDirectoryPath)
        .list(followLinks: false)
        .where(
          (entity) => entity is File && p.extension(entity.path) == '.json',
        )
        .length;

    return MiniProgramPublishResult(
      repoRootPath: repoRootPath,
      backendRootPath: backendRootPath,
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
}

class _CompletedMiniProgramBuilder extends MiniProgramBuilder {
  const _CompletedMiniProgramBuilder(this.result);

  final MiniProgramBuildResult result;

  @override
  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) async =>
      result;
}
