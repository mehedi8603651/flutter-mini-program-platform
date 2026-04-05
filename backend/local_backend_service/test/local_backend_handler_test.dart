import 'dart:convert';
import 'dart:io';

import 'package:local_backend_service/local_backend_service.dart';
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
    expect(
      body['deliveryMetadata'],
      isA<Map<String, dynamic>>()
          .having(
            (metadata) => metadata['selectionMode'],
            'selectionMode',
            'matched_rule',
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
    expect(body['errorCode'], 'host_not_enabled');
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
  });

  test('returns 412 when feedback_form secure_api capability is missing', () async {
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
  });

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
}
