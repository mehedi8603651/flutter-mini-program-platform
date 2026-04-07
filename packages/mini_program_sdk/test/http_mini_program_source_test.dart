import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  group('HttpMiniProgramSource', () {
    test(
      'builds manifest query parameters from MiniProgramDeliveryContext',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/manifests/profile_center/latest.json');
          expect(request.url.queryParameters['hostApp'], 'embedded_app');
          expect(request.url.queryParameters['sdkVersion'], '1.0.0');
          expect(request.url.queryParameters['hostVersion'], '2.4.0');
          expect(request.url.queryParameters['platform'], 'android');
          expect(request.url.queryParameters['locale'], 'en-US');
          expect(request.url.queryParameters['tenantId'], 'campus-demo');
          expect(request.url.queryParameters['pinnedVersion'], '1.1.0');
          expect(
            request.url.queryParameters['capabilities'],
            'analytics,native_navigation',
          );
          return http.Response(_manifestJson, 200);
        });

        final source = HttpMiniProgramSource.fromDeliveryContext(
          apiBaseUri: Uri.parse('http://localhost:8080/api'),
          deliveryContext: const MiniProgramDeliveryContext(
            hostApp: 'embedded_app',
            sdkVersion: '1.0.0',
            hostVersion: '2.4.0',
            capabilities: <Capability>{
              Capability.nativeNavigation,
              Capability.analytics,
            },
            platform: 'android',
            locale: 'en-US',
            tenantId: 'campus-demo',
            pinnedVersion: '1.1.0',
          ),
          client: client,
        );

        final manifest = await source.loadManifest('profile_center');

        expect(manifest.id, 'profile_center');
      },
    );

    test('loads the latest manifest from the backend endpoint', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/manifests/profile_center/latest.json');
        expect(request.url.queryParameters['hostApp'], 'super_app_host');
        expect(request.url.queryParameters['sdkVersion'], '1.0.0');
        expect(
          request.url.queryParameters['capabilities'],
          'analytics,native_navigation',
        );
        return http.Response(_manifestJson, 200);
      });

      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('http://localhost:8080/api'),
        manifestRequestQueryParametersBuilder: (_) => <String, String>{
          'hostApp': 'super_app_host',
          'sdkVersion': '1.0.0',
          'capabilities': 'analytics,native_navigation',
        },
        client: client,
      );

      final manifest = await source.loadManifest('profile_center');

      expect(manifest.id, 'profile_center');
      expect(manifest.version, '1.0.0');
    });

    test('loads a versioned screen from the backend endpoint', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost:8080/api/screens/profile_center/1.0.0/profile_center_home.json',
        );
        return http.Response(_screenJson, 200);
      });

      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('http://localhost:8080/api/'),
        client: client,
      );

      final screenJson = await source.loadScreen(
        miniProgramId: 'profile_center',
        version: '1.0.0',
        screenId: 'profile_center_home',
      );

      expect(screenJson['type'], 'scaffold');
    });

    test(
      'throws a structured source exception when the backend rejects delivery',
      () {
        final source = HttpMiniProgramSource(
          apiBaseUri: Uri.parse('http://localhost:8080/api/'),
          client: MockClient(
            (request) async => http.Response(
              '{"responseType":"manifest_delivery_error","statusCode":412,"errorCode":"missing_capabilities","message":"Host app is missing required capabilities.","traceId":"lb_trace_001","error":{"code":"missing_capabilities","message":"Host app is missing required capabilities.","details":{"matchedRuleId":"partner-default","decisionReason":"matched_disabled_rule"}}}',
              412,
              headers: <String, String>{
                'x-backend-trace-id': 'lb_trace_001',
                'x-mini-program-selection-mode': 'matched_rule',
                'x-mini-program-decision-reason': 'matched_disabled_rule',
              },
            ),
          ),
        );

        expect(
          () => source.loadManifest('missing_program'),
          throwsA(
            isA<MiniProgramSourceException>()
                .having(
                  (error) => error.errorCode,
                  'errorCode',
                  'missing_capabilities',
                )
                .having((error) => error.statusCode, 'statusCode', 412)
                .having(
                  (error) => error.message,
                  'message',
                  'Host app is missing required capabilities.',
                )
                .having(
                  (error) => error.details['traceId'],
                  'details.traceId',
                  'lb_trace_001',
                )
                .having(
                  (error) => error.details['responseType'],
                  'details.responseType',
                  'manifest_delivery_error',
                )
                .having(
                  (error) => error.details['matchedRuleId'],
                  'details.matchedRuleId',
                  'partner-default',
                )
                .having(
                  (error) => error.details['decisionReason'],
                  'details.decisionReason',
                  'matched_disabled_rule',
                ),
          ),
        );
      },
    );

    test('wraps transport failures as backend_unreachable', () {
      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('http://localhost:8080/api/'),
        client: MockClient((request) async {
          throw http.ClientException('Connection refused', request.url);
        }),
      );

      expect(
        () => source.loadManifest('profile_center'),
        throwsA(
          isA<MiniProgramSourceException>()
              .having(
                (error) => error.errorCode,
                'errorCode',
                'backend_unreachable',
              )
              .having(
                (error) => error.message,
                'message',
                'Failed to reach the mini-program backend while loading manifest.',
              ),
        ),
      );
    });

    test('times out manifest requests and surfaces backend_unreachable', () {
      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('http://localhost:8080/api/'),
        requestTimeout: const Duration(milliseconds: 10),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(_manifestJson, 200);
        }),
      );

      expect(
        () => source.loadManifest('profile_center'),
        throwsA(
          isA<MiniProgramSourceException>()
              .having(
                (error) => error.errorCode,
                'errorCode',
                MiniProgramErrorCodes.backendUnreachable,
              )
              .having(
                (error) => error.message,
                'message',
                'Timed out while loading manifest from the mini-program backend.',
              )
              .having(
                (error) => error.details['requestTimeoutMs'],
                'details.requestTimeoutMs',
                10,
              ),
        ),
      );
    });

    test('falls back to a generic message for non-JSON backend errors', () {
      final source = HttpMiniProgramSource(
        apiBaseUri: Uri.parse('http://localhost:8080/api/'),
        client: MockClient((request) async => http.Response('Not found', 404)),
      );

      expect(
        () => source.loadManifest('missing_program'),
        throwsA(
          isA<MiniProgramSourceException>().having(
            (error) => error.message,
            'message',
            contains('HTTP 404'),
          ),
        ),
      );
    });

    test(
      'throws a FormatException when the backend returns non-object JSON',
      () {
        final source = HttpMiniProgramSource(
          apiBaseUri: Uri.parse('http://localhost:8080/api/'),
          client: MockClient((request) async => http.Response('[]', 200)),
        );

        expect(
          () => source.loadScreen(
            miniProgramId: 'profile_center',
            version: '1.0.0',
            screenId: 'profile_center_home',
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}

const String _manifestJson = '''
{
  "id": "profile_center",
  "version": "1.0.0",
  "entry": "profile_center_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"],
  "fallback": {
    "strategy": "errorView",
    "message": "Profile Center is temporarily unavailable in this host app."
  }
}
''';

const String _screenJson = '''
{
  "type": "scaffold",
  "body": {
    "type": "safeArea",
    "child": {
      "type": "text",
      "data": "Profile Center"
    }
  }
}
''';
