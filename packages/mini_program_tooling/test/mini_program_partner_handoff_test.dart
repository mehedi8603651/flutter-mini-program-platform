import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MiniProgramPartnerHandoffController', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'mini_program_partner_handoff_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes and reads a minimal MVP partner handoff package', () async {
      const controller = MiniProgramPartnerHandoffController();
      final outputPath = p.join(tempDir.path, 'coupon.partner.json');

      final result = await controller.createPackage(
        MiniProgramPartnerPackageRequest(
          appId: 'coupon_demo',
          title: 'Coupon Demo',
          artifactBaseUri: Uri.parse('https://cdn.example.com/coupon/'),
          outputPath: outputPath,
          generatedAtUtc: DateTime.utc(2026, 5, 14),
        ),
      );

      expect(result.filePath, p.normalize(p.absolute(outputPath)));
      final decoded =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 3);
      expect(decoded['type'], MiniProgramPartnerHandoff.documentType);
      expect(decoded['artifactBaseUrl'], 'https://cdn.example.com/coupon');
      expect(decoded.containsKey('apiBaseUrl'), isFalse);
      expect(decoded.containsKey('backendBaseUrl'), isFalse);
      expect(decoded.containsKey('accessMode'), isFalse);
      expect(decoded.containsKey('accessKey'), isFalse);

      final handoff = await controller.readPackage(outputPath);
      expect(handoff.appId, 'coupon_demo');
      expect(handoff.title, 'Coupon Demo');
      expect(
        handoff.artifactBaseUri.toString(),
        'https://cdn.example.com/coupon',
      );
      expect(handoff.apiBaseUri, handoff.artifactBaseUri);
      expect(handoff.backendBaseUri, isNull);
      expect(handoff.accessKey, isNull);
    });

    test('writes and reads legacy schema v2 handoff packages', () async {
      const controller = MiniProgramPartnerHandoffController();
      final outputPath = p.join(tempDir.path, 'legacy-v2.partner.json');

      final result = await controller.createPackage(
        MiniProgramPartnerPackageRequest(
          schemaVersion: MiniProgramPartnerHandoff.legacySchemaVersion,
          appId: 'aws_coupon_demo',
          title: 'AWS Coupon Demo',
          artifactBaseUri: Uri.parse('https://api.example.com/prod/api/'),
          backendBaseUri: Uri.parse('https://publisher.example.com/api/'),
          accessKey: 'mpk_live_company_a_12345678901234567890',
          outputPath: outputPath,
          generatedAtUtc: DateTime.utc(2026, 5, 14),
        ),
      );

      final decoded =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 2);
      expect(decoded['apiBaseUrl'], 'https://api.example.com/prod/api');
      expect(decoded['backendBaseUrl'], 'https://publisher.example.com/api');
      expect(
        decoded['accessMode'],
        MiniProgramPartnerHandoff.accessModeProtected,
      );
      expect(decoded['accessKey'], 'mpk_live_company_a_12345678901234567890');

      final handoff = await controller.readPackage(outputPath);
      expect(result.handoff.schemaVersion, 2);
      expect(handoff.appId, 'aws_coupon_demo');
      expect(handoff.title, 'AWS Coupon Demo');
      expect(handoff.apiBaseUri.toString(), 'https://api.example.com/prod/api');
      expect(
        handoff.backendBaseUri?.toString(),
        'https://publisher.example.com/api',
      );
      expect(handoff.accessKey, 'mpk_live_company_a_12345678901234567890');
    });

    test('reads legacy schema v1 protected packages', () async {
      final filePath = p.join(tempDir.path, 'legacy.partner.json');
      await File(filePath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'type': MiniProgramPartnerHandoff.documentType,
          'appId': 'legacy_coupon_demo',
          'title': 'Legacy Coupon Demo',
          'apiBaseUrl': 'https://api.example.com/prod/api/',
          'accessKey': 'mpk_live_company_a_12345678901234567890',
          'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
        }),
      );

      final handoff = await const MiniProgramPartnerHandoffController()
          .readPackage(filePath);

      expect(handoff.schemaVersion, 1);
      expect(handoff.accessMode, MiniProgramPartnerHandoff.accessModeProtected);
      expect(handoff.accessKey, 'mpk_live_company_a_12345678901234567890');
    });

    test('rejects unsupported document types', () async {
      final filePath = p.join(tempDir.path, 'bad.partner.json');
      await File(filePath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'type': 'other',
          'appId': 'aws_coupon_demo',
          'title': 'AWS Coupon Demo',
          'apiBaseUrl': 'https://api.example.com/prod/api/',
          'accessKey': 'mpk_live_company_a_12345678901234567890',
          'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
        }),
      );

      expect(
        () => const MiniProgramPartnerHandoffController().readPackage(filePath),
        throwsA(isA<MiniProgramPartnerHandoffException>()),
      );
    });
  });
}
