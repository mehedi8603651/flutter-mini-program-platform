import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('doctor public API remains available from the barrel', () {
    const doctor = MiniprogramDoctor();
    const check = MiniprogramDoctorCheck(
      label: 'Flutter CLI',
      status: MiniprogramDoctorCheckStatus.ok,
      summary: 'Flutter 3.35.0',
    );
    const result = MiniprogramDoctorResult(
      checks: <MiniprogramDoctorCheck>[check],
    );
    DoctorShellRunner runner = _shellRunner;

    expect(doctor, isA<MiniprogramDoctor>());
    expect(result.hasErrors, isFalse);
    expect(runner, isA<DoctorShellRunner>());
  });
}

Future<ProcessResult> _shellRunner(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async => ProcessResult(1, 0, 'ok', '');
