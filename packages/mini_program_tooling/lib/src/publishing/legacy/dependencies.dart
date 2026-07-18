import '../../delivery_validator.dart';
import '../../mini_program_builder.dart';

class LegacyPublishingDependencies {
  const LegacyPublishingDependencies({
    required this.builder,
    required this.validator,
  });

  final MiniProgramBuilder builder;
  final DeliveryRepositoryValidator validator;
}
