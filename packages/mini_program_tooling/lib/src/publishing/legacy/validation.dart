import '../../delivery_validation.dart';
import '../../delivery_validator.dart';
import 'models.dart';

enum LegacyPublishingValidationStage { beforePublish, afterPublish }

Future<DeliveryValidationReport> validateLegacyPublishing({
  required DeliveryRepositoryValidator validator,
  required LegacyPublishingValidationStage stage,
  required String repoRootPath,
  required String backendRootPath,
  required String miniProgramId,
  required String? externalMiniProgramRootPath,
}) async {
  final report = await validator.validate(
    repoRootPath: backendRootPath,
    authoredRepoRootPath: repoRootPath,
    backendRootPath: backendRootPath,
    miniProgramId: miniProgramId,
    externalMiniProgramRootPath: externalMiniProgramRootPath,
  );
  if (report.hasErrors) {
    final stageLabel = switch (stage) {
      LegacyPublishingValidationStage.beforePublish => 'before publish',
      LegacyPublishingValidationStage.afterPublish => 'after publish',
    };
    throw MiniProgramPublishException(
      'Delivery validation failed $stageLabel for $miniProgramId.\n'
      '${formatDeliveryValidationReport(report)}',
    );
  }
  return report;
}
