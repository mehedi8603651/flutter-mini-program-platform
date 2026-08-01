/// JSON-safe state returned by a trusted host flashlight provider.
class MiniProgramFlashlightStatus {
  const MiniProgramFlashlightStatus({
    required this.available,
    required this.enabled,
  });

  factory MiniProgramFlashlightStatus.fromJson(Map<String, dynamic> json) {
    final available = json['available'];
    final enabled = json['enabled'];
    if (available is! bool || enabled is! bool) {
      throw const FormatException('Invalid mini-program flashlight status.');
    }
    final status = MiniProgramFlashlightStatus(
      available: available,
      enabled: enabled,
    );
    status.validate();
    return status;
  }

  final bool available;
  final bool enabled;

  void validate() {
    if (!available && enabled) {
      throw const FormatException(
        'An unavailable flashlight cannot be enabled.',
      );
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return <String, dynamic>{'available': available, 'enabled': enabled};
  }
}
