enum ValidationSeverity { error, warning }

class DeliveryValidationMessage {
  const DeliveryValidationMessage({
    required this.severity,
    required this.code,
    required this.path,
    required this.message,
  });

  final ValidationSeverity severity;
  final String code;
  final String path;
  final String message;

  bool get isError => severity == ValidationSeverity.error;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'severity': severity.name,
    'code': code,
    'path': path,
    'message': message,
  };
}

class DeliveryValidationReport {
  const DeliveryValidationReport({
    required this.repoRootPath,
    required this.messages,
  });

  final String repoRootPath;
  final List<DeliveryValidationMessage> messages;

  int get errorCount => messages.where((message) => message.isError).length;

  int get warningCount => messages.length - errorCount;

  bool get hasErrors => errorCount > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoRootPath': repoRootPath,
    'errorCount': errorCount,
    'warningCount': warningCount,
    'messages': messages.map((message) => message.toJson()).toList(),
  };
}

String formatDeliveryValidationReport(DeliveryValidationReport report) {
  final lines = <String>[
    'Repo root: ${report.repoRootPath}',
    'Errors: ${report.errorCount}',
    'Warnings: ${report.warningCount}',
  ];

  if (report.messages.isEmpty) {
    lines.add('Validation passed with no findings.');
    return lines.join('\n');
  }

  for (final message in report.messages) {
    lines.add(
      '[${message.severity.name}] ${message.code} ${message.path}: ${message.message}',
    );
  }

  return lines.join('\n');
}
