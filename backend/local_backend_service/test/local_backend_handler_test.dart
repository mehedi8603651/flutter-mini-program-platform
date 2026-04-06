import 'dart:convert';
import 'dart:io';

import 'package:local_backend_service/local_backend_service.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDirectory;
  late Handler handler;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'local_backend_service_test_',
    );

    await _writeJsonFile(
      tempDirectory,
      'manifests/profile_center/latest.json',
      <String, Object?>{
        'id': 'profile_center',
        'version': '1.1.0',
        'entry': 'profile_center_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': <String>['analytics', 'native_navigation'],
      },
    );
    await _writeJsonFile(
      tempDirectory,
      'manifests/profile_center/versions/1.1.0.json',
      <String, Object?>{
        'id': 'profile_center',
        'version': '1.1.0',
        'entry': 'profile_center_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': <String>['analytics', 'native_navigation'],
      },
    );
    await _writeJsonFile(
      tempDirectory,
      'manifests/profile_center/versions/1.0.0.json',
      <String, Object?>{
        'id': 'profile_center',
        'version': '1.0.0',
        'entry': 'profile_center_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': <String>['analytics', 'native_navigation'],
      },
    );
    await _writeJsonFile(
      tempDirectory,
      'screens/profile_center/1.0.0/profile_center_home.json',
      <String, Object?>{'type': 'scaffold', 'versionLabel': '1.0.0'},
    );
    await _writeJsonFile(
      tempDirectory,
      'screens/profile_center/1.1.0/profile_center_home.json',
      <String, Object?>{'type': 'scaffold', 'versionLabel': '1.1.0'},
    );
    await _writeJsonFile(
      tempDirectory,
      'manifests/feedback_form/latest.json',
      <String, Object?>{
        'id': 'feedback_form',
        'version': '1.1.0',
        'entry': 'feedback_form_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': <String>[
          'analytics',
          'secure_api',
          'native_navigation',
        ],
      },
    );
    await _writeJsonFile(
      tempDirectory,
      'manifests/feedback_form/versions/1.1.0.json',
      <String, Object?>{
        'id': 'feedback_form',
        'version': '1.1.0',
        'entry': 'feedback_form_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': <String>[
          'analytics',
          'secure_api',
          'native_navigation',
        ],
      },
    );
    await _writeJsonFile(
      tempDirectory,
      'manifests/feedback_form/versions/1.0.0.json',
      <String, Object?>{
        'id': 'feedback_form',
        'version': '1.0.0',
        'entry': 'feedback_form_home',
        'contractVersion': '1.0.0',
        'sdkVersionRange': '>=1.0.0 <2.0.0',
        'requiredCapabilities': <String>['analytics', 'native_navigation'],
      },
    );
    await _writeJsonFile(
      tempDirectory,
      'screens/feedback_form/1.1.0/feedback_form_home.json',
      <String, Object?>{'type': 'scaffold', 'versionLabel': '1.1.0'},
    );
    await _writeJsonFile(
      tempDirectory,
      'screens/feedback_form/1.0.0/feedback_form_home.json',
      <String, Object?>{'type': 'scaffold', 'versionLabel': '1.0.0'},
    );

    handler = createLocalBackendHandler(apiRootDirectory: tempDirectory);
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('returns health status', () async {
    final response = await handler(
      Request('GET', Uri.parse('http://localhost/health')),
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(
      response.headers[HttpHeaders.contentTypeHeader],
      contains('application/json'),
    );

    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'health');
    expect(body['statusCode'], HttpStatus.ok);
    expect(body['status'], 'ok');
    expect(body['service'], 'local_backend_service');
  });

  test('serves the latest manifest from a .json endpoint', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,auth',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['id'], 'profile_center');
    expect(body['version'], '1.1.0');
    expect(response.headers['x-backend-trace-id'], isNotNull);
    expect(
      response.headers['x-mini-program-decision-reason'],
      'matched_enabled_rule',
    );
    expect(
      body['deliveryMetadata'],
      isA<Map<String, dynamic>>()
          .having(
            (metadata) => metadata['selectionMode'],
            'selectionMode',
            'matched_rule',
          )
          .having(
            (metadata) => metadata['decisionReason'],
            'decisionReason',
            'matched_enabled_rule',
          )
          .having(
            (metadata) => metadata['matchedRuleId'],
            'matchedRuleId',
            'super-app-android-v1',
          )
          .having(
            (metadata) => metadata['resolvedVersion'],
            'resolvedVersion',
            '1.1.0',
          )
          .having(
            (metadata) => metadata['traceId'],
            'traceId',
            response.headers['x-backend-trace-id'],
          ),
    );
  });

  test('serves 1.0.0 latest for partner_app_host', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['version'], '1.0.0');
  });

  test('inspects a resolved manifest delivery decision', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/debug/manifests/profile_center/decision?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,auth',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers['x-debug-route'], 'manifest_decision_inspect');
    expect(response.headers['x-debug-outcome'], 'resolved');

    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'manifest_decision_inspection');
    expect(body['statusCode'], HttpStatus.ok);
    expect(body['outcome'], 'resolved');
    expect(body['simulatedStatusCode'], HttpStatus.ok);
    expect(
      (body['decision'] as Map<String, dynamic>)['matchedRuleId'],
      'super-app-android-v1',
    );
    expect(
      (body['decision'] as Map<String, dynamic>)['decisionReason'],
      'matched_enabled_rule',
    );
    expect(
      (body['manifestSummary'] as Map<String, dynamic>)['version'],
      '1.1.0',
    );
    expect((body['rollout'] as Map<String, dynamic>)['type'], 'rule_based');
  });

  test(
    'falls back to default version when hostVersion misses rollout rule',
    () async {
      await _writeProfileCenterPolicies(tempDirectory);

      final response = await handler(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=0.9.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,auth',
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['version'], '1.0.0');
    },
  );

  test('serves locale-specific 1.1.0 lane for partner_app_host', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=zh-CN&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['version'], '1.1.0');
  });

  test('serves tenant-specific 1.1.0 lane for partner_app_host', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&tenantId=vip_partner&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['version'], '1.1.0');
  });

  test('serves feedback_form latest for partner_app_host', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/feedback_form/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,secure_api',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['version'], '1.1.0');
  });

  test('accepts secure feedback submission for allowlisted hosts', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/secure/feedback/submit'),
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer super-demo-access-token',
          'x-host-app': 'super_app_host',
          'x-host-version': '1.4.0',
          'x-host-user-id': 'super_demo_user',
          'x-host-tenant-id': 'internal-demo',
        },
        body: jsonEncode(<String, Object?>{
          'source': 'feedback_form',
          'flow': 'portable_feedback',
          'message': 'Validated feedback payload from portable UI.',
        }),
      ),
    );

    expect(response.statusCode, HttpStatus.created);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['traceId'], response.headers['x-backend-trace-id']);
    expect(body['responseType'], 'secure_api_result');
    expect(body['statusCode'], HttpStatus.created);
    expect(body['status'], 'accepted');
    expect(body['endpoint'], 'feedback/submit');
    expect(body['hostApp'], 'super_app_host');
    expect(body['userId'], 'super_demo_user');
    expect(body['tenantId'], 'internal-demo');
    expect(body['flow'], 'portable_feedback');
    expect(body['submissionId'], startsWith('super_app_host_'));
    expect(body['result'], isA<Map<String, dynamic>>());
    expect(
      (body['result'] as Map<String, dynamic>)['submissionId'],
      body['submissionId'],
    );
  });

  test('returns 401 when secure feedback headers are missing', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/secure/feedback/submit'),
        headers: <String, String>{
          'content-type': 'application/json',
          'x-host-app': 'super_app_host',
        },
        body: jsonEncode(<String, Object?>{
          'source': 'feedback_form',
          'message': 'Validated feedback payload from portable UI.',
        }),
      ),
    );

    expect(response.statusCode, HttpStatus.unauthorized);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'secure_api_error');
    expect(body['statusCode'], HttpStatus.unauthorized);
    expect(body['errorCode'], MiniProgramErrorCodes.secureApiUnauthorized);
    expect(body['traceId'], response.headers['x-backend-trace-id']);
    expect((body['error'] as Map<String, dynamic>)['code'], body['errorCode']);
    expect(
      (body['details'] as Map<String, dynamic>)['missingHeaders'],
      containsAll(<String>[
        'x-host-version',
        'x-host-user-id',
        'authorization',
      ]),
    );
  });

  test('returns 403 when secure feedback host is not allowlisted', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/secure/feedback/submit'),
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer unknown-demo-access-token',
          'x-host-app': 'unknown_host',
          'x-host-version': '1.0.0',
          'x-host-user-id': 'unknown_user',
        },
        body: jsonEncode(<String, Object?>{
          'source': 'feedback_form',
          'message': 'Validated feedback payload from portable UI.',
        }),
      ),
    );

    expect(response.statusCode, HttpStatus.forbidden);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'secure_api_error');
    expect(body['errorCode'], MiniProgramErrorCodes.secureApiForbidden);
    expect(
      (body['details'] as Map<String, dynamic>)['hostApp'],
      'unknown_host',
    );
    expect(
      (body['details'] as Map<String, dynamic>)['reason'],
      'host_not_allowlisted',
    );
  });

  test('returns 401 when secure feedback token is expired', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/secure/feedback/submit'),
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer expired-super-demo-access-token',
          'x-host-app': 'super_app_host',
          'x-host-version': '1.4.0',
          'x-host-user-id': 'super_demo_user',
        },
        body: jsonEncode(<String, Object?>{
          'source': 'feedback_form',
          'message': 'Validated feedback payload from portable UI.',
        }),
      ),
    );

    expect(response.statusCode, HttpStatus.unauthorized);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['errorCode'], MiniProgramErrorCodes.secureApiSessionExpired);
  });

  test('returns 403 when secure feedback user is blocked', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/secure/feedback/submit'),
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer partner-demo-access-token',
          'x-host-app': 'partner_app_host',
          'x-host-version': '1.2.3',
          'x-host-user-id': 'blocked_partner_demo_user',
        },
        body: jsonEncode(<String, Object?>{
          'source': 'feedback_form',
          'message': 'Validated feedback payload from portable UI.',
        }),
      ),
    );

    expect(response.statusCode, HttpStatus.forbidden);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['errorCode'], MiniProgramErrorCodes.secureApiForbidden);
    expect((body['details'] as Map<String, dynamic>)['reason'], 'user_blocked');
    expect((body['error'] as Map<String, dynamic>)['code'], body['errorCode']);
  });

  test('returns 400 when secure feedback message is too short', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/secure/feedback/submit'),
        headers: <String, String>{
          'content-type': 'application/json',
          'authorization': 'Bearer partner-demo-access-token',
          'x-host-app': 'partner_app_host',
          'x-host-version': '1.2.3',
          'x-host-user-id': 'partner_demo_user',
        },
        body: jsonEncode(<String, Object?>{
          'source': 'feedback_form',
          'message': 'Too short',
        }),
      ),
    );

    expect(response.statusCode, HttpStatus.badRequest);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['errorCode'], MiniProgramErrorCodes.secureApiValidationFailed);
    expect((body['details'] as Map<String, dynamic>)['minimumLength'], 12);
  });

  test('serves a pinned profile_center version when requested', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,auth&pinnedVersion=1.0.0',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['version'], '1.0.0');
    expect(
      body['deliveryMetadata'],
      isA<Map<String, dynamic>>()
          .having(
            (metadata) => metadata['selectionMode'],
            'selectionMode',
            'pinned_version',
          )
          .having(
            (metadata) => metadata['requestedPinnedVersion'],
            'requestedPinnedVersion',
            '1.0.0',
          ),
    );
  });

  test(
    'returns 400 when latest manifest context is required but missing',
    () async {
      await _writeJsonFile(
        tempDirectory,
        'capability-policies/profile_center.json',
        <String, Object?>{
          'miniProgramId': 'profile_center',
          'requireContextForLatest': true,
          'enforceManifestCapabilities': true,
          'requiredQueryParameters': <String>[
            'hostApp',
            'sdkVersion',
            'hostVersion',
            'platform',
            'locale',
            'capabilities',
          ],
        },
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/api/manifests/profile_center/latest.json',
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.badRequest);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['errorCode'], 'manifest_context_required');
    },
  );

  test('returns 412 when host app is not enabled by rollout rules', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=unknown_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.preconditionFailed);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'manifest_delivery_error');
    expect(body['statusCode'], HttpStatus.preconditionFailed);
    expect(body['errorCode'], 'host_not_enabled');
    expect(body['traceId'], response.headers['x-backend-trace-id']);
    expect((body['error'] as Map<String, dynamic>)['code'], body['errorCode']);
  });

  test('returns 412 when a matching rollout rule is disabled', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/feedback_form/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&tenantId=blocked_lab&capabilities=analytics,native_navigation,secure_api',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.preconditionFailed);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['errorCode'], 'host_not_enabled');
    final details = body['details'] as Map<String, dynamic>;
    expect(details['matchedRuleId'], 'partner-feedback-disabled-lab');
    expect(details['resolvedVersion'], '1.1.0');
    expect(details['decisionReason'], 'matched_disabled_rule');
  });

  test(
    'returns 412 when feedback_form secure_api capability is missing',
    () async {
      await _writeFeedbackFormPolicies(tempDirectory);

      final response = await handler(
        Request(
          'GET',
          Uri.parse(
            'http://localhost/api/manifests/feedback_form/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation',
          ),
        ),
      );

      expect(response.statusCode, HttpStatus.preconditionFailed);
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['errorCode'], 'missing_capabilities');
      final details = body['details'] as Map<String, dynamic>;
      expect(details['missingCapabilities'], contains('secure_api'));
    },
  );

  test('returns 412 when request capabilities are missing', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.preconditionFailed);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['errorCode'], 'missing_capabilities');
  });

  test('returns 412 when requested SDK version is incompatible', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=2.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.preconditionFailed);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['errorCode'], 'incompatible_sdk_version');
  });

  test('serves a versioned manifest from a clean endpoint', () async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/versions/1.0.0',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['version'], '1.0.0');
  });

  test('inspects a rejected manifest delivery decision', () async {
    await _writeFeedbackFormPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/debug/manifests/feedback_form/decision?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers['x-debug-route'], 'manifest_decision_inspect');
    expect(response.headers['x-debug-outcome'], 'rejected');

    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'manifest_decision_inspection');
    expect(body['statusCode'], HttpStatus.ok);
    expect(body['outcome'], 'rejected');
    expect(body['simulatedStatusCode'], HttpStatus.preconditionFailed);
    expect(
      (body['rejection'] as Map<String, dynamic>)['errorCode'],
      'missing_capabilities',
    );
    expect(
      (body['decision'] as Map<String, dynamic>)['matchedRuleId'],
      'partner-feedback-default',
    );
    expect(
      (body['decision'] as Map<String, dynamic>)['resolvedVersion'],
      '1.1.0',
    );
  });

  test('serves a versioned screen from a .json endpoint', () async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/screens/profile_center/1.0.0/profile_center_home.json',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['type'], 'scaffold');
    expect(body['versionLabel'], '1.0.0');
  });

  test('serves the new 1.1.0 screen from a versioned endpoint', () async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/screens/profile_center/1.1.0/profile_center_home.json',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['type'], 'scaffold');
    expect(body['versionLabel'], '1.1.0');
  });

  test('returns 404 when a manifest is missing', () async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/manifests/missing_program/latest.json'),
      ),
    );

    expect(response.statusCode, HttpStatus.notFound);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'manifest_delivery_error');
    expect(body['statusCode'], HttpStatus.notFound);
    expect(body['errorCode'], 'artifact_not_found');
  });

  test('returns 400 when a path segment is unsafe', () async {
    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/screens/profile%20center/1.0.0/profile_center_home.json',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.badRequest);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['responseType'], 'request_error');
    expect(body['statusCode'], HttpStatus.badRequest);
    expect(body['errorCode'], 'invalid_request');
  });
}

