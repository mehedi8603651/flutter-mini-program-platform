import '../../mini_program_builder.dart';

class MiniProgramStaticPublishRequest {
  const MiniProgramStaticPublishRequest({
    required this.repoRootPath,
    required this.outputPath,
    this.miniProgramId,
    this.miniProgramRootPath,
    this.mpBuildScriptPath,
    this.skipBuildPubGet = false,
    this.clean = false,
  });

  final String repoRootPath;
  final String outputPath;
  final String? miniProgramId;
  final String? miniProgramRootPath;
  final String? mpBuildScriptPath;
  final bool skipBuildPubGet;
  final bool clean;
}

class StaticPublishedFileRecord {
  const StaticPublishedFileRecord({
    required this.relativePath,
    required this.localSourcePath,
  });

  final String relativePath;
  final String localSourcePath;
}

class MiniProgramStaticPublishResult {
  const MiniProgramStaticPublishResult({
    required this.outputPath,
    required this.miniProgramId,
    required this.version,
    required this.buildResult,
    required this.manifestLatestPath,
    required this.manifestVersionPath,
    required this.screensDirectoryPath,
    required this.metadataReleasePath,
    required this.metadataCatalogPath,
    required this.instructionsPath,
    required this.nojekyllPath,
    required this.publishedAtUtc,
    required this.writtenFiles,
    this.cleaned = false,
    this.assetsDirectoryPath,
  });

  final String outputPath;
  final String miniProgramId;
  final String version;
  final MiniProgramBuildResult buildResult;
  final String manifestLatestPath;
  final String manifestVersionPath;
  final String screensDirectoryPath;
  final String? assetsDirectoryPath;
  final String metadataReleasePath;
  final String metadataCatalogPath;
  final String instructionsPath;
  final String nojekyllPath;
  final String publishedAtUtc;
  final List<StaticPublishedFileRecord> writtenFiles;
  final bool cleaned;
}
