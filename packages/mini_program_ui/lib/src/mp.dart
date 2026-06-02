import 'mp_action.dart';
import 'mp_node.dart';

/// Author-friendly namespace for Mp widget and action builders.
abstract final class Mp {
  /// Email authentication actions.
  static const auth = MpAuthActions();

  /// Creates a vertical layout.
  static MpNode column({required List<MpNode> children}) =>
      MpNode('column', children: children);

  /// Creates a horizontal layout.
  static MpNode row({required List<MpNode> children}) =>
      MpNode('row', children: children);

  /// Creates body text.
  static MpNode text(String data) =>
      MpNode('text', props: <String, Object?>{'data': data});

  /// Creates heading text.
  static MpNode heading(String data) =>
      MpNode('heading', props: <String, Object?>{'data': data});

  /// Creates fixed empty space.
  static MpNode sizedBox({num? width, num? height}) {
    if (width == null && height == null) {
      throw ArgumentError('Provide width, height, or both for Mp.sizedBox.');
    }
    return MpNode(
      'sizedBox',
      props: <String, Object?>{
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      },
    );
  }

  /// Creates an image node.
  static MpNode image({required String src, String? alt}) => MpNode(
    'image',
    props: <String, Object?>{'src': src, if (alt != null) 'alt': alt},
  );

  /// Creates a simple card container.
  static MpNode card({required MpNode child}) =>
      MpNode('card', children: <MpNode>[child]);

  /// Creates the primary button style.
  static MpNode primaryButton({
    required String label,
    required MpAction action,
  }) => MpNode(
    'primaryButton',
    props: <String, Object?>{'label': label, 'action': action},
  );

  /// Creates the secondary button style.
  static MpNode secondaryButton({
    required String label,
    required MpAction action,
  }) => MpNode(
    'secondaryButton',
    props: <String, Object?>{'label': label, 'action': action},
  );
}

/// Email authentication action builders.
final class MpAuthActions {
  /// Creates email authentication action helpers.
  const MpAuthActions();

  /// Shows the SDK-owned email/password auth sheet.
  MpAction showEmailAuth() => MpAction('auth.showEmailAuth');
}
