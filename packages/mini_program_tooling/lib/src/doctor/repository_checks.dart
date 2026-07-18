import '../mini_program_path_resolver.dart';
import 'dependencies.dart';
import 'models.dart';

class DoctorRepositoryInspection {
  const DoctorRepositoryInspection({required this.check, this.repoRootPath});

  final MiniprogramDoctorCheck check;
  final String? repoRootPath;
}

Future<DoctorRepositoryInspection> inspectDoctorRepository(
  DoctorDependencies dependencies, {
  required String currentWorkingDirectory,
  required String? explicitRepoRootPath,
  required String? configuredRepoRootPath,
}) async {
  try {
    final repoRootPath = await dependencies.pathResolver.resolveRepoRoot(
      explicitRepoRootPath: explicitRepoRootPath ?? configuredRepoRootPath,
      currentWorkingDirectory: currentWorkingDirectory,
      additionalSearchPath: configuredRepoRootPath,
    );
    if (repoRootPath == null) {
      return const DoctorRepositoryInspection(
        check: MiniprogramDoctorCheck(
          label: 'Platform repo',
          status: MiniprogramDoctorCheckStatus.skipped,
          summary: 'Platform repo root is not configured.',
          detail:
              'Standalone CLI workflows can continue without it. Older '
              'repo-managed commands can still pass `--repo-root` when '
              'needed.',
        ),
      );
    }

    return DoctorRepositoryInspection(
      repoRootPath: repoRootPath,
      check: MiniprogramDoctorCheck(
        label: 'Platform repo',
        status: MiniprogramDoctorCheckStatus.ok,
        summary: repoRootPath,
      ),
    );
  } on MiniProgramPathResolutionException catch (error) {
    return DoctorRepositoryInspection(
      check: MiniprogramDoctorCheck(
        label: 'Platform repo',
        status: MiniprogramDoctorCheckStatus.error,
        summary: 'Platform repo resolution failed.',
        detail: error.message,
      ),
    );
  }
}
