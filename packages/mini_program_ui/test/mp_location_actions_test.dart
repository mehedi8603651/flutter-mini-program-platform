import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('Mp.location', () {
    test('serializes current location deterministically', () {
      expect(
        Mp.location
            .getCurrent(
              timeout: const Duration(seconds: 10),
              targetState: 'location.current',
              statusState: 'location.status',
              errorState: 'location.error',
              requestId: 'current-location',
            )
            .toJson(),
        <String, Object?>{
          'type': 'location.getCurrent',
          'props': <String, Object?>{
            'accuracy': 'approximate',
            'errorState': 'location.error',
            'requestId': 'current-location',
            'statusState': 'location.status',
            'targetState': 'location.current',
            'timeoutMs': 10000,
          },
        },
      );
    });

    test('rejects unsupported accuracy, timeout, and state keys', () {
      expect(
        () => Mp.location.getCurrent(
          accuracy: 'precise',
          timeout: const Duration(seconds: 10),
          targetState: 'location.current',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.location.getCurrent(
          timeout: const Duration(milliseconds: 999),
          targetState: 'location.current',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.location.getCurrent(
          timeout: const Duration(seconds: 61),
          targetState: 'location.current',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.location.getCurrent(
          timeout: const Duration(seconds: 10),
          targetState: 'location..current',
        ),
        throwsArgumentError,
      );
    });
  });
}
