import 'mini_program_builder.dart';
import 'publishing/static/coordinator.dart';
import 'publishing/static/dependencies.dart';
import 'publishing/static/models.dart';

export 'publishing/static/models.dart'
    show
        MiniProgramStaticPublishRequest,
        MiniProgramStaticPublishResult,
        StaticPublishedFileRecord;

/// Legacy directory adapter over the canonical portable artifact builder.
///
/// New workflows should use `miniprogram artifact build` and copy the generated
/// `artifacts/` directory manually. This adapter remains for existing scripts.
class MiniProgramStaticPublisher {
  const MiniProgramStaticPublisher({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
  }) : _builder = builder;

  final MiniProgramBuilder _builder;

  Future<MiniProgramStaticPublishResult> publish(
    MiniProgramStaticPublishRequest request,
  ) => publishStaticMiniProgram(
    request,
    dependencies: StaticPublishingDependencies(builder: _builder),
  );
}
