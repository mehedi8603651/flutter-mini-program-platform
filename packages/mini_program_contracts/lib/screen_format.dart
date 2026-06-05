import 'package:json_annotation/json_annotation.dart';

/// Stable wire ID for a screen document format.
typedef MiniProgramScreenFormat = String;

/// Standard mini-program screen document formats.
abstract final class MiniProgramScreenFormats {
  /// Native Mp JSON screen documents.
  static const MiniProgramScreenFormat mp = 'mp';

  /// Returns whether [value] is a non-empty screen format ID.
  static bool isValid(MiniProgramScreenFormat value) => value.trim().isNotEmpty;

  /// Normalizes and validates a screen format ID.
  static MiniProgramScreenFormat normalize(MiniProgramScreenFormat value) {
    final normalized = value.trim();
    if (!isValid(normalized)) {
      throw FormatException('Invalid screen format "$value".');
    }
    return normalized;
  }
}

/// JSON converter that preserves unknown screen formats as strings.
class MiniProgramScreenFormatConverter
    implements JsonConverter<MiniProgramScreenFormat, Object?> {
  /// Creates a screen format converter.
  const MiniProgramScreenFormatConverter();

  @override
  MiniProgramScreenFormat fromJson(Object? json) {
    if (json == null) {
      return MiniProgramScreenFormats.mp;
    }
    if (json is String) {
      return MiniProgramScreenFormats.normalize(json);
    }
    throw const FormatException('Expected a screen format string.');
  }

  @override
  Object toJson(MiniProgramScreenFormat object) =>
      MiniProgramScreenFormats.normalize(object);
}
