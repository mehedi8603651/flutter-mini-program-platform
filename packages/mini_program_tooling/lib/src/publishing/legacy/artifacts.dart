import 'package:path/path.dart' as p;

import '../../mini_program_artifacts.dart';
import '../../mini_program_builder.dart';
import 'models.dart';

Future<MiniProgramArtifactBuildResult> buildLegacyPublishingArtifact({
  required String repoRootPath,
  required String backendApiPath,
  required MiniProgramBuildResult buildResult,
}) async {
  try {
    return await MiniProgramArtifactBuilder(
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
}

class _CompletedMiniProgramBuilder extends MiniProgramBuilder {
  const _CompletedMiniProgramBuilder(this.result);

  final MiniProgramBuildResult result;

  @override
  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) async =>
      result;
}
