import 'dart:io';

import 'package:path/path.dart' as p;

import '../local_cli_state.dart';
import 'backend_checks.dart';
import 'command_probes.dart';
import 'dependencies.dart';
import 'models.dart';
import 'repository_checks.dart';
import 'workspace_checks.dart';

Future<MiniprogramDoctorResult> diagnoseMiniprogramEnvironment(
  DoctorDependencies dependencies, {
  String? explicitRepoRootPath,
}) async {
  final checks = <MiniprogramDoctorCheck>[];
  final cwd = p.normalize(
    p.absolute(dependencies.workingDirectory ?? Directory.current.path),
  );

  checks.add(
    MiniprogramDoctorCheck(
      label: 'Dart SDK',
      status: MiniprogramDoctorCheckStatus.ok,
      summary: Platform.version.split(' ').first,
      detail: 'Running from ${Platform.resolvedExecutable}',
    ),
  );
  checks.add(
    await probeDoctorCommand(
      dependencies,
      label: 'Flutter CLI',
      executable: 'flutter',
      arguments: const <String>['--version'],
      missingSummary: 'Flutter was not found on PATH.',
      missingDetail:
          'Install Flutter and ensure the `flutter` executable is available '
          'on PATH.',
    ),
  );

  final environment = await inspectDoctorEnvironment(
    dependencies,
    currentWorkingDirectory: cwd,
  );
  checks.add(environment.check);

  final repository = await inspectDoctorRepository(
    dependencies,
    currentWorkingDirectory: cwd,
    explicitRepoRootPath: explicitRepoRootPath,
    configuredRepoRootPath: environment.state?.state.repoRootPath,
  );
  checks.add(repository.check);

  ResolvedLocalBackendWorkspaceState? backendWorkspaceState;
  try {
    backendWorkspaceState = await resolveUsableDoctorBackendWorkspace(
      dependencies,
      currentWorkingDirectory: cwd,
      additionalSearchRoots: <String>[
        if (repository.repoRootPath != null) repository.repoRootPath!,
        if (environment.state?.state.repoRootPath case final repoRoot?)
          repoRoot,
      ],
    );
  } on LocalCliStateException catch (error) {
    checks.add(
      MiniprogramDoctorCheck(
        label: 'Artifact host workspace',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'Failed to read artifact host workspace configuration.',
        detail: error.message,
      ),
    );
  }

  final backendRootPath =
      backendWorkspaceState?.state.backendRootPath ?? repository.repoRootPath;
  if (backendRootPath == null) {
    checks.add(missingDoctorBackendWorkspaceCheck());
    checks.add(skippedDoctorBackendStatusCheck());
    return MiniprogramDoctorResult(checks: checks);
  }

  checks.add(
    await inspectDoctorBackendWorkspace(
      backendRootPath: backendRootPath,
      backendWorkspaceState: backendWorkspaceState,
    ),
  );
  checks.add(
    await inspectDoctorBackendStatus(
      dependencies,
      backendRootPath: backendRootPath,
    ),
  );

  return MiniprogramDoctorResult(checks: checks);
}
