import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('builds the debug inspection URI with sorted capabilities', () {
    const request = DeliveryInspectionRequest(
      miniProgramId: 'profile_center',
      hostApp: 'super_app_host',
      sdkVersion: '1.0.0',
      hostVersion: '1.0.0',
      platform: 'android',
      locale: 'en-US',
      capabilities: <String>{'native_navigation', 'analytics'},
    );

    final uri = request.buildUri(Uri.parse('http://127.0.0.1:8080/api/'));

    expect(uri.path, '/api/debug/manifests/profile_center/decision');
    expect(uri.queryParameters['hostApp'], 'super_app_host');
    expect(uri.queryParameters['capabilities'], 'analytics,native_navigation');
  });

  test('formats a resolved inspection response for humans', () {
    final formatted = formatDeliveryInspectionResponse(
      const DeliveryInspectionResponse(
        statusCode: 200,
        headers: <String, String>{'x-backend-trace-id': 'lb_trace_001'},
        body: <String, dynamic>{
          'miniProgramId': 'profile_center',
          'outcome': 'resolved',
          'simulatedStatusCode': 200,
          'traceId': 'lb_trace_001',
          'decision': <String, dynamic>{
            'selectionMode': 'matched_rule',
            'decisionReason': 'matched_enabled_rule',
            'resolvedVersion': '1.1.0',
            'matchedRuleId': 'super-app-android-v1',
          },
          'manifestSummary': <String, dynamic>{
            'version': '1.1.0',
            'entry': 'profile_center_home',
            'sdkVersionRange': '>=1.0.0 <2.0.0',
            'requiredCapabilities': <String>['analytics', 'native_navigation'],
          },
          'rollout': <String, dynamic>{
            'type': 'rule_based',
            'defaultVersion': '1.0.0',
            'rules': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'super-app-android-v1',
                'version': '1.1.0',
                'matches': true,
              },
            ],
          },
          'deliveryContext': <String, dynamic>{
            'hostApp': 'super_app_host',
            'sdkVersion': '1.0.0',
          },
        },
      ),
    );

    expect(formatted, contains('Mini-program: profile_center'));
    expect(formatted, contains('resolvedVersion: 1.1.0'));
    expect(formatted, contains('matchedRuleId: super-app-android-v1'));
    expect(formatted, contains('[match] super-app-android-v1 -> 1.1.0'));
  });

  test('client preserves trace ID from backend responses', () async {
    final client = DeliveryInspectorClient(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080/api/'),
      httpClient: MockClient((request) async {
        expect(
          request.url.path,
          '/api/debug/manifests/profile_center/decision',
        );
        expect(request.headers['x-request-id'], 'debug_trace_123');
        return http.Response(
          '{"miniProgramId":"profile_center","outcome":"resolved","simulatedStatusCode":200,"traceId":"debug_trace_123"}',
          200,
          headers: <String, String>{'x-backend-trace-id': 'debug_trace_123'},
        );
      }),
    );

    final response = await client.inspect(
      const DeliveryInspectionRequest(miniProgramId: 'profile_center'),
      requestId: 'debug_trace_123',
    );

    expect(response.traceId, 'debug_trace_123');
    expect(response.body['outcome'], 'resolved');
  });
}
