import 'delivery_validator.dart';
import 'mini_program_builder.dart';
import 'publishing/legacy/coordinator.dart';
import 'publishing/legacy/dependencies.dart';
import 'publishing/legacy/models.dart';

export 'publishing/legacy/models.dart'
    show
        MiniProgramPublishException,
        MiniProgramPublishRequest,
        MiniProgramPublishResult;

class MiniProgramPublisher {
  const MiniProgramPublisher({
    MiniProgramBuilder builder = const MiniProgramBuilder(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
  }) : _builder = builder,
       _validator = validator;

  final MiniProgramBuilder _builder;
  final DeliveryRepositoryValidator _validator;

  Future<MiniProgramPublishResult> publish(MiniProgramPublishRequest request) =>
      publishLegacyMiniProgram(
        request,
        dependencies: LegacyPublishingDependencies(
          builder: _builder,
          validator: _validator,
        ),
      );
}
