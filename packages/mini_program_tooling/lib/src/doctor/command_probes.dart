import 'dart:io';

import 'dependencies.dart';
import 'models.dart';

Future<MiniprogramDoctorCheck> probeDoctorCommand(
  DoctorDependencies dependencies, {
  required String label,
  required String executable,
  required List<String> arguments,
  required String missingSummary,
  required String missingDetail,
}) async {
  try {
    final result = await dependencies.shellRunner(
      executable,
      arguments,
      workingDirectory: dependencies.workingDirectory,
    );
    if (result.exitCode != 0) {
      return MiniprogramDoctorCheck(
        label: label,
        status: MiniprogramDoctorCheckStatus.warning,
        summary: missingSummary,
        detail: extractDoctorCommandDetail(result) ?? missingDetail,
      );
    }

    return MiniprogramDoctorCheck(
      label: label,
      status: MiniprogramDoctorCheckStatus.ok,
      summary:
          extractDoctorCommandDetail(result) ?? '$executable is available.',
    );
  } on ProcessException catch (error) {
    return MiniprogramDoctorCheck(
      label: label,
      status: MiniprogramDoctorCheckStatus.warning,
      summary: missingSummary,
      detail: error.message.isEmpty ? missingDetail : error.message,
    );
  }
}

String? extractDoctorCommandDetail(ProcessResult result) {
  final combined = <String>[
    '${result.stdout}'.trim(),
    '${result.stderr}'.trim(),
  ].where((value) => value.isNotEmpty).join('\n').trim();
  if (combined.isEmpty) {
    return null;
  }

  final lines = combined
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  return lines.isEmpty ? null : lines.first;
}
