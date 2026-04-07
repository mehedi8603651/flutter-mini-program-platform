class OpenMiniProgramScreenActionPayload {
  const OpenMiniProgramScreenActionPayload({required this.screenId});

  factory OpenMiniProgramScreenActionPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return OpenMiniProgramScreenActionPayload(
      screenId: _requireScreenId(json, actionName: 'openMiniProgramScreen'),
    );
  }

  final String screenId;

  Map<String, dynamic> toJson() => <String, dynamic>{'screenId': screenId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenMiniProgramScreenActionPayload &&
          other.screenId == screenId;

  @override
  int get hashCode => screenId.hashCode;
}

class ResetMiniProgramStackActionPayload {
  const ResetMiniProgramStackActionPayload({required this.screenId});

  factory ResetMiniProgramStackActionPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return ResetMiniProgramStackActionPayload(
      screenId: _requireScreenId(json, actionName: 'resetMiniProgramStack'),
    );
  }

  final String screenId;

  Map<String, dynamic> toJson() => <String, dynamic>{'screenId': screenId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResetMiniProgramStackActionPayload &&
          other.screenId == screenId;

  @override
  int get hashCode => screenId.hashCode;
}

class ReplaceMiniProgramScreenActionPayload {
  const ReplaceMiniProgramScreenActionPayload({required this.screenId});

  factory ReplaceMiniProgramScreenActionPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReplaceMiniProgramScreenActionPayload(
      screenId: _requireScreenId(json, actionName: 'replaceMiniProgramScreen'),
    );
  }

  final String screenId;

  Map<String, dynamic> toJson() => <String, dynamic>{'screenId': screenId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplaceMiniProgramScreenActionPayload &&
          other.screenId == screenId;

  @override
  int get hashCode => screenId.hashCode;
}

class PopMiniProgramScreenActionPayload {
  const PopMiniProgramScreenActionPayload();

  factory PopMiniProgramScreenActionPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return const PopMiniProgramScreenActionPayload();
  }

  Map<String, dynamic> toJson() => const <String, dynamic>{};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PopMiniProgramScreenActionPayload;

  @override
  int get hashCode => 0;
}

class PopToMiniProgramRootActionPayload {
  const PopToMiniProgramRootActionPayload();

  factory PopToMiniProgramRootActionPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return const PopToMiniProgramRootActionPayload();
  }

  Map<String, dynamic> toJson() => const <String, dynamic>{};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PopToMiniProgramRootActionPayload;

  @override
  int get hashCode => 0;
}

class PopToMiniProgramScreenActionPayload {
  const PopToMiniProgramScreenActionPayload({required this.screenId});

  factory PopToMiniProgramScreenActionPayload.fromJson(
    Map<String, dynamic> json,
  ) {
    return PopToMiniProgramScreenActionPayload(
      screenId: _requireScreenId(json, actionName: 'popToMiniProgramScreen'),
    );
  }

  final String screenId;

  Map<String, dynamic> toJson() => <String, dynamic>{'screenId': screenId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PopToMiniProgramScreenActionPayload &&
          other.screenId == screenId;

  @override
  int get hashCode => screenId.hashCode;
}

String _requireScreenId(
  Map<String, dynamic> json, {
  required String actionName,
}) {
  final screenId = json['screenId'];
  if (screenId is! String || screenId.trim().isEmpty) {
    throw FormatException(
      'Payload for "$actionName" must contain a non-empty "screenId" string.',
    );
  }

  return screenId.trim();
}
