import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test(
    'partner handoff public API remains available from the package barrel',
    () {
      final handoff = MiniProgramPartnerHandoff(
        appId: 'public_handoff',
        title: 'Public Handoff',
        artifactBaseUri: Uri.parse('https://cdn.example.com/public_handoff/'),
        generatedAtUtc: '2026-07-18T00:00:00.000Z',
      );
      const request = MiniProgramPartnerPackageRequest(
        appId: 'public_handoff',
        title: 'Public Handoff',
      );
      final result = MiniProgramPartnerPackageResult(
        filePath: 'public_handoff.partner.json',
        handoff: handoff,
      );
      const exception = MiniProgramPartnerHandoffException('handoff failed');
      const controller = MiniProgramPartnerHandoffController();

      expect(
        request.schemaVersion,
        MiniProgramPartnerHandoff.currentSchemaVersion,
      );
      expect(controller, isA<MiniProgramPartnerHandoffController>());
      expect(exception.toString(), 'handoff failed');
      expect(result.handoff, same(handoff));
      expect(handoff.apiBaseUri, handoff.artifactBaseUri);
      expect(handoff.toJson().keys.toList(), <String>[
        'schemaVersion',
        'type',
        'appId',
        'title',
        'artifactBaseUrl',
        'generatedAtUtc',
      ]);
    },
  );
}
