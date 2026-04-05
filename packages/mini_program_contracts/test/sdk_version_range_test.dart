import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('SdkVersionRange', () {
    test('accepts versions inside the declared range', () {
      const range = SdkVersionRange(value: '>=1.0.0 <2.0.0');

      expect(range.isValid, isTrue);
      expect(range.allows('1.0.0'), isTrue);
      expect(range.allows('1.5.9'), isTrue);
      expect(range.allows('1.9.9'), isTrue);
    });

    test('rejects versions outside the declared range', () {
      const range = SdkVersionRange(value: '>=1.0.0 <2.0.0');

      expect(range.allows('0.9.9'), isFalse);
      expect(range.allows('2.0.0'), isFalse);
    });

    test('handles invalid range strings safely', () {
      const range = SdkVersionRange(value: 'not-a-valid-semver-range');

      expect(range.isValid, isFalse);
      expect(range.tryParseConstraint(), isNull);
      expect(range.allows('1.2.3'), isFalse);
    });

    test('handles invalid sdk versions safely', () {
      const range = SdkVersionRange(value: '>=1.0.0 <2.0.0');

      expect(range.tryParseVersion('not-a-version'), isNull);
      expect(range.allows('not-a-version'), isFalse);
    });

    test('serializes as a single range string when nested in manifests', () {
      const converter = SdkVersionRangeConverter();
      const range = SdkVersionRange(value: '>=1.0.0 <2.0.0');

      expect(converter.toJson(range), '>=1.0.0 <2.0.0');
      expect(converter.fromJson('>=1.0.0 <2.0.0'), range);
    });
  });
}
