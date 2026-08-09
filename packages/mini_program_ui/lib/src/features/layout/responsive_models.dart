/// Width thresholds used by responsive mini-program layouts.
///
/// Values are Flutter logical pixels. Widths below [mediumMinWidth] are
/// compact, widths below [expandedMinWidth] are medium, and larger widths are
/// expanded.
final class MpResponsiveBreakpoints {
  const MpResponsiveBreakpoints({
    this.mediumMinWidth = 600,
    this.expandedMinWidth = 840,
  });

  final num mediumMinWidth;
  final num expandedMinWidth;

  Map<String, Object?> toJson() {
    _validateWidth(mediumMinWidth, 'mediumMinWidth');
    _validateWidth(expandedMinWidth, 'expandedMinWidth');
    if (mediumMinWidth >= expandedMinWidth) {
      throw ArgumentError.value(
        expandedMinWidth,
        'expandedMinWidth',
        'expandedMinWidth must be greater than mediumMinWidth.',
      );
    }
    return <String, Object?>{
      'expandedMinWidth': expandedMinWidth,
      'mediumMinWidth': mediumMinWidth,
    };
  }
}

void _validateWidth(num value, String name) {
  if (!value.isFinite || value <= 0 || value > 10000) {
    throw ArgumentError.value(
      value,
      name,
      'Responsive widths must be finite and between 1 and 10000.',
    );
  }
}
