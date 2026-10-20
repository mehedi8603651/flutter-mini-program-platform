import 'package:mini_program_contracts/mini_program_contracts.dart';

import '../../core/authoring_validation.dart';
import '../../core/mp_action.dart';
import '../../core/mp_node.dart';

/// State-bound calendar and clock fields rendered by the host SDK.
///
/// Selection uses Flutter's built-in dialogs. Values are civil dates and clock
/// times, without timezone conversion. Bounds and initial values are literals;
/// update the bound state to change a selection at runtime. Within `Mp.form`,
/// `name` defaults to the last segment of `stateKey` and must be unique.
final class MpDateTime {
  const MpDateTime();

  /// Selects one Gregorian `YYYY-MM-DD` date, including both date bounds.
  MpNode dateField({
    required String stateKey,
    required String label,
    String? name,
    String? hint,
    String? initialValue,
    String minDate = MiniProgramDateTimeValues.defaultMinDate,
    String maxDate = MiniProgramDateTimeValues.defaultMaxDate,
    bool required = false,
    bool enabled = true,
    MpAction? onChanged,
  }) => _field(
    'dateField',
    stateKey,
    label,
    name,
    hint,
    initialValue,
    minDate,
    maxDate,
    required,
    enabled,
    onChanged,
  );

  /// Selects one clock time, stored as 24-hour `HH:mm` regardless of display.
  MpNode timeField({
    required String stateKey,
    required String label,
    String? name,
    String? hint,
    String? initialValue,
    bool required = false,
    bool enabled = true,
    MpAction? onChanged,
  }) => _field(
    'timeField',
    stateKey,
    label,
    name,
    hint,
    initialValue,
    null,
    null,
    required,
    enabled,
    onChanged,
  );

  /// Selects an inclusive range stored as `{"start": date, "end": date}`.
  /// A same-day range is valid. Cancellation keeps the existing state.
  MpNode dateRangeField({
    required String stateKey,
    required String label,
    String? name,
    String? hint,
    Map<String, String>? initialValue,
    String minDate = MiniProgramDateTimeValues.defaultMinDate,
    String maxDate = MiniProgramDateTimeValues.defaultMaxDate,
    bool required = false,
    bool enabled = true,
    MpAction? onChanged,
  }) => _field(
    'dateRangeField',
    stateKey,
    label,
    name,
    hint,
    initialValue,
    minDate,
    maxDate,
    required,
    enabled,
    onChanged,
  );

  MpNode _field(
    String type,
    String stateKey,
    String label,
    String? name,
    String? hint,
    Object? initialValue,
    String? minDate,
    String? maxDate,
    bool required,
    bool enabled,
    MpAction? onChanged,
  ) {
    final key = requiredStateKey(stateKey, 'stateKey');
    Object? initial = initialValue;
    try {
      if (minDate != null && maxDate != null) {
        MiniProgramDateTimeValues.parseDate(minDate);
        MiniProgramDateTimeValues.parseDate(maxDate);
        if (minDate.compareTo(maxDate) > 0) {
          throw const FormatException('minDate cannot be after maxDate.');
        }
      }
      if (initial != null) {
        if (type == 'timeField') {
          MiniProgramDateTimeValues.parseTime(initial);
        } else {
          final dates = type == 'dateRangeField'
              ? (initial = MiniProgramDateTimeValues.parseDateRange(initial))
              : <String, String>{'date': initial as String};
          for (final date in dates.values) {
            MiniProgramDateTimeValues.parseDate(date);
            if (date.compareTo(minDate!) < 0 || date.compareTo(maxDate!) > 0) {
              throw const FormatException(
                'Initial date is outside the bounds.',
              );
            }
          }
        }
      }
    } on FormatException catch (error) {
      throw ArgumentError(error.message);
    }
    return MpNode(
      type,
      props: <String, Object?>{
        'stateKey': key,
        'name': requiredFieldName(name ?? key.split('.').last, 'name'),
        'label': _text(label, 'label'),
        if (hint != null) 'hint': _text(hint, 'hint'),
        if (initial != null) 'initialValue': initial,
        if (minDate != null) 'minDate': minDate,
        if (maxDate != null) 'maxDate': maxDate,
        'required': required,
        'enabled': enabled,
        if (onChanged != null) 'onChanged': onChanged,
      },
    );
  }

  String _text(String value, String name) {
    final result = requiredAuthoringString(value, name);
    if (result.length > 512) {
      throw ArgumentError.value(value, name, 'Cannot exceed 512 characters.');
    }
    return result;
  }
}
