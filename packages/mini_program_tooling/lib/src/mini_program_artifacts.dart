import 'artifact_pipeline/build/coordinator.dart';
import 'artifact_pipeline/models.dart';
import 'artifact_pipeline/shared/constants.dart' as artifact_constants;
import 'artifact_pipeline/verify/coordinator.dart';
import 'mini_program_builder.dart';

export 'artifact_pipeline/models.dart'
    show
        MiniProgramArtifactBuildRequest,
        MiniProgramArtifactBuildResult,
        MiniProgramArtifactErrorCodes,
        MiniProgramArtifactException,
        MiniProgramArtifactVerifyRequest,
        MiniProgramArtifactVerifyResult;

class MiniProgramArtifactBuilder {
  const MiniProgramArtifactBuilder({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
  }) : _builder = builder;

  static const int artifactLayoutVersion =
      artifact_constants.artifactLayoutVersion;

  final MiniProgramBuilder _builder;

  Future<MiniProgramArtifactBuildResult> build(
    MiniProgramArtifactBuildRequest request,
  ) {
    return buildPortableMiniProgramArtifact(_builder, request);
  }
}

class MiniProgramArtifactVerifier {
  const MiniProgramArtifactVerifier();

  Future<MiniProgramArtifactVerifyResult> verify(
    MiniProgramArtifactVerifyRequest request,
  ) {
    return verifyPortableMiniProgramArtifact(request);
  }
}