Future<void> _writeJsonFile(
  Directory rootDirectory,
  String relativePath,
  Map<String, Object?> json,
) async {
  final file = File(
    '${rootDirectory.path}${Platform.pathSeparator}$relativePath',
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(json));
}

Future<void> _writeProfileCenterPolicies(Directory rootDirectory) async {
  await _writeJsonFile(
    rootDirectory,
    'rollout-rules/profile_center.json',
    <String, Object?>{
      'miniProgramId': 'profile_center',
      'defaultVersion': '1.0.0',
      'rules': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'super-app-android-v1',
          'hostApp': 'super_app_host',
          'platform': 'android',
          'hostVersionRange': '>=1.0.0 <2.0.0',
          'version': '1.1.0',
          'enabled': true,
        },
        <String, Object?>{
          'id': 'partner-vip-tenant',
          'hostApp': 'partner_app_host',
          'tenantId': 'vip_partner',
          'version': '1.1.0',
          'enabled': true,
        },
        <String, Object?>{
          'id': 'partner-zh-locale',
          'hostApp': 'partner_app_host',
          'locale': 'zh',
          'version': '1.1.0',
          'enabled': true,
        },
        <String, Object?>{
          'id': 'partner-default',
          'hostApp': 'partner_app_host',
          'version': '1.0.0',
          'enabled': true,
        },
      ],
    },
  );
  await _writeJsonFile(
    rootDirectory,
    'capability-policies/profile_center.json',
    <String, Object?>{
      'miniProgramId': 'profile_center',
      'requireContextForLatest': true,
      'enforceManifestCapabilities': true,
      'requiredQueryParameters': <String>[
        'hostApp',
        'sdkVersion',
        'hostVersion',
        'platform',
        'locale',
        'capabilities',
      ],
    },
  );
}

