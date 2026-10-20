part of '../../../mp_screen_renderer.dart';

extension _MpDateTimeNodeValidation on MpScreenValidator {
  _MpNode _parseDateTimeFieldNode({
    required String type,
    required Map<String, dynamic> props,
    required List<_MpNode> children,
    required String path,
  }) {
    final time = type == 'timeField';
    _validateObjectKeys(props, <String>{
      'stateKey',
      'name',
      'label',
      'hint',
      'initialValue',
      'required',
      'enabled',
      'onChanged',
      if (!time) ...{'minDate', 'maxDate'},
    }, path: '$path.props');
    _validateNoChildren(children, path: '$path.children');
    final key = _requiredStateKey(props, 'stateKey', path: '$path.props');
    String text(String name) {
      final result = _requiredString(props, name, path: '$path.props');
      if (result.length > 512) {
        _fail(
          'Mp date/time field text cannot exceed 512 characters.',
          path: '$path.props.$name',
        );
      }
      return result;
    }

    final min = props.containsKey('minDate')
        ? props['minDate']
        : MiniProgramDateTimeValues.defaultMinDate;
    final max = props.containsKey('maxDate')
        ? props['maxDate']
        : MiniProgramDateTimeValues.defaultMaxDate;
    Object? initial = props['initialValue'];
    try {
      if (!time) {
        MiniProgramDateTimeValues.parseDate(min);
        MiniProgramDateTimeValues.parseDate(max);
        if ((min as String).compareTo(max as String) > 0) {
          throw const FormatException('minDate cannot be after maxDate.');
        }
      }
      if (props.containsKey('initialValue')) {
        if (time) {
          MiniProgramDateTimeValues.parseTime(initial);
        } else {
          final dates = type == 'dateRangeField'
              ? (initial = MiniProgramDateTimeValues.parseDateRange(initial))
              : <String, String>{'date': initial is String ? initial : ''};
          for (final date in dates.values) {
            MiniProgramDateTimeValues.parseDate(date);
            if (date.compareTo(min as String) < 0 ||
                date.compareTo(max as String) > 0) {
              throw const FormatException(
                'Initial date is outside the bounds.',
              );
            }
          }
        }
      }
    } on FormatException catch (error) {
      _fail('Invalid Mp $type value: ${error.message}', path: '$path.props');
    }
    return _MpNode(
      type: type,
      props: <String, dynamic>{
        'stateKey': key,
        'name': props.containsKey('name')
            ? _requiredFieldName(props, 'name', path: '$path.props')
            : key.split('.').last,
        'label': text('label'),
        if (props.containsKey('hint')) 'hint': text('hint'),
        if (props.containsKey('initialValue')) 'initialValue': initial,
        if (!time) ...{'minDate': min, 'maxDate': max},
        'required':
            _optionalBool(props['required'], path: '$path.props.required') ??
            false,
        'enabled':
            _optionalBool(props['enabled'], path: '$path.props.enabled') ??
            true,
        if (props.containsKey('onChanged'))
          'onChanged': _parseAction(
            props['onChanged'],
            path: '$path.props.onChanged',
          ),
      },
      children: const <_MpNode>[],
    );
  }
}
