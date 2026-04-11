import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('LocalMiniProgramBackendDefaults', () {
    test('uses Android emulator host by default on Android', () {
      final uri = LocalMiniProgramBackendDefaults.resolveBaseUri(
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.toString(), 'http://10.0.2.2:8080/api/');
    });

    test('uses loopback by default on desktop targets', () {
      final uri = LocalMiniProgramBackendDefaults.resolveBaseUri(
        platform: TargetPlatform.windows,
        isWeb: false,
      );

      expect(uri.toString(), 'http://127.0.0.1:8080/api/');
    });

    test('uses loopback by default on web', () {
      final uri = LocalMiniProgramBackendDefaults.resolveBaseUri(
        platform: TargetPlatform.android,
        isWeb: true,
      );

      expect(uri.toString(), 'http://127.0.0.1:8080/api/');
    });

    test('respects configured host and port override', () {
      final uri = LocalMiniProgramBackendDefaults.resolveBaseUri(
        configuredHost: '192.168.1.33',
        configuredPort: 9090,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.toString(), 'http://192.168.1.33:9090/api/');
    });

    test('respects configured base URL override', () {
      final uri = LocalMiniProgramBackendDefaults.resolveBaseUri(
        configuredBaseUrl: 'https://mini.example.com/backend/api/',
        platform: TargetPlatform.android,
        isWeb: false,
      );

      expect(uri.toString(), 'https://mini.example.com/backend/api/');
    });
  });
}
