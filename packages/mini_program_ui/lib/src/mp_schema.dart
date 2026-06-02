/// Mp JSON schema constants and validation helpers.
abstract final class MpSchema {
  /// Current Mp screen schema version.
  static const int schemaVersion = 1;

  static final RegExp _screenIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Validates a screen ID used by an Mp screen document.
  static void validateScreenId(String screenId) {
    if (!_screenIdPattern.hasMatch(screenId)) {
      throw ArgumentError.value(
        screenId,
        'screenId',
        r'Screen ID must match ^[a-z][a-z0-9_]*$',
      );
    }
  }
}
