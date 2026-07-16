part of '../../mp_screen_renderer.dart';

final RegExp _rtlTextPattern = RegExp(r'[\u0590-\u08FF]');

class _MpThemeData {
  const _MpThemeData({
    this.colors = const <String, String>{},
    this.typography = const <String, _MpTypographyStyle>{},
  });

  final Map<String, String> colors;
  final Map<String, _MpTypographyStyle> typography;

  factory _MpThemeData.fromNode(_MpNode node) {
    final rawColors =
        node.props['colors'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final rawTypography =
        node.props['typography'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return _MpThemeData(
      colors: <String, String>{
        for (final entry in rawColors.entries) entry.key: entry.value as String,
      },
      typography: <String, _MpTypographyStyle>{
        for (final entry in rawTypography.entries)
          entry.key: _MpTypographyStyle.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
    );
  }

  _MpThemeData merge(_MpThemeData child) {
    return _MpThemeData(
      colors: <String, String>{...colors, ...child.colors},
      typography: <String, _MpTypographyStyle>{
        ...typography,
        ...child.typography,
      },
    );
  }
}

class _MpTypographyStyle {
  const _MpTypographyStyle({
    this.size,
    this.weight,
    this.lineHeight,
    this.color,
  });

  factory _MpTypographyStyle.fromMap(Map<String, dynamic> style) {
    return _MpTypographyStyle(
      size: (style['size'] as num?)?.toDouble(),
      weight: style['weight'] as String?,
      lineHeight: (style['lineHeight'] as num?)?.toDouble(),
      color: style['color'] as String?,
    );
  }

  final double? size;
  final String? weight;
  final double? lineHeight;
  final String? color;
}

class _MpTheme extends StatelessWidget {
  const _MpTheme({required this.node, required this.bindings});

  final _MpNode node;
  final _MpRenderBindings bindings;

  @override
  Widget build(BuildContext context) {
    final parentTheme = bindings.theme ?? const _MpThemeData();
    final mergedTheme = parentTheme.merge(_MpThemeData.fromNode(node));
    return _MpNodeView(
      node: node.children.single,
      bindings: bindings.copyWith(theme: mergedTheme),
    );
  }
}

class _MpToneColors {
  const _MpToneColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

class _MpButtonColors {
  const _MpButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.disabledBorder,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color disabledBorder;
}

FontWeight _mpFontWeight(String value) {
  return switch (value) {
    'medium' => FontWeight.w500,
    'semibold' => FontWeight.w600,
    'bold' => FontWeight.w700,
    _ => FontWeight.w400,
  };
}

TextAlign _mpTextAlign(String value) {
  return switch (value) {
    'left' => TextAlign.left,
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'end' => TextAlign.end,
    'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

TextOverflow _mpTextOverflow(String value) {
  return switch (value) {
    'ellipsis' => TextOverflow.ellipsis,
    'fade' => TextOverflow.fade,
    'visible' => TextOverflow.visible,
    _ => TextOverflow.clip,
  };
}

TextDirection _mpTextDirection(String value, String data) {
  return switch (value) {
    'ltr' => TextDirection.ltr,
    'rtl' => TextDirection.rtl,
    _ => _rtlTextPattern.hasMatch(data) ? TextDirection.rtl : TextDirection.ltr,
  };
}

Locale? _mpLocale(String? value) {
  if (value == null) {
    return null;
  }
  final parts = value.split('-');
  return parts.length == 1
      ? Locale(parts.first)
      : Locale(parts.first, parts[1]);
}

double _defaultTextSize(_MpNode node) {
  if (node.type != 'heading') {
    return 15;
  }
  return switch (_int(node, 'level', fallback: 1)) {
    2 => 22,
    3 => 20,
    4 => 18,
    5 => 16,
    6 => 15,
    _ => 24,
  };
}

Color _mpColor(String? value, {required Color fallback}) {
  if (value == null) {
    return fallback;
  }
  final hex = value.substring(1);
  if (hex.length == 6) {
    return Color(0xFF000000 | int.parse(hex, radix: 16));
  }
  return Color(int.parse(hex, radix: 16));
}

Color _mpThemeToken(
  _MpThemeData? theme,
  String token, {
  required Color fallback,
}) {
  return _mpThemeColor(token, theme, fallback: fallback);
}

Color _mpThemeColor(
  String value,
  _MpThemeData? theme, {
  required Color fallback,
}) {
  if (value.startsWith('#')) {
    return _mpColor(value, fallback: fallback);
  }
  final tokenColor = theme?.colors[value];
  if (tokenColor == null) {
    return fallback;
  }
  return _mpColor(tokenColor, fallback: fallback);
}

Color _mpSkeletonColor(_MpThemeData? theme, String? colorToken) {
  const fallback = Color(0xFFE5E7EB);
  if (colorToken != null) {
    final explicitColor = theme?.colors[colorToken];
    if (explicitColor != null) {
      return _mpColor(explicitColor, fallback: fallback);
    }
  }
  return _mpThemeToken(theme, 'skeleton', fallback: fallback);
}

TextStyle _mpThemeTextStyle(
  _MpThemeData? theme,
  String variant, {
  required Color defaultColor,
  required double defaultSize,
  required String defaultWeight,
  double? defaultHeight,
}) {
  return TextStyle(
    color: _mpTypographyColor(theme, variant, fallback: defaultColor),
    fontSize: _mpTypographySize(theme, variant, fallback: defaultSize),
    fontWeight: _mpTypographyWeight(theme, variant, fallback: defaultWeight),
    height: _mpTypographyHeight(theme, variant) ?? defaultHeight,
  );
}

Color _mpTypographyColor(
  _MpThemeData? theme,
  String variant, {
  required Color fallback,
}) {
  final color = theme?.typography[variant]?.color;
  return color == null
      ? fallback
      : _mpThemeColor(color, theme, fallback: fallback);
}

double _mpTypographySize(
  _MpThemeData? theme,
  String variant, {
  required double fallback,
}) {
  return theme?.typography[variant]?.size ?? fallback;
}

FontWeight _mpTypographyWeight(
  _MpThemeData? theme,
  String variant, {
  required String fallback,
}) {
  return _mpFontWeight(theme?.typography[variant]?.weight ?? fallback);
}

double? _mpTypographyHeight(_MpThemeData? theme, String variant) {
  return theme?.typography[variant]?.lineHeight;
}

_MpButtonColors _mpButtonColors({
  required bool primary,
  required bool enabled,
  required bool hoveredOrFocused,
  required bool pressed,
  required _MpThemeData? theme,
}) {
  final primaryColor = _mpThemeToken(
    theme,
    'primary',
    fallback: const Color(0xFF0B7A75),
  );
  final onPrimary = _mpThemeToken(
    theme,
    'onPrimary',
    fallback: const Color(0xFFFFFFFF),
  );
  final surface = _mpThemeToken(
    theme,
    'surface',
    fallback: const Color(0xFFFFFFFF),
  );
  final surfaceMuted = _mpThemeToken(
    theme,
    'surfaceMuted',
    fallback: const Color(0xFFE5E7EB),
  );
  final border = _mpThemeToken(
    theme,
    'border',
    fallback: const Color(0xFFD1D5DB),
  );
  final textMuted = _mpThemeToken(
    theme,
    'textMuted',
    fallback: const Color(0xFF6B7280),
  );
  if (!enabled) {
    return _MpButtonColors(
      background: surfaceMuted,
      foreground: textMuted,
      border: border,
      disabledBackground: surfaceMuted,
      disabledForeground: textMuted,
      disabledBorder: border,
    );
  }
  if (!primary) {
    final background = hoveredOrFocused || pressed
        ? _mpThemeToken(theme, 'surfaceMuted', fallback: surface)
        : surface;
    return _MpButtonColors(
      background: background,
      foreground: primaryColor,
      border: primaryColor,
      disabledBackground: surfaceMuted,
      disabledForeground: textMuted,
      disabledBorder: border,
    );
  }

  final background = pressed
      ? _mpThemeToken(
          theme,
          'primaryPressed',
          fallback: const Color(0xFF065F56),
        )
      : hoveredOrFocused
      ? _mpThemeToken(theme, 'primaryHover', fallback: const Color(0xFF0F766E))
      : primaryColor;
  return _MpButtonColors(
    background: background,
    foreground: onPrimary,
    border: primaryColor,
    disabledBackground: surfaceMuted,
    disabledForeground: textMuted,
    disabledBorder: border,
  );
}

_MpToneColors _mpToneStyle(String tone, [_MpThemeData? theme]) {
  final defaults = switch (tone) {
    'info' => const _MpToneColors(
      background: Color(0xFFEFF6FF),
      foreground: Color(0xFF1D4ED8),
      border: Color(0xFFBFDBFE),
    ),
    'success' => const _MpToneColors(
      background: Color(0xFFECFDF5),
      foreground: Color(0xFF047857),
      border: Color(0xFFA7F3D0),
    ),
    'warning' => const _MpToneColors(
      background: Color(0xFFFFFBEB),
      foreground: Color(0xFFB45309),
      border: Color(0xFFFDE68A),
    ),
    'danger' => const _MpToneColors(
      background: Color(0xFFFEF2F2),
      foreground: Color(0xFFB91C1C),
      border: Color(0xFFFECACA),
    ),
    _ => const _MpToneColors(
      background: Color(0xFFF3F4F6),
      foreground: Color(0xFF374151),
      border: Color(0xFFE5E7EB),
    ),
  };
  return _MpToneColors(
    background: _mpThemeToken(
      theme,
      '${tone}Bg',
      fallback: defaults.background,
    ),
    foreground: _mpThemeToken(theme, tone, fallback: defaults.foreground),
    border: _mpThemeToken(theme, '${tone}Border', fallback: defaults.border),
  );
}
