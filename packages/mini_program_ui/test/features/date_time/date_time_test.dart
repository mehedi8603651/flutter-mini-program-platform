import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('date namespace is public and emits deterministic date-field JSON', () {
    const MpDateTime fields = Mp.dateTime;
    final field = fields.dateField(
      stateKey: 'booking.date',
      label: 'Booking date',
      name: 'delivery_date',
      hint: 'Choose a day',
      initialValue: '2026-10-25',
      minDate: '2026-10-01',
      maxDate: '2026-10-31',
      required: true,
      onChanged: Mp.state.set('booking.changed', true),
    );
    expect(field.toJson(), {
      'type': 'dateField',
      'props': {
        'stateKey': 'booking.date',
        'name': 'delivery_date',
        'label': 'Booking date',
        'hint': 'Choose a day',
        'initialValue': '2026-10-25',
        'minDate': '2026-10-01',
        'maxDate': '2026-10-31',
        'required': true,
        'enabled': true,
        'onChanged': Mp.state.set('booking.changed', true).toJson(),
      },
      'children': <Object?>[],
    });
  });

  test('time field uses canonical time and has no calendar bounds', () {
    final field = Mp.dateTime.timeField(
      stateKey: 'booking.time',
      label: 'Time',
      initialValue: '14:30',
      enabled: false,
    );
    expect(field.type, 'timeField');
    expect(field.props['name'], 'time');
    expect(field.props['initialValue'], '14:30');
    expect(field.props['enabled'], isFalse);
    expect(field.props.containsKey('minDate'), isFalse);
    expect(field.props.containsKey('maxDate'), isFalse);
  });

  test('date range is copied, ordered and allows equal endpoints', () {
    final range = {'start': '2026-10-25', 'end': '2026-10-25'};
    final field = Mp.dateTime.dateRangeField(
      stateKey: 'booking.stay',
      label: 'Stay',
      initialValue: range,
    );
    range['end'] = '2026-10-28';
    expect(field.props['initialValue'], {
      'start': '2026-10-25',
      'end': '2026-10-25',
    });
    expect(field.props['minDate'], '1900-01-01');
    expect(field.props['maxDate'], '2100-12-31');
  });

  test(
    'absent selections stay absent and screen generation is deterministic',
    () {
      final program = MpProgram(
        screens: {
          'booking': () => Mp.column(
            children: [
              Mp.dateTime.dateField(stateKey: 'booking.date', label: 'Date'),
              Mp.dateTime.timeField(stateKey: 'booking.time', label: 'Time'),
              Mp.dateTime.dateRangeField(
                stateKey: 'booking.range',
                label: 'Range',
              ),
            ],
          ),
        },
      );
      expect(program.buildScreensJson(), program.buildScreensJson());
      expect(
        Mp.dateTime
            .dateField(stateKey: 'booking.date', label: 'Date')
            .props
            .containsKey('initialValue'),
        isFalse,
      );
    },
  );

  test('authoring rejects invalid values, bounds, names and state keys', () {
    final invalid = <void Function()>[
      () => Mp.dateTime.dateField(
        stateKey: 'booking.date',
        label: 'Date',
        initialValue: '2026-02-30',
      ),
      () => Mp.dateTime.dateField(
        stateKey: 'booking.date',
        label: 'Date',
        initialValue: '{{state.date}}',
      ),
      () => Mp.dateTime.dateField(
        stateKey: 'booking.date',
        label: 'Date',
        minDate: '2027-01-01',
        maxDate: '2026-01-01',
      ),
      () => Mp.dateTime.dateField(
        stateKey: 'booking.date',
        label: 'Date',
        initialValue: '2026-10-25',
        maxDate: '2026-10-24',
      ),
      () => Mp.dateTime.dateField(
        stateKey: 'booking.date',
        label: 'Date',
        minDate: '2026-13-01',
      ),
      () => Mp.dateTime.timeField(
        stateKey: 'booking.time',
        label: 'Time',
        initialValue: '24:00',
      ),
      () => Mp.dateTime.dateRangeField(
        stateKey: 'booking.stay',
        label: 'Stay',
        initialValue: {'start': '2026-10-28', 'end': '2026-10-25'},
      ),
      () => Mp.dateTime.dateRangeField(
        stateKey: 'booking.stay',
        label: 'Stay',
        minDate: '2026-10-26',
        initialValue: {'start': '2026-10-25', 'end': '2026-10-28'},
      ),
      () => Mp.dateTime.dateField(stateKey: 'booking.token', label: 'Date'),
      () => Mp.dateTime.dateField(stateKey: 'Booking.date', label: 'Date'),
      () => Mp.dateTime.dateField(stateKey: 'booking.date', label: ' '),
      () => Mp.dateTime.dateField(stateKey: 'booking.date', label: 'x' * 513),
      () => Mp.dateTime.dateField(
        stateKey: 'booking.date',
        label: 'Date',
        name: 'bad.name',
      ),
    ];
    for (final build in invalid) {
      expect(build, throwsArgumentError);
    }
  });
}
