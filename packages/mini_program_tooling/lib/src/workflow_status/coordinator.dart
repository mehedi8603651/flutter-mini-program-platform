import 'package:path/path.dart' as p;

import 'assessment.dart';
import 'dependencies.dart';
import 'environment_backend.dart';
import 'host_app.dart';
import 'mini_program.dart';
import 'models.dart';
import 'validation.dart';
import 'workspace.dart';

Future<MiniProgramWorkflowStatusResult> inspectMiniProgramWorkflowStatus(
  WorkflowStatusDependencies dependencies,
  MiniProgramWorkflowStatusRequest request,
) async {
  final workspacePath = p.normalize(p.absolute(request.workspacePath));
  final generatedAtUtc = DateTime.now().toUtc().toIso8601String();
  final workspace = await inspectWorkflowWorkspace(workspacePath);
  final miniProgram = await inspectWorkflowMiniProgram(
    workspacePath,
    workspace,
  );
  final hostApp = await inspectWorkflowHostApp(workspacePath, workspace);
  final environment = await inspectWorkflowEnvironment(
    dependencies,
    workspacePath: workspacePath,
    explicitEnvironmentName: request.environmentName,
  );
  final backend = await inspectWorkflowBackend(dependencies, workspacePath);
  await inspectWorkflowValidation(
    dependencies,
    workspacePath: workspacePath,
    workspace: workspace,
    miniProgram: miniProgram,
    backend: backend,
  );
  final remote = inspectWorkflowRemote(request.remote);
  final nextActions = buildWorkflowNextActions(
    workspace: workspace,
    miniProgram: miniProgram,
    hostApp: hostApp,
    environment: environment,
    remote: remote,
  );
  final severity = computeWorkflowSeverity(
    workspace: workspace,
    miniProgram: miniProgram,
    hostApp: hostApp,
    environment: environment,
    remote: remote,
  );
  final ready = severity == 'ok';

  return MiniProgramWorkflowStatusResult(<String, Object?>{
    'schemaVersion': 1,
    'command': 'workflow status',
    'generatedAtUtc': generatedAtUtc,
    'workspace': workspace,
    'environment': environment,
    'miniProgram': miniProgram,
    'hostApp': hostApp,
    'backend': backend,
    'remote': remote,
    'ready': ready,
    'severity': severity,
    'nextActions': nextActions,
  });
}
