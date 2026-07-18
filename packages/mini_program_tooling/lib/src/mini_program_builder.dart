import 'build_pipeline/coordinator.dart';
import 'build_pipeline/models.dart';
import 'build_pipeline/process.dart';

export 'build_pipeline/models.dart'
    show
        MiniProgramBuildException,
        MiniProgramBuildRequest,
        MiniProgramBuildResult,
        ProcessRunner;

/// Public compatibility facade for development-output builds.
class MiniProgramBuilder {
  const MiniProgramBuilder({
    ProcessRunner processRunner = defaultMiniProgramBuildProcessRunner,
  }) : _processRunner = processRunner;

  final ProcessRunner _processRunner;

  Future<MiniProgramBuildResult> build(MiniProgramBuildRequest request) =>
      buildMiniProgramDevelopmentOutput(request, processRunner: _processRunner);
}
