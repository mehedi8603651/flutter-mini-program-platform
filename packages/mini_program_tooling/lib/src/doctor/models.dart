enum MiniprogramDoctorCheckStatus { ok, warning, error, skipped }

class MiniprogramDoctorCheck {
  const MiniprogramDoctorCheck({
    required this.label,
    required this.status,
    required this.summary,
    this.detail,
  });

  final String label;
  final MiniprogramDoctorCheckStatus status;
  final String summary;
  final String? detail;
}

class MiniprogramDoctorResult {
  const MiniprogramDoctorResult({required this.checks});

  final List<MiniprogramDoctorCheck> checks;

  bool get hasErrors =>
      checks.any((check) => check.status == MiniprogramDoctorCheckStatus.error);
}
