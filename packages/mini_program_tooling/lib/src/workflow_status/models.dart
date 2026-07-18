class MiniProgramWorkflowStatusRequest {
  const MiniProgramWorkflowStatusRequest({
    required this.workspacePath,
    this.environmentName,
    this.remote = false,
  });

  final String workspacePath;
  final String? environmentName;
  final bool remote;
}

class MiniProgramWorkflowStatusResult {
  const MiniProgramWorkflowStatusResult(this.json);

  final Map<String, Object?> json;

  bool get ready => json['ready'] == true;

  String get severity => json['severity']?.toString() ?? 'warning';
}
