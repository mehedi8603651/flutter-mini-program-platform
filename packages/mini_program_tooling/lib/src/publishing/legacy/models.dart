import '../../delivery_validation.dart';
import '../../mini_program_builder.dart';

export '../shared/errors.dart' show MiniProgramPublishException;

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
