import 'dart:io';

import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('partner handoff parity', () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        'mini_program_partner_handoff_parity_',
      );
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('preserves full requested-policy bytes and normalization', () async {
      final outputPath = path.join(
        temporaryDirectory.path,
        'weather.partner.json',
      );
      final result = await const MiniProgramPartnerHandoffController()
          .createPackage(
            MiniProgramPartnerPackageRequest(
              appId: ' weather ',
              title: ' Weather ',
              artifactBaseUri: Uri.parse('https://cdn.example.com/weather///'),
              outputPath: outputPath,
              generatedAtUtc: DateTime.utc(2026, 7, 18, 10, 30),
              requestedCache: const <String, Object?>{
                'state': <String, Object?>{
                  'enabled': true,
                  'reason': 'saved places',
                  'recommendedMaxBytes': 1024,
                  'nested': <String, Object?>{
                    'labels': <Object?>['home', 'work'],
                  },
                },
              },
              requestedPublisherApi: const <String, Object?>{
                'enabled': true,
                'reason': ' Load forecasts. ',
              },
              requestedPermissions: const <String, Object?>{
                'location': <String, Object?>{
                  'enabled': true,
                  'reason': ' Use approximate location. ',
                  'accuracy': 'approximate',
                  'mode': 'whenInUse',
                },
              },
            ),
          );

      expect(result.filePath, path.normalize(path.absolute(outputPath)));
      expect(await File(outputPath).readAsString(), _expectedFullHandoff);
      expect(result.handoff.appId, 'weather');
      expect(result.handoff.title, 'Weather');
      expect(
        result.handoff.artifactBaseUri.toString(),
        'https://cdn.example.com/weather',
      );
      expect(result.handoff.requestedPublisherApi['reason'], 'Load forecasts.');
      expect(
        (result.handoff.requestedPermissions['location'] as Map)['reason'],
        'Use approximate location.',
      );

      final state = result.handoff.requestedCache['state'] as Map;
      final nested = state['nested'] as Map;
      final labels = nested['labels'] as List;
      expect(() => state['enabled'] = false, throwsUnsupportedError);
      expect(() => labels.add('other'), throwsUnsupportedError);

      final reread = await const MiniProgramPartnerHandoffController()
          .readPackage(outputPath);
      expect(reread.toJson(), result.handoff.toJson());
    });

    test('preserves constructor validation order and exact errors', () {
      expect(
        () => MiniProgramPartnerHandoff(
          schemaVersion: 99,
          appId: 'invalid/id',
          title: '',
          artifactBaseUri: Uri.parse('relative/path'),
          generatedAtUtc: 'invalid',
          requestedCache: const <String, Object?>{
            'session': <String, Object?>{'enabled': true},
          },
        ),
        throwsA(
          isA<MiniProgramPartnerHandoffException>().having(
            (error) => error.message,
            'message',
            'Mini-program artifact base URL must be absolute: relative/path',
          ),
        ),
      );

      expect(
        () => MiniProgramPartnerHandoff(
          schemaVersion: 99,
          appId: 'valid_app',
          title: 'Valid',
          artifactBaseUri: Uri.parse('https://cdn.example.com/app/'),
          generatedAtUtc: 'invalid',
          requestedCache: const <String, Object?>{
            'session': <String, Object?>{'enabled': true},
          },
        ),
        throwsA(
          isA<MiniProgramPartnerHandoffException>().having(
            (error) => error.message,
            'message',
            'MiniProgram partner handoff requestedCache.session is not allowed.',
          ),
        ),
      );

      expect(
        () => MiniProgramPartnerHandoff(
          schemaVersion: 99,
          appId: 'valid_app',
          title: 'Valid',
          artifactBaseUri: Uri.parse('https://cdn.example.com/app/'),
          generatedAtUtc: 'invalid',
        ),
        throwsA(
          isA<MiniProgramPartnerHandoffException>().having(
            (error) => error.message,
            'message',
            'Unsupported MiniProgram partner handoff schema version: 99.',
          ),
        ),
      );

      expect(
        () => MiniProgramPartnerHandoff(
          appId: ' bad/id ',
          title: 'Valid',
          artifactBaseUri: Uri.parse('https://cdn.example.com/app/'),
          generatedAtUtc: '2026-07-18T00:00:00.000Z',
        ),
        throwsA(
          isA<MiniProgramPartnerHandoffException>().having(
            (error) => error.message,
            'message',
            'appId is invalid:  bad/id ',
          ),
        ),
      );
    });

    test('preserves document parsing and missing-file errors', () async {
      expect(
        () => MiniProgramPartnerHandoff.fromJson(const <Object?>[]),
        throwsA(
          isA<MiniProgramPartnerHandoffException>().having(
            (error) => error.message,
            'message',
            'MiniProgram partner handoff file must contain a JSON object.',
          ),
        ),
      );
      expect(
        () => MiniProgramPartnerHandoff.fromJson(const <String, Object?>{}),
        throwsA(
          isA<MiniProgramPartnerHandoffException>().having(
            (error) => error.message,
            'message',
            'MiniProgram partner handoff is missing "type".',
          ),
        ),
      );

      final missingPath = path.join(
        temporaryDirectory.path,
        'missing.partner.json',
      );
      await expectLater(
        const MiniProgramPartnerHandoffController().readPackage(missingPath),
        throwsA(
          isA<MiniProgramPartnerHandoffException>().having(
            (error) => error.message,
            'message',
            'MiniProgram partner handoff file does not exist: '
                '${path.normalize(path.absolute(missingPath))}',
          ),
        ),
      );
    });
  });
}

const String _expectedFullHandoff = '''{
  "schemaVersion": 3,
  "type": "mini_program_partner_handoff",
  "appId": "weather",
  "title": "Weather",
  "artifactBaseUrl": "https://cdn.example.com/weather",
  "generatedAtUtc": "2026-07-18T10:30:00.000Z",
  "requestedCache": {
    "state": {
      "enabled": true,
      "reason": "saved places",
      "recommendedMaxBytes": 1024,
      "nested": {
        "labels": [
          "home",
          "work"
        ]
      }
    }
  },
  "requestedPublisherApi": {
    "enabled": true,
    "reason": "Load forecasts.",
    "contract": "publisher_backend.json"
  },
  "requestedPermissions": {
    "location": {
      "enabled": true,
      "reason": "Use approximate location.",
      "accuracy": "approximate",
      "mode": "whenInUse"
    }
  }
}
''';
