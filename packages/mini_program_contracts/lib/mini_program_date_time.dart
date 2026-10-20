/// Canonical, timezone-free values exchanged by mini-program date/time fields.
///
/// Dates use Gregorian `YYYY-MM-DD`, times use 24-hour `HH:mm`, and ranges
/// contain exactly `start` and `end` dates. These values do not represent an
/// instant or imply a timezone. No parsing method normalizes invalid input.
abstract final class MiniProgramDateTimeValues {
  static const defaultMinDate = '1900-01-01';
  static const defaultMaxDate = '2100-12-31';

  /// Parses a civil date as UTC solely for component validation/comparison.
  /// Convert its components to a local calendar date when displaying a picker;
  /// do not convert this validation value with `toLocal()`.
  static DateTime parseDate(Object? value) {
    if (value is! String ||
        value.length != 10 ||
        !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
      throw const FormatException('Expected a date in YYYY-MM-DD format.');
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      throw const FormatException('Expected a valid Gregorian date.');
    }
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('Expected a valid Gregorian date.');
    }
    return date;
  }

  /// Parses a clock time into minutes since midnight, without a date/timezone.
  static int parseTime(Object? value) {
    if (value is! String ||
        value.length != 5 ||
        !RegExp(r'^[0-9]{2}:[0-9]{2}$').hasMatch(value)) {
      throw const FormatException('Expected a time in HH:mm format.');
    }
    final hour = int.parse(value.substring(0, 2));
    final minute = int.parse(value.substring(3, 5));
    if (hour > 23 || minute > 59) {
      throw const FormatException('Expected a valid 24-hour time.');
    }
    return hour * 60 + minute;
  }

  /// Validates and defensively copies an ordered, inclusive date range.
  static Map<String, String> parseDateRange(Object? value) {
    if (value is! Map ||
        value.length != 2 ||
        !value.containsKey('start') ||
        !value.containsKey('end')) {
      throw const FormatException('Expected a range with start and end dates.');
    }
    final start = parseDate(value['start']);
    final end = parseDate(value['end']);
    if (end.isBefore(start)) {
      throw const FormatException('Range end cannot be before start.');
    }
    return Map<String, String>.unmodifiable({
      'start': value['start'] as String,
      'end': value['end'] as String,
    });
  }
}
