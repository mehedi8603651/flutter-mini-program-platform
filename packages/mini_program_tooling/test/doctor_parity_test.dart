import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'doctor preserves ordered standalone diagnostics and command detail',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'miniprogram_doctor_parity_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final workspace = Directory(p.join(tempDirectory.path, 'workspace'));
      await workspace.create(recursive: true);
      final stateStore = LocalCliStateStore(
        homeDirectoryPath: p.join(tempDirectory.path, 'home'),
      );
      final doctor = MiniprogramDoctor(
        stateStore: stateStore,
        workingDirectory: workspace.path,
        shellRunner: _failingShellRunner,
      );

      final result = await doctor.diagnose();

      expect(
        result.checks
            .map(
              (check) => <Object?>[
                check.label,
                check.status,
                check.summary,
                check.detail,
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>[
            'Dart SDK',
            MiniprogramDoctorCheckStatus.ok,
            Platform.version.split(' ').first,
            'Running from ${Platform.resolvedExecutable}',
          ],
          <Object?>[
            'Flutter CLI',
            MiniprogramDoctorCheckStatus.warning,
            'Flutter was not found on PATH.',
            'flutter failed',
          ],
          <Object?>[
            'Env config',
            MiniprogramDoctorCheckStatus.warning,
            'No miniprogram env configuration was found.',
            'Run `miniprogram env init` from your mini-program workspace.',
          ],
          <Object?>[
            'Platform repo',
            MiniprogramDoctorCheckStatus.skipped,
            'Platform repo root is not configured.',
            'Standalone CLI workflows can continue without it. Older '
                'repo-managed commands can still pass `--repo-root` when needed.',
          ],
          <Object?>[
            'Artifact host workspace',
            MiniprogramDoctorCheckStatus.warning,
            'No artifact host workspace was found.',
            'Run `miniprogram artifact-host init` to scaffold a standalone '
                'local artifact host workspace.',
          ],
          <Object?>[
            'Artifact host status',
            MiniprogramDoctorCheckStatus.skipped,
            'Skipped because no artifact host workspace was resolved.',
            null,
          ],
        ],
      );
      expect(result.hasErrors, isFalse);
    },
  );
}

Future<ProcessResult> _failingShellRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async => ProcessResult(1, 1, 'flutter failed\nignored line', 'stderr line');
