import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test(
    'civil dates preserve Gregorian components without a timezone shift',
    () {
      for (final value in [
        '0001-01-01',
        '2000-02-29',
        '2026-10-25',
        '9999-12-31',
      ]) {
        final date = MiniProgramDateTimeValues.parseDate(value);
        expect(date.isUtc, isTrue);
        expect(date.toIso8601String().substring(0, 10), value);
      }
    },
  );

  for (final value in <Object?>[
    null,
    20261025,
    '',
    '2026-1-01',
    '0000-01-01',
    '1900-02-29',
    '2026-02-29',
    '2026-02-30',
    '2026-00-01',
    '2026-13-01',
    '2026-10-00',
    '2026-10-32',
    '2026-10-25Z',
    '2026-10-25\n',
    '2026-10-25T00:00:00Z',
    ' 2026-10-25',
    '{{state.date}}',
  ]) {
    test('rejects invalid civil date ${value.runtimeType}: $value', () {
      expect(
        () => MiniProgramDateTimeValues.parseDate(value),
        throwsFormatException,
      );
    });
  }

  test('clock times are bounded minutes since midnight', () {
    expect(MiniProgramDateTimeValues.parseTime('00:00'), 0);
    expect(MiniProgramDateTimeValues.parseTime('14:30'), 870);
    expect(MiniProgramDateTimeValues.parseTime('23:59'), 1439);
  });

  for (final value in <Object?>[
    null,
    1430,
    '',
    '9:30',
    '24:00',
    '12:60',
    '-1:00',
    '14:30Z',
    '14:30\n',
    '2:30 PM',
  ]) {
    test('rejects invalid clock time $value', () {
      expect(
        () => MiniProgramDateTimeValues.parseTime(value),
        throwsFormatException,
      );
    });
  }

  test(
    'inclusive ranges are ordered and returned as defensive immutable copies',
    () {
      final source = {'start': '2026-10-25', 'end': '2026-10-28'};
      final range = MiniProgramDateTimeValues.parseDateRange(source);
      source['start'] = '2026-10-01';
      expect(range['start'], '2026-10-25');
      expect(() => range['start'] = '2026-10-01', throwsUnsupportedError);
      expect(
        MiniProgramDateTimeValues.parseDateRange({
          'start': '2026-10-25',
          'end': '2026-10-25',
        }),
        {'start': '2026-10-25', 'end': '2026-10-25'},
      );
    },
  );

  test('malformed, reversed, or extended range objects are rejected', () {
    for (final value in <Object?>[
      null,
      [],
      '2026-10-25',
      {'start': '2026-10-25'},
      {'start': '2026-10-28', 'end': '2026-10-25'},
      {'start': '2026-10-25', 'end': '2026-02-30'},
      {'start': '2026-10-25', 'end': '2026-10-28', 'timezone': 'UTC'},
    ]) {
      expect(
        () => MiniProgramDateTimeValues.parseDateRange(value),
        throwsFormatException,
      );
    }
  });
}
