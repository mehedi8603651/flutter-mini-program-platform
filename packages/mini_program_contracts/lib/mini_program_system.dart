/// Maximum plain-text clipboard length across the wire (UTF-16 code units).
const int miniProgramClipboardMaxTextLength = 32768;

/// Short system haptic effects; arbitrary durations and repeating patterns are
/// intentionally unavailable. The operating system owns strength and settings.
enum MiniProgramVibrationEffect {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
}

/// Normalizes an ordinary phone number for a user-controlled system dialer.
/// Rejects schemes, extensions, pauses, USSD/MMI codes and control characters.
String normalizeMiniProgramPhoneNumber(String value) {
  if (value.length > 64 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) ||
      !RegExp(r'^[+0-9(). -]+$').hasMatch(value)) {
    throw const FormatException('Provide an ordinary phone number.');
  }
  final number = value.trim();
  if (number.isEmpty ||
      number.length > 64 ||
      !RegExp(r'^[+0-9(). -]+$').hasMatch(number)) {
    throw const FormatException('Provide an ordinary phone number.');
  }
  final normalized = number.replaceAll(RegExp(r'[(). -]'), '');
  if (!RegExp(r'^\+?[0-9]{1,32}$').hasMatch(normalized)) {
    throw const FormatException('Phone numbers require 1-32 digits.');
  }
  return normalized;
}
