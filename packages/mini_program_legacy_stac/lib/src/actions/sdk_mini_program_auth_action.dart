class SdkMiniProgramAuthAction {
  const SdkMiniProgramAuthAction({required this.action, this.mode});

  static const String stacActionType = 'miniProgramAuth';

  final String action;
  final String? mode;

  bool get isShowEmailAuth => action == 'showEmailAuth';
  bool get isSignOut => action == 'signOut';
  bool get isRestore => action == 'restore';
  bool get isRefresh => action == 'refresh';

  factory SdkMiniProgramAuthAction.fromJson(Map<String, dynamic> json) {
    final actionType = json['actionType'];
    if (actionType != stacActionType) {
      throw FormatException(
        'Expected actionType "$stacActionType", got "$actionType".',
      );
    }

    final action = json['action'];
    if (action is! String || action.trim().isEmpty) {
      throw const FormatException(
        'Mini-program auth action JSON must contain a non-empty "action" string.',
      );
    }
    final mode = json['mode'];
    if (mode != null && mode is! String) {
      throw const FormatException('"mode" must be a string when provided.');
    }

    return SdkMiniProgramAuthAction(
      action: action.trim(),
      mode: mode == null || mode.trim().isEmpty ? null : mode.trim(),
    );
  }
}
