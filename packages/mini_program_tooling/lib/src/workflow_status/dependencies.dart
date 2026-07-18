import '../delivery_validator.dart';
import '../local_backend_controller.dart';
import '../local_cli_state.dart';

class WorkflowStatusDependencies {
  const WorkflowStatusDependencies({
    required this.stateStore,
    required this.validator,
    required this.backendController,
  });

  final LocalCliStateStore stateStore;
  final DeliveryRepositoryValidator validator;
  final LocalBackendController backendController;
}
