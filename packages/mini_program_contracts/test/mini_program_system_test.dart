import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes international and local phone formatting', () {
    expect(
      normalizeMiniProgramPhoneNumber('+880 (171) 234-5678'),
      '+8801712345678',
    );
    expect(normalizeMiniProgramPhoneNumber('(020) 1234.5678'), '02012345678');
  });
  test('rejects schemes, USSD, pauses, extensions and oversized numbers', () {
    for (final value in [
      '',
      'tel:123',
      '*123#',
      '123;456',
      '12,34',
      '123\n456',
      '\n123',
      '123\t',
      '12+34',
      '123 ext 4',
      '1' * 33,
      'https://example.com',
      '%2B123',
    ]) {
      expect(
        () => normalizeMiniProgramPhoneNumber(value),
        throwsFormatException,
        reason: value,
      );
    }
  });
}
