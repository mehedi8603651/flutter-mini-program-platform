const Set<String> mpToneNames = <String>{
  'neutral',
  'info',
  'success',
  'warning',
  'danger',
};

const Set<String> mpIconNames = <String>{
  'person',
  'settings',
  'chevronRight',
  'star',
  'gift',
  'check',
  'warning',
  'info',
  'lock',
  'mail',
  'home',
  'search',
};

const Set<String> mpAlignmentNames = <String>{
  'topLeft',
  'topCenter',
  'topRight',
  'centerLeft',
  'center',
  'centerRight',
  'bottomLeft',
  'bottomCenter',
  'bottomRight',
};

final RegExp _hexColorPattern = RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

String requiredWidgetString(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Value cannot be empty.');
  }
  return trimmed;
}

num nonNegativeWidgetNumber(num value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be finite and non-negative.',
    );
  }
  return value;
}

num positiveWidgetNumber(num value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be finite and positive.',
    );
  }
  return value;
}

num unitIntervalWidgetNumber(num value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(
      value,
      name,
      'Value must be finite and between 0 and 1.',
    );
  }
  return value;
}

int positiveWidgetInt(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, 'Value must be positive.');
  }
  return value;
}

List<T> requiredWidgetList<T>(List<T> values, String name) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, name, 'Values cannot be empty.');
  }
  return values;
}

int gridColumnCount(int value) {
  if (value < 1 || value > 6) {
    throw ArgumentError.value(
      value,
      'columns',
      'Grid columns must be between 1 and 6.',
    );
  }
  return value;
}

String? pairedActionLabel({
  required Object? action,
  required String? actionLabel,
  required String owner,
}) {
  if (action == null && actionLabel == null) {
    return null;
  }
  if (action == null || actionLabel == null) {
    throw ArgumentError(
      'Provide both action and actionLabel for Mp.$owner, or neither.',
    );
  }
  return requiredWidgetString(actionLabel, 'actionLabel');
}

Map<String, Object?> positionedConstraints({
  num? left,
  num? top,
  num? right,
  num? bottom,
  num? width,
  num? height,
}) {
  if (left == null &&
      top == null &&
      right == null &&
      bottom == null &&
      width == null &&
      height == null) {
    throw ArgumentError('Provide at least one constraint for Mp.positioned.');
  }
  if (left != null && right != null && width != null) {
    throw ArgumentError('Mp.positioned cannot combine left, right, and width.');
  }
  if (top != null && bottom != null && height != null) {
    throw ArgumentError(
      'Mp.positioned cannot combine top, bottom, and height.',
    );
  }
  return <String, Object?>{
    if (bottom != null) 'bottom': nonNegativeWidgetNumber(bottom, 'bottom'),
    if (height != null) 'height': nonNegativeWidgetNumber(height, 'height'),
    if (left != null) 'left': nonNegativeWidgetNumber(left, 'left'),
    if (right != null) 'right': nonNegativeWidgetNumber(right, 'right'),
    if (top != null) 'top': nonNegativeWidgetNumber(top, 'top'),
    if (width != null) 'width': nonNegativeWidgetNumber(width, 'width'),
  };
}

String widgetAlignment(String value) {
  final alignment = requiredWidgetString(value, 'alignment');
  if (!mpAlignmentNames.contains(alignment)) {
    throw ArgumentError.value(
      value,
      'alignment',
      'Alignment must be one of: ${mpAlignmentNames.join(', ')}.',
    );
  }
  return alignment;
}

String widgetColor(String value, String name) {
  final trimmed = requiredWidgetString(value, name);
  if (!_hexColorPattern.hasMatch(trimmed)) {
    throw ArgumentError.value(
      value,
      name,
      'Color must use #RRGGBB or #AARRGGBB.',
    );
  }
  return trimmed;
}

String widgetTone(String value) {
  final tone = requiredWidgetString(value, 'tone');
  if (!mpToneNames.contains(tone)) {
    throw ArgumentError.value(
      value,
      'tone',
      'Tone must be one of: ${mpToneNames.join(', ')}.',
    );
  }
  return tone;
}

String widgetIconName(String value, String name) {
  final iconName = requiredWidgetString(value, name);
  if (!mpIconNames.contains(iconName)) {
    throw ArgumentError.value(
      value,
      name,
      'Icon must be one of: ${mpIconNames.join(', ')}.',
    );
  }
  return iconName;
}

Map<String, Object?> widgetSpacing({
  num? all,
  num? horizontal,
  num? vertical,
  num? left,
  num? top,
  num? right,
  num? bottom,
}) {
  final resolvedLeft = _spacingSide(
    side: left,
    axis: horizontal,
    all: all,
    name: 'left',
  );
  final resolvedTop = _spacingSide(
    side: top,
    axis: vertical,
    all: all,
    name: 'top',
  );
  final resolvedRight = _spacingSide(
    side: right,
    axis: horizontal,
    all: all,
    name: 'right',
  );
  final resolvedBottom = _spacingSide(
    side: bottom,
    axis: vertical,
    all: all,
    name: 'bottom',
  );
  return <String, Object?>{
    if (resolvedBottom != null) 'bottom': resolvedBottom,
    if (resolvedLeft != null) 'left': resolvedLeft,
    if (resolvedRight != null) 'right': resolvedRight,
    if (resolvedTop != null) 'top': resolvedTop,
  };
}

num? _spacingSide({
  required num? side,
  required num? axis,
  required num? all,
  required String name,
}) {
  final raw = side ?? axis ?? all;
  return raw == null ? null : nonNegativeWidgetNumber(raw, name);
}
