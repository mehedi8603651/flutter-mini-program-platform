import 'scaffolding/coordinator.dart';
import 'scaffolding/models.dart';

export 'scaffolding/models.dart'
    show
        MiniProgramScaffoldException,
        MiniProgramScaffoldRequest,
        MiniProgramScaffoldResult;

/// Public compatibility facade for mini-program project scaffolding.
class MiniProgramScaffolder {
  const MiniProgramScaffolder();

  Future<MiniProgramScaffoldResult> scaffold(
    MiniProgramScaffoldRequest request,
  ) => scaffoldMiniProgram(request);
}
