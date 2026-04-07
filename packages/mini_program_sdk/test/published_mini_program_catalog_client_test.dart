import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('builds discovery query parameters from MiniProgramDeliveryContext', () async {
    late Uri requestUri;
    final client = MockClient((request) async {
      requestUri = request.url;
      return http.Response(
        '''
        {
          "responseType":"mini_program_catalog",
          "statusCode":200,
          "entries":[]
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final catalogClient = PublishedMiniProgramCatalogClient.fromDeliveryContext(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      deliveryContext: const MiniProgramDeliveryContext(
        hostApp: 'embedded_app',
        sdkVersion: '1.0.0',
        hostVersion: '2.4.0',
        capabilities: <Capability>{
          Capability.secureApi,
          Capability.analytics,
          Capability.nativeNavigation,
        },
        platform: 'android',
        locale: 'en-US',
      ),
      client: client,
    );

    final catalog = await catalogClient.listAvailableMiniPrograms();

    expect(catalog.entries, isEmpty);
    expect(requestUri.path, '/api/discovery/mini-programs.json');
    expect(requestUri.queryParameters['hostApp'], 'embedded_app');
    expect(requestUri.queryParameters['hostVersion'], '2.4.0');
    expect(
      requestUri.queryParameters['capabilities'],
      'analytics,native_navigation,secure_api',
    );
  });

  test('loads and parses the published mini-program catalog', () async {
    late Uri requestUri;
    final client = MockClient((request) async {
      requestUri = request.url;
      return http.Response(
        '''
        {
          "responseType":"mini_program_catalog",
          "statusCode":200,
          "traceId":"trace_catalog_001",
          "entryCount":2,
          "entries":[
            {
              "id":"feedback_form",
              "title":"Feedback Form",
              "description":"Backend-discovered portable mini-program.",
              "entry":"feedback_form_home",
              "resolvedVersion":"1.1.0",
              "requiredCapabilities":["analytics","secure_api","native_navigation"],
              "selectionMode":"matched_rule",
              "decisionReason":"matched_enabled_rule",
              "matchedRuleId":"partner-feedback-default"
            },
            {
              "id":"profile_center",
              "title":"Profile Center",
              "description":"Backend-discovered portable mini-program.",
              "entry":"profile_center_home",
              "resolvedVersion":"1.0.0",
              "requiredCapabilities":["analytics","native_navigation"],
              "selectionMode":"default_version",
              "decisionReason":"no_rule_matched"
            }
          ]
        }
        ''',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final catalogClient = PublishedMiniProgramCatalogClient(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      queryParameters: const <String, String>{
        'hostApp': 'partner_app_host',
        'sdkVersion': '1.0.0',
      },
      client: client,
    );

    final catalog = await catalogClient.listAvailableMiniPrograms();

    expect(requestUri.path, '/api/discovery/mini-programs.json');
    expect(requestUri.queryParameters['hostApp'], 'partner_app_host');
    expect(catalog.traceId, 'trace_catalog_001');
    expect(catalog.entries, hasLength(2));
    expect(catalog.entries.first.id, 'feedback_form');
    expect(catalog.entries.first.requiredCapabilities, <Capability>[
      Capability.analytics,
      Capability.secureApi,
      Capability.nativeNavigation,
    ]);
  });

  test('surfaces backend catalog failures as source exceptions', () async {
    final client = MockClient((request) async {
      return http.Response(
        '''
        {
          "responseType":"mini_program_catalog_error",
          "statusCode":400,
          "errorCode":"manifest_context_required",
          "message":"Manifest context is required.",
          "traceId":"trace_catalog_002"
        }
        ''',
        400,
        headers: <String, String>{
          'content-type': 'application/json',
          'x-backend-trace-id': 'trace_catalog_002',
        },
      );
    });
    final catalogClient = PublishedMiniProgramCatalogClient(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      client: client,
    );

    expect(
      () => catalogClient.listAvailableMiniPrograms(),
      throwsA(
        isA<MiniProgramSourceException>()
            .having((error) => error.errorCode, 'errorCode', 'manifest_context_required')
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.details['traceId'],
              'traceId',
              'trace_catalog_002',
            ),
      ),
    );
  });

  test('times out catalog requests and surfaces backend_unreachable', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response(
        '{"responseType":"mini_program_catalog","statusCode":200,"entries":[]}',
        200,
      );
    });
    final catalogClient = PublishedMiniProgramCatalogClient(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      requestTimeout: const Duration(milliseconds: 10),
      client: client,
    );

    expect(
      () => catalogClient.listAvailableMiniPrograms(),
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
              'Timed out while loading the mini-program discovery catalog from the backend.',
            )
            .having(
              (error) => error.details['requestTimeoutMs'],
              'details.requestTimeoutMs',
              10,
            ),
      ),
    );
  });
}
