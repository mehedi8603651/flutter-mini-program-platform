/// Supported interactions with a live, foreground mini-program interface.
/// These are UI operations, never arbitrary Mp actions or backend requests.
enum MiniProgramInteractionAction {
  tap,
  enterText,
  scrollUp,
  scrollDown,
  scrollLeft,
  scrollRight,
  increase,
  decrease,
  back;

  static MiniProgramInteractionAction parse(Object? value) {
    for (final action in values) {
      if (action.name == value) return action;
    }
    throw const FormatException('Unsupported interaction action.');
  }
}

/// A request bound to one observation of one mounted mini-program instance.
final class MiniProgramInteractionRequest {
  MiniProgramInteractionRequest({
    required String requestId,
    required String sessionId,
    required this.revision,
    required this.action,
    String? targetId,
    this.text,
  }) : requestId = _identifier(requestId),
       sessionId = _identifier(sessionId),
       targetId = targetId == null ? null : _identifier(targetId) {
    if (revision < 1 || revision > 9007199254740991) {
      throw const FormatException('Invalid interaction revision.');
    }
    if (action == MiniProgramInteractionAction.back) {
      if (targetId != null) {
        throw const FormatException('Back does not accept a target.');
      }
    } else if (targetId == null) {
      throw const FormatException('An interaction target is required.');
    }
    if (action == MiniProgramInteractionAction.enterText) {
      if (text == null || text!.length > maxTextLength) {
        throw const FormatException('Invalid interaction text.');
      }
    } else if (text != null) {
      throw const FormatException('Only enterText accepts text.');
    }
  }

  static const int maxTextLength = 4096;
  final String requestId;
  final String sessionId;
  final int revision;
  final MiniProgramInteractionAction action;
  final String? targetId;
  final String? text;

  factory MiniProgramInteractionRequest.fromJson(Map<String, dynamic> json) {
    if (json.keys.any(
          (key) => !const {
            'requestId',
            'sessionId',
            'revision',
            'action',
            'targetId',
            'text',
          }.contains(key),
        ) ||
        json['requestId'] is! String ||
        json['sessionId'] is! String ||
        json['revision'] is! int ||
        (json['targetId'] != null && json['targetId'] is! String) ||
        (json['text'] != null && json['text'] is! String)) {
      throw const FormatException('Invalid interaction request.');
    }
    return MiniProgramInteractionRequest(
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      revision: json['revision'] as int,
      action: MiniProgramInteractionAction.parse(json['action']),
      targetId: json['targetId'] as String?,
      text: json['text'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'sessionId': sessionId,
    'revision': revision,
    'action': action.name,
    if (targetId != null) 'targetId': targetId,
    if (text != null) 'text': text,
  };

  static String _identifier(String value) {
    if (!RegExp(r'^[a-zA-Z0-9_.:-]{1,128}$').hasMatch(value)) {
      throw const FormatException('Invalid interaction identifier.');
    }
    return value;
  }
}

/// Bounded, rendered information about one UI element. No action payloads,
/// hidden state, credentials or backend configuration are included.
final class MiniProgramInteractionNode {
  MiniProgramInteractionNode({
    required this.id,
    required this.role,
    required this.label,
    required List<MiniProgramInteractionAction> actions,
    this.parentId,
    this.value,
    this.hint,
    this.enabled = true,
    this.selected,
    this.checked,
    this.protected = false,
    this.maxLength,
  }) : actions = List.unmodifiable(actions);

  final String id;
  final String role;
  final String label;
  final String? parentId;
  final String? value;
  final String? hint;
  final bool enabled;
  final bool? selected;
  final bool? checked;
  final bool protected;
  final int? maxLength;
  final List<MiniProgramInteractionAction> actions;

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role,
    if (parentId != null) 'parentId': parentId,
    if (label.isNotEmpty) 'label': label,
    if (!protected && value != null) 'value': value,
    if (hint != null) 'hint': hint,
    if (!enabled) 'enabled': false,
    if (selected != null) 'selected': selected,
    if (checked != null) 'checked': checked,
    if (protected) 'protected': true,
    if (maxLength != null) 'maxLength': maxLength,
    if (actions.isNotEmpty) 'actions': actions.map((a) => a.name).toList(),
  };
}

/// One replaceable observation; a new observation supersedes older UI details.
final class MiniProgramInteractionSnapshot {
  MiniProgramInteractionSnapshot({
    required this.appId,
    required this.sessionId,
    required this.screenId,
    required this.revision,
    required this.status,
    required List<MiniProgramInteractionNode> nodes,
    this.canGoBack = false,
    this.truncated = false,
  }) : nodes = List.unmodifiable(nodes);

  final String appId;
  final String sessionId;
  final String screenId;
  final int revision;

  /// `ready`, `pending`, `blocked`, `hidden`, `unavailable`, or `disposed`.
  final String status;
  final List<MiniProgramInteractionNode> nodes;
  final bool canGoBack;
  final bool truncated;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'appId': appId,
    'sessionId': sessionId,
    'screenId': screenId,
    'revision': revision,
    'status': status,
    'canGoBack': canGoBack,
    if (truncated) 'truncated': true,
    'nodes': nodes.map((n) => n.toJson()).toList(growable: false),
  };
}

/// An execution acknowledgement plus a fresh observation. `pending` is not a
/// promise of completion; observe again instead of replaying the interaction.
final class MiniProgramInteractionResult {
  const MiniProgramInteractionResult({
    required this.requestId,
    required this.status,
    required this.snapshot,
    this.code,
  });
  final String requestId;
  final String status;
  final String? code;
  final MiniProgramInteractionSnapshot snapshot;

  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'status': status,
    if (code != null) 'code': code,
    'snapshot': snapshot.toJson(),
  };
}
