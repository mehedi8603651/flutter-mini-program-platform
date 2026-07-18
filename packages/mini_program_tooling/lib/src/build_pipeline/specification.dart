import 'models.dart';
import 'paths.dart';

class MiniProgramBuildSpecification {
  const MiniProgramBuildSpecification({
    required this.repoRootPath,
    required this.paths,
    required this.manifest,
    required this.command,
    required this.requestedMiniProgramId,
    required this.skipPubGet,
  });

  final String? repoRootPath;
  final MiniProgramBuildPaths paths;
  final MiniProgramBuildManifest manifest;
  final MiniProgramBuildCommand command;
  final String? requestedMiniProgramId;
  final bool skipPubGet;
}
