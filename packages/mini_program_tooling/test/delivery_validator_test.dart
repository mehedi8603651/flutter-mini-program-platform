import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('DeliveryRepositoryValidator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_validation_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('passes for a valid minimal repo fixture', () async {
      await _writeValidFixture(tempDir.path);

      final report = await const DeliveryRepositoryValidator().validate(
        repoRootPath: tempDir.path,
      );

      expect(report.hasErrors, isFalse);
      expect(report.messages, isEmpty);
    });

    test(
      'accepts secure API sources backed only by published artifacts',
      () async {
        await _writeValidFixture(tempDir.path, miniProgramId: 'feedback_form');
        await Directory(
          path.join(tempDir.path, 'mini_programs', 'feedback_form'),
        ).delete(recursive: true);

        final report = await const DeliveryRepositoryValidator().validate(
          repoRootPath: tempDir.path,
        );

        expect(report.hasErrors, isFalse);
        expect(
          report.messages.any(
            (message) => message.code == 'secure_api_policy_unknown_source',
          ),
          isFalse,
        );
        expect(
          report.messages.any(
            (message) =>
                message.code == 'capability_policy_missing_authored_manifest',
          ),
          isTrue,
        );
      },
    );

    test(
      'fails when secure_api manifest allows entry-screen caching',
      () async {
        await _writeValidFixture(
          tempDir.path,
          authoredManifestJson: '''
{
  "id": "feedback_form",
  "version": "1.1.0",
  "entry": "feedback_form_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "secure_api", "native_navigation"],
  "cachePolicy": {
    "manifest": {"mode": "noCache"},
    "entryScreen": {"mode": "staleWhileError", "maxStaleSeconds": 600}
  }
}
''',
          miniProgramId: 'feedback_form',
        );

        final report = await const DeliveryRepositoryValidator().validate(
          repoRootPath: tempDir.path,
          miniProgramId: 'feedback_form',
        );

        expect(report.hasErrors, isTrue);
        expect(
          report.messages.any(
            (message) =>
                message.code == 'secure_api_entry_screen_must_not_cache',
          ),
          isTrue,
        );
      },
    );

    test('fails when rollout versions are not published', () async {
      await _writeValidFixture(
        tempDir.path,
        rolloutJson: '''
{
  "miniProgramId": "profile_center",
  "defaultVersion": "9.9.9",
  "rules": [
    {
      "id": "broken-rule",
      "hostApp": "super_app_host",
      "version": "2.0.0",
      "enabled": true
    }
  ]
}
''',
      );

      final report = await const DeliveryRepositoryValidator().validate(
        repoRootPath: tempDir.path,
      );

      expect(report.hasErrors, isTrue);
      expect(
        report.messages.any(
          (message) => message.code == 'rollout_default_version_not_published',
        ),
        isTrue,
      );
      expect(
        report.messages.any(
          (message) => message.code == 'rollout_rule_version_not_published',
        ),
        isTrue,
      );
    });

    test(
      'fails when capability policy enforces capabilities without requiring them',
      () async {
        await _writeValidFixture(
          tempDir.path,
          capabilityPolicyJson: '''
{
  "miniProgramId": "profile_center",
  "requireContextForLatest": true,
  "enforceManifestCapabilities": true,
  "requiredQueryParameters": ["hostApp", "sdkVersion"]
}
''',
        );

        final report = await const DeliveryRepositoryValidator().validate(
          repoRootPath: tempDir.path,
        );

        expect(report.hasErrors, isTrue);
        expect(
          report.messages.any(
            (message) =>
                message.code ==
                'capability_policy_missing_capabilities_parameter',
          ),
          isTrue,
        );
      },
    );

    test('fails when secure API policy is malformed', () async {
      await _writeValidFixture(
        tempDir.path,
        secureApiPolicyJson: '''
{
  "endpoint": "/feedback/submit",
  "allowedMethods": ["TRACE", "POST"],
  "allowedHosts": ["super_app_host", "super_app_host"],
  "allowedSources": ["missing_program"],
  "minimumMessageLength": 0
}
''',
      );

      final report = await const DeliveryRepositoryValidator().validate(
        repoRootPath: tempDir.path,
      );

      expect(report.hasErrors, isTrue);
      expect(
        report.messages.any(
          (message) => message.code == 'secure_api_policy_invalid_endpoint',
        ),
        isTrue,
      );
      expect(
        report.messages.any(
          (message) => message.code == 'allowedMethods_invalid_value',
        ),
        isTrue,
      );
      expect(
        report.messages.any(
          (message) => message.code == 'allowedHosts_duplicate',
        ),
        isTrue,
      );
      expect(
        report.messages.any(
          (message) => message.code == 'secure_api_policy_unknown_source',
        ),
        isTrue,
      );
      expect(
        report.messages.any(
          (message) =>
              message.code ==
              'secure_api_policy_invalid_minimum_message_length',
        ),
        isTrue,
      );
    });
  });
}

