import '../core/mp_node.dart';
import 'mp_schema.dart';

/// Builds a root Mp node for a screen.
typedef MpScreenBuilder = MpNode Function();

/// Explicit screen registry for a mini-program.
final class MpProgram {
  /// Creates an Mp program from a deterministic screen registry.
  MpProgram({required Map<String, MpScreenBuilder> screens})
    : screens = Map<String, MpScreenBuilder>.unmodifiable(
        _normalizeScreens(screens),
      );

  /// Registered screen builders keyed by screen ID.
  final Map<String, MpScreenBuilder> screens;

  /// Builds deterministic JSON documents for all registered screens.
  Map<String, Map<String, Object?>> buildScreensJson() {
    return <String, Map<String, Object?>>{
      for (final entry in screens.entries)
        entry.key: MpScreenDocument(
          screenId: entry.key,
          root: entry.value(),
        ).toJson(),
    };
  }

  static Map<String, MpScreenBuilder> _normalizeScreens(
    Map<String, MpScreenBuilder> screens,
  ) {
    if (screens.isEmpty) {
      throw ArgumentError.value(
        screens,
        'screens',
        'MpProgram must register at least one screen.',
      );
    }

    for (final screenId in screens.keys) {
      MpSchema.validateScreenId(screenId);
    }

    return screens;
  }
}

/// Versioned Mp screen document.
final class MpScreenDocument {
  /// Creates a versioned Mp screen document.
  MpScreenDocument({required this.screenId, required this.root}) {
    MpSchema.validateScreenId(screenId);
  }

  /// Stable schema version for this screen document.
  final int schemaVersion = MpSchema.schemaVersion;

  /// Screen ID matching the manifest entry or navigation target.
  final String screenId;

  /// Root widget node.
  final MpNode root;

  /// Serializes this screen document.
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'screenId': screenId,
    'root': root.toJson(),
  };
}
