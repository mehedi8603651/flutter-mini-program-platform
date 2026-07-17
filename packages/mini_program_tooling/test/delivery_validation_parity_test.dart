import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('delivery validation parity', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_tooling_delivery_parity_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('preserves ordered missing-root failures exactly', () async {
      final report = await const DeliveryRepositoryValidator().validate(
        repoRootPath: tempDir.path,
      );

      expect(report.messages.map((message) => message.toJson()).toList(), <
        Map<String, dynamic>
      >[
        <String, dynamic>{
          'severity': 'error',
          'code': 'missing_mini_programs_root',
          'path': 'mini_programs',
          'message': 'mini_programs/ was not found under the repo root.',
        },
        <String, dynamic>{
          'severity': 'error',
          'code': 'missing_backend_api_root',
          'path': 'backend/api',
          'message':
              'Static artifact path backend/api/ was not found under the repo root.',
        },
      ]);
    });

    test('preserves malformed JSON failure details exactly', () async {
      await Directory(
        path.join(tempDir.path, 'mini_programs', 'broken'),
      ).create(recursive: true);
      await Directory(
        path.join(tempDir.path, 'backend', 'api'),
      ).create(recursive: true);
      await File(
        path.join(tempDir.path, 'mini_programs', 'broken', 'manifest.json'),
      ).writeAsString('{invalid');

      final report = await const DeliveryRepositoryValidator().validate(
        repoRootPath: tempDir.path,
      );

      expect(report.messages, hasLength(1));
      expect(report.messages.single.severity, ValidationSeverity.error);
      expect(report.messages.single.code, 'json_decode_failed');
      expect(report.messages.single.path, 'mini_programs/broken/manifest.json');
      expect(
        report.messages.single.message,
        startsWith('Invalid JSON: Unexpected character'),
      );
    });

    test('preserves secure policy validation ordering exactly', () async {
      await Directory(
        path.join(tempDir.path, 'mini_programs'),
      ).create(recursive: true);
      final policyFile = File(
        path.join(
          tempDir.path,
          'backend',
          'api',
          'secure-api-policies',
          'feedback_submit.json',
        ),
      );
      await policyFile.parent.create(recursive: true);
      await policyFile.writeAsString('''
{
  "endpoint": "feedback/submit",
  "allowedHosts": "host",
  "allowedSources": []
}
''');

      final report = await const DeliveryRepositoryValidator().validate(
        repoRootPath: tempDir.path,
      );

      expect(report.messages.map((message) => message.code).toList(), <String>[
        'allowedMethods_missing',
        'allowedHosts_not_list',
        'allowedSources_empty',
        'secure_api_policy_missing_minimum_message_length',
      ]);
      expect(report.messages.map((message) => message.path).toSet(), <String>{
        'backend/api/secure-api-policies/feedback_submit.json',
      });
    });
  });
}
