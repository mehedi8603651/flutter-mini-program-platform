import 'host_endpoint/coordinator.dart';
import 'host_endpoint/models.dart';
import 'host_endpoint/runner.dart';

export 'host_endpoint/models.dart'
    show
        MiniProgramHostEndpointAddRequest,
        MiniProgramHostEndpointAddResult,
        MiniProgramHostException,
        MiniProgramHostProcessRunner,
        MiniProgramHostRunRequest,
        MiniProgramHostRunResult;

class MiniProgramHostController {
  MiniProgramHostController({
    MiniProgramHostProcessRunner processRunner =
        defaultMiniProgramHostProcessRunner,
  }) : _processRunner = processRunner;

  final MiniProgramHostProcessRunner _processRunner;

  Future<MiniProgramHostRunResult> run(MiniProgramHostRunRequest request) {
    return runMiniProgramHost(request, processRunner: _processRunner);
  }

  Future<MiniProgramHostEndpointAddResult> addEndpoint(
    MiniProgramHostEndpointAddRequest request,
  ) {
    return addMiniProgramHostEndpoint(request);
  }
}
