import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host authority for plain-text clipboard access. Reads require independent
/// opt-in, even when writing has been accepted.
@immutable
class MiniProgramClipboardPolicy {
  const MiniProgramClipboardPolicy({
    this.enabled = false,
    this.allowRead = false,
    this.allowWrite = true,
    this.maxTextLength = miniProgramClipboardMaxTextLength,
  }) : assert(maxTextLength > 0),
       assert(maxTextLength <= miniProgramClipboardMaxTextLength);

  final bool enabled;
  final bool allowRead;
  final bool allowWrite;
  final int maxTextLength;

  @override
  bool operator ==(Object other) =>
      other is MiniProgramClipboardPolicy &&
      enabled == other.enabled &&
      allowRead == other.allowRead &&
      allowWrite == other.allowWrite &&
      maxTextLength == other.maxTextLength;
  @override
  int get hashCode =>
      Object.hash(enabled, allowRead, allowWrite, maxTextLength);
}

abstract interface class MiniProgramClipboardPolicyProvider {
  MiniProgramClipboardPolicy clipboardPolicyFor(String miniProgramId);
}

/// Trusted host implementation. Read only plain text without coercing a URI or
/// Intent; enforce [maxTextLength] before returning data across the channel.
abstract interface class MiniProgramClipboardProvider {
  Future<String?> readText({
    required String miniProgramId,
    required int maxTextLength,
  });
  Future<void> writeText({
    required String miniProgramId,
    required String text,
    required bool sensitive,
  });
}

/// Host authority for one bounded system haptic effect per user action.
@immutable
class MiniProgramVibrationPolicy {
  const MiniProgramVibrationPolicy({this.enabled = false});
  final bool enabled;
  @override
  bool operator ==(Object other) =>
      other is MiniProgramVibrationPolicy && enabled == other.enabled;
  @override
  int get hashCode => enabled.hashCode;
}

abstract interface class MiniProgramVibrationPolicyProvider {
  MiniProgramVibrationPolicy vibrationPolicyFor(String miniProgramId);
}

/// Honors system haptic settings and never starts a repeating vibration.
abstract interface class MiniProgramVibrationProvider {
  Future<bool> trigger({
    required String miniProgramId,
    required MiniProgramVibrationEffect effect,
  });
}

/// Host authority to open a dialer with an ordinary telephone number.
@immutable
class MiniProgramPhonePolicy {
  const MiniProgramPhonePolicy({this.enabled = false});
  final bool enabled;
  @override
  bool operator ==(Object other) =>
      other is MiniProgramPhonePolicy && enabled == other.enabled;
  @override
  int get hashCode => enabled.hashCode;
}

abstract interface class MiniProgramPhonePolicyProvider {
  MiniProgramPhonePolicy phonePolicyFor(String miniProgramId);
}

/// Opens the system dialer. A successful result means UI was opened, not that
/// the user placed or completed a call. Never use direct-call APIs.
abstract interface class MiniProgramPhoneProvider {
  Future<void> openDialer({
    required String miniProgramId,
    required String number,
  });
}

/// Sanitized native failure for clipboard, haptics or dialer operations.
class MiniProgramSystemException implements Exception {
  const MiniProgramSystemException({
    required this.errorCode,
    required this.message,
  });
  final String errorCode;
  final String message;
  @override
  String toString() => message;
}