Future<void> _writeFeedbackFormPolicies(Directory rootDirectory) async {
  await _writeJsonFile(
    rootDirectory,
    'rollout-rules/feedback_form.json',
    <String, Object?>{
      'miniProgramId': 'feedback_form',
      'defaultVersion': '1.0.0',
      'rules': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'super-feedback-android',
          'hostApp': 'super_app_host',
          'platform': 'android',
          'hostVersionRange': '>=1.0.0 <2.0.0',
          'version': '1.1.0',
          'enabled': true,
        },
        <String, Object?>{
          'id': 'super-feedback-default',
          'hostApp': 'super_app_host',
          'version': '1.1.0',
          'enabled': true,
        },
        <String, Object?>{
          'id': 'partner-feedback-disabled-lab',
          'hostApp': 'partner_app_host',
          'tenantId': 'blocked_lab',
          'version': '1.1.0',
          'enabled': false,
        },
        <String, Object?>{
          'id': 'partner-feedback-default',
          'hostApp': 'partner_app_host',
          'version': '1.1.0',
          'enabled': true,
        },
      ],
    },
  );
  await _writeJsonFile(
    rootDirectory,
    'capability-policies/feedback_form.json',
    <String, Object?>{
      'miniProgramId': 'feedback_form',
      'requireContextForLatest': true,
      'enforceManifestCapabilities': true,
      'requiredQueryParameters': <String>[
        'hostApp',
        'sdkVersion',
        'hostVersion',
        'platform',
        'locale',
        'capabilities',
      ],
    },
  );
  await _writeJsonFile(
    rootDirectory,
    'secure-api-policies/feedback_submit.json',
    <String, Object?>{
      'endpoint': 'feedback/submit',
      'allowedMethods': <String>['POST'],
      'allowedHosts': <String>['super_app_host', 'partner_app_host'],
      'allowedSources': <String>['feedback_form'],
      'blockedUserIds': <String>[
        'blocked_super_demo_user',
        'blocked_partner_demo_user',
      ],
      'expiredAccessTokenPrefixes': <String>['expired-'],
      'minimumMessageLength': 12,
    },
  );
}
