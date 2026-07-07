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

      final handoff = await controller.readPackage(outputPath);
      expect(handoff.appId, 'coupon_demo');
      expect(handoff.title, 'Coupon Demo');
      expect(
        handoff.artifactBaseUri.toString(),
        'https://cdn.example.com/coupon',
      );
      expect(handoff.apiBaseUri, handoff.artifactBaseUri);
    });

    test('writes and reads optional requested cache policy', () async {
      const controller = MiniProgramPartnerHandoffController();
      final outputPath = p.join(tempDir.path, 'calculator.partner.json');

      final result = await controller.createPackage(
        MiniProgramPartnerPackageRequest(
          appId: 'calculator',
          title: 'Calculator',
          artifactBaseUri: Uri.parse('https://cdn.example.com/calculator/'),
          outputPath: outputPath,
          generatedAtUtc: DateTime.utc(2026, 7, 7, 10),
          requestedCache: const <String, Object?>{
            'state': <String, Object?>{
              'enabled': true,
              'reason': 'calculator history',
              'recommendedMaxBytes': 1048576,
              'recommendedTtlDays': 30,
            },
          },
        ),
      );

      expect(result.handoff.requestedCache['state'], isA<Map>());
      final decoded =
          jsonDecode(await File(outputPath).readAsString())
              as Map<String, dynamic>;
      expect(decoded['requestedCache'], <String, dynamic>{
        'state': <String, dynamic>{
          'enabled': true,
          'reason': 'calculator history',
          'recommendedMaxBytes': 1048576,
          'recommendedTtlDays': 30,
        },
      });

      final handoff = await controller.readPackage(outputPath);
      expect(handoff.requestedCache, <String, Object?>{
        'state': <String, Object?>{
          'enabled': true,
          'reason': 'calculator history',
          'recommendedMaxBytes': 1048576,
          'recommendedTtlDays': 30,
        },
      });
    });

    test('rejects sensitive requested cache buckets and keys', () async {
      final sessionPath = p.join(tempDir.path, 'session.partner.json');
      await File(sessionPath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 3,
          'type': MiniProgramPartnerHandoff.documentType,
          'appId': 'coupon_demo',
          'title': 'Coupon Demo',
          'artifactBaseUrl': 'https://static.example.com/coupon/',
          'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
          'requestedCache': <String, Object?>{
            'session': <String, Object?>{'enabled': true},
          },
        }),
      );
      expect(
        () => const MiniProgramPartnerHandoffController().readPackage(
          sessionPath,
        ),
        throwsA(isA<MiniProgramPartnerHandoffException>()),
      );

      final tokenPath = p.join(tempDir.path, 'token.partner.json');
      await File(tokenPath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 3,
          'type': MiniProgramPartnerHandoff.documentType,
          'appId': 'coupon_demo',
          'title': 'Coupon Demo',
          'artifactBaseUrl': 'https://static.example.com/coupon/',
          'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
          'requestedCache': <String, Object?>{
            'state': <String, Object?>{'token': 'unsafe'},
          },
        }),
      );
      expect(
        () =>
            const MiniProgramPartnerHandoffController().readPackage(tokenPath),
        throwsA(isA<MiniProgramPartnerHandoffException>()),
      );
    });

    test(
      'reads legacy schema v2 handoff packages as static artifacts',
      () async {
        const controller = MiniProgramPartnerHandoffController();
        final outputPath = p.join(tempDir.path, 'legacy-v2.partner.json');
        await File(outputPath).writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 2,
            'type': MiniProgramPartnerHandoff.documentType,
            'appId': 'coupon_demo',
            'title': 'Coupon Demo',
            'apiBaseUrl': 'https://static.example.com/coupon/',
            'backendBaseUrl': 'https://publisher.example.com/api/',
            'legacyField': 'ignored',
            'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
          }),
        );

        final decoded =
            jsonDecode(await File(outputPath).readAsString())
                as Map<String, dynamic>;
        expect(decoded['schemaVersion'], 2);
        expect(decoded['apiBaseUrl'], 'https://static.example.com/coupon/');
        expect(decoded['backendBaseUrl'], 'https://publisher.example.com/api/');

        final handoff = await controller.readPackage(outputPath);
        expect(handoff.schemaVersion, 2);
        expect(handoff.appId, 'coupon_demo');
        expect(handoff.title, 'Coupon Demo');
        expect(
          handoff.artifactBaseUri.toString(),
          'https://static.example.com/coupon',
        );
      },
    );

    test(
      'reads legacy schema v1 packages and ignores removed fields',
      () async {
        final filePath = p.join(tempDir.path, 'legacy.partner.json');
        await File(filePath).writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'type': MiniProgramPartnerHandoff.documentType,
            'appId': 'legacy_coupon_demo',
            'title': 'Legacy Coupon Demo',
            'apiBaseUrl': 'https://api.example.com/prod/api/',
            'legacyField': 'ignored',
            'generatedAtUtc': DateTime.utc(2026, 5, 14).toIso8601String(),
          }),
        );

        final handoff = await const MiniProgramPartnerHandoffController()
            .readPackage(filePath);

        expect(handoff.schemaVersion, 1);
        expect(
          handoff.artifactBaseUri.toString(),
          'https://api.example.com/prod/api',
        );
      },
    );

    test('rejects unsupported document types', () async {
      final filePath = p.join(tempDir.path, 'bad.partner.json');
      await File(filePath).writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'type': 'other',
          'appId': 'coupon_demo',
          'title': 'Coupon Demo',
          'apiBaseUrl': 'https://api.example.com/prod/api/',
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
