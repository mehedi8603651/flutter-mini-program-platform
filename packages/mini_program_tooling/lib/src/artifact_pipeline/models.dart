import '../mini_program_builder.dart';

abstract final class MiniProgramArtifactErrorCodes {
  static const buildFailed = 'artifact_build_failed';
  static const manifestInvalid = 'artifact_manifest_invalid';
  static const versionInvalid = 'artifact_version_invalid';
  static const versionConflict = 'artifact_version_conflict';
  static const structureInvalid = 'artifact_structure_invalid';
  static const fileMissing = 'artifact_file_missing';
  static const checksumMismatch = 'artifact_checksum_mismatch';
  static const latestInvalid = 'artifact_latest_invalid';
  static const publisherBackendInvalid = 'artifact_publisher_backend_invalid';
  static const pathUnsafe = 'artifact_path_unsafe';
  static const ioFailed = 'artifact_io_failed';
}

class MiniProgramArtifactException implements Exception {
  const MiniProgramArtifactException({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() => '[$code] $message';
}

class MiniProgramArtifactBuildRequest {
  const MiniProgramArtifactBuildRequest({
    this.repoRootPath,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.artifactsRootPath,
    this.mpBuildScriptPath,
    this.skipPubGet = false,
  });

  final String? repoRootPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
  final String? artifactsRootPath;
  final String? mpBuildScriptPath;
  final bool skipPubGet;
}

class MiniProgramArtifactBuildResult {
  const MiniProgramArtifactBuildResult({
    required this.buildResult,
    required this.artifactsRootPath,
    required this.appArtifactsPath,
    required this.versionArtifactsPath,
    required this.latestManifestPath,
    required this.catalogPath,
    required this.version,
    required this.fileCount,
    required this.totalBytes,
    required this.created,
    required this.latestUpdated,
  });

  final MiniProgramBuildResult buildResult;
  final String artifactsRootPath;
  final String appArtifactsPath;
  final String versionArtifactsPath;
  final String latestManifestPath;
  final String catalogPath;
  final String version;
  final int fileCount;
  final int totalBytes;
  final bool created;
  final bool latestUpdated;

  Map<String, Object?> toJson() => <String, Object?>{
    'appId': buildResult.miniProgramId,
    'version': version,
    'artifactsRootPath': artifactsRootPath,
    'appArtifactsPath': appArtifactsPath,
    'versionArtifactsPath': versionArtifactsPath,
    'latestManifestPath': latestManifestPath,
    'catalogPath': catalogPath,
    'fileCount': fileCount,
    'totalBytes': totalBytes,
    'created': created,
    'latestUpdated': latestUpdated,
    'build': buildResult.toJson(),
  };
}

class MiniProgramArtifactVerifyRequest {
  const MiniProgramArtifactVerifyRequest({
    required this.miniProgramRootPath,
    this.miniProgramId,
    this.artifactsRootPath,
  });

  final String miniProgramRootPath;
  final String? miniProgramId;
  final String? artifactsRootPath;
}

class MiniProgramArtifactVerifyResult {
  const MiniProgramArtifactVerifyResult({
    required this.artifactsRootPath,
    required this.appArtifactsPath,
    required this.miniProgramId,
    required this.latestVersion,
    required this.versions,
    required this.fileCount,
    required this.totalBytes,
  });

  final String artifactsRootPath;
  final String appArtifactsPath;
  final String miniProgramId;
  final String latestVersion;
  final List<String> versions;
  final int fileCount;
  final int totalBytes;

  Map<String, Object?> toJson() => <String, Object?>{
    'valid': true,
    'appId': miniProgramId,
    'latestVersion': latestVersion,
    'versions': versions,
    'artifactsRootPath': artifactsRootPath,
    'appArtifactsPath': appArtifactsPath,
    'fileCount': fileCount,
    'totalBytes': totalBytes,
  };
}