Future<void> _writeValidFixture(
  String repoRootPath, {
  String miniProgramId = 'profile_center',
  String? authoredManifestJson,
  String? rolloutJson,
  String? capabilityPolicyJson,
  String? secureApiPolicyJson,
}) async {
  final manifestJson =
      authoredManifestJson ??
      '''
{
  "id": "$miniProgramId",
  "version": "1.1.0",
  "entry": "${miniProgramId}_home",
  "contractVersion": "1.0.0",
  "sdkVersionRange": ">=1.0.0 <2.0.0",
  "requiredCapabilities": ["analytics", "native_navigation"],
  "cachePolicy": {
    "manifest": {"mode": "staleWhileError", "maxStaleSeconds": 3600},
    "entryScreen": {"mode": "staleWhileError", "maxStaleSeconds": 1800}
  }
}
''';

  final entryName = '${miniProgramId}_home';

  await _writeFile(
    repoRootPath,
    'mini_programs/$miniProgramId/manifest.json',
    manifestJson,
  );
  await _writeFile(
    repoRootPath,
    'backend/api/artifacts/$miniProgramId/latest.json',
    manifestJson,
  );
  await _writeFile(
    repoRootPath,
    'backend/api/artifacts/$miniProgramId/1.1.0/manifest.json',
    manifestJson,
  );
  await _writeFile(
    repoRootPath,
    'backend/api/artifacts/$miniProgramId/1.1.0/screens/$entryName.json',
    '{"type":"scaffold","body":{"type":"text","data":"ok"}}',
  );
  await _writeFile(
    repoRootPath,
    'backend/api/rollout-rules/$miniProgramId.json',
    rolloutJson ??
        '''
{
  "miniProgramId": "$miniProgramId",
  "defaultVersion": "1.1.0",
  "rules": [
    {
      "id": "default-rule",
      "hostApp": "super_app_host",
      "version": "1.1.0",
      "enabled": true
    }
  ]
}
''',
  );
  await _writeFile(
    repoRootPath,
    'backend/api/capability-policies/$miniProgramId.json',
    capabilityPolicyJson ??
        '''
{
  "miniProgramId": "$miniProgramId",
  "requireContextForLatest": true,
  "enforceManifestCapabilities": true,
  "requiredQueryParameters": [
    "hostApp",
    "sdkVersion",
    "hostVersion",
    "platform",
    "locale",
    "capabilities"
  ]
}
''',
  );
  await _writeFile(
    repoRootPath,
    'backend/api/secure-api-policies/feedback_submit.json',
    secureApiPolicyJson ??
        '''
{
  "endpoint": "feedback/submit",
  "allowedMethods": ["POST"],
  "allowedHosts": ["super_app_host", "partner_app_host"],
  "allowedSources": ["$miniProgramId"],
  "blockedUserIds": ["blocked_super_demo_user", "blocked_partner_demo_user"],
  "expiredAccessTokenPrefixes": ["expired-"],
  "minimumMessageLength": 12
}
''',
  );
}

Future<void> _writeFile(
  String repoRootPath,
  String relativePath,
  String contents,
) async {
  final file = File(path.join(repoRootPath, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
