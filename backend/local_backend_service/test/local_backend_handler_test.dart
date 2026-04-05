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
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&capabilities=analytics,native_navigation,auth',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['id'], 'profile_center');
    expect(body['version'], '1.1.0');
  });

  test('serves 1.0.0 latest for partner_app_host', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.ok);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['version'], '1.0.0');
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
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=unknown_host&sdkVersion=1.0.0&capabilities=analytics,native_navigation',
        ),
      ),
    );

    expect(response.statusCode, HttpStatus.preconditionFailed);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['errorCode'], 'host_not_enabled');
  });

  test('returns 412 when request capabilities are missing', () async {
    await _writeProfileCenterPolicies(tempDirectory);

    final response = await handler(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&capabilities=analytics',
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
          'http://localhost/api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=2.0.0&capabilities=analytics,native_navigation',
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
      'hostRules': <Map<String, Object?>>[
        <String, Object?>{
          'hostApp': 'super_app_host',
          'version': '1.1.0',
          'enabled': true,
        },
        <String, Object?>{
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
        'capabilities',
      ],
    },
  );
}
