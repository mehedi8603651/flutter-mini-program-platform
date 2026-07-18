import 'delivery_validator.dart';
import 'local_backend_controller.dart';
import 'local_cli_state.dart';
import 'workflow_status/coordinator.dart';
import 'workflow_status/dependencies.dart';
import 'workflow_status/environment_backend.dart';
import 'workflow_status/models.dart';

export 'workflow_status/models.dart'
    show MiniProgramWorkflowStatusRequest, MiniProgramWorkflowStatusResult;

/// Public compatibility facade for local workflow status inspection.
class MiniProgramWorkflowStatusController {
  const MiniProgramWorkflowStatusController({
    LocalCliStateStore stateStore = const LocalCliStateStore(),
    DeliveryRepositoryValidator validator = const DeliveryRepositoryValidator(),
    LocalBackendController backendController = const LocalBackendController(),
  }) : _stateStore = stateStore,
       _validator = validator,
       _backendController = backendController;

  final LocalCliStateStore _stateStore;
  final DeliveryRepositoryValidator _validator;
  final LocalBackendController _backendController;

  WorkflowStatusDependencies get _dependencies => WorkflowStatusDependencies(
    stateStore: _stateStore,
    validator: _validator,
    backendController: _backendController,
  );

  Future<MiniProgramWorkflowStatusResult> inspect(
    MiniProgramWorkflowStatusRequest request,
  ) => inspectMiniProgramWorkflowStatus(_dependencies, request);
}

Map<String, Object?> miniProgramWorkflowStatusBackendJson(
  LocalBackendStatusResult result,
) => workflowStatusBackendJson(result);
