import 'dependencies.dart';

Future<void> inspectWorkflowValidation(
  WorkflowStatusDependencies dependencies, {
  required String workspacePath,
  required Map<String, Object?> workspace,
  required Map<String, Object?> miniProgram,
  required Map<String, Object?> backend,
}) async {
  if (workspace['type'] != 'mini_program') {
    return;
  }
  final appId = miniProgram['appId']?.toString();
  final backendRootPath = backend['backendRootPath']?.toString();
  if (appId == null || appId.isEmpty || backendRootPath == null) {
    miniProgram['validation'] = <String, Object?>{
      'status': 'not_run',
      'reason': 'No local artifact host workspace was found for validation.',
    };
    return;
  }
  try {
    final report = await dependencies.validator.validate(
      repoRootPath: backendRootPath,
      authoredRepoRootPath: workspacePath,
      backendRootPath: backendRootPath,
      miniProgramId: appId,
      externalMiniProgramRootPath: workspacePath,
    );
    miniProgram['validation'] = <String, Object?>{
      'status': report.hasErrors
          ? 'error'
          : report.warningCount > 0
          ? 'warning'
          : 'ok',
      'errorCount': report.errorCount,
      'warningCount': report.warningCount,
    };
  } catch (error) {
    miniProgram['validation'] = <String, Object?>{
      'status': 'error',
      'reason': error.toString(),
    };
  }
}
