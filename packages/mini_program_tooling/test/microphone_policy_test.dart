import 'dart:io';
import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:test/test.dart';

void main() {
  test(
    'microphone requires explicit host acceptance and preserves accepted limits',
    () async {
      final requested = normalizePartnerHandoffRequestedPermissions({
        'microphone': {
          'enabled': true,
          'reason': 'Record a voice note.',
          'recommendedMaxDurationSeconds': 3,
        },
      });
      final directory = await Directory.systemTemp.createTemp(
        'microphone_policy_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/policy.json');
      Future<Map<String, Object?>> update(bool accept, {bool force = false}) =>
          upsertHostPolicyFile(
            policyFile: file,
            appId: 'photos',
            sourcePath: 'photos.partner.json',
            requestedCache: {},
            requestedPublisherApi: {},
            requestedPermissions: requested,
            acceptRequestedPolicy: accept,
            forceAcceptedPolicy: force,
          );
      Map microphone(Map document) =>
          (((document['apps'] as Map)['photos'] as Map)['accepted']
                  as Map)['permissions']['microphone']
              as Map;
      final denied = await update(false);
      expect(microphone(denied)['enabled'], isFalse);
      final accepted = await update(true);
      expect(microphone(accepted), containsPair('maxDurationSeconds', 3));
      expect(microphone(accepted)['enabled'], isTrue);
      final resolver = buildHostPolicyResolverFile(accepted);
      expect(
        resolver,
        contains('MiniProgramMicrophonePolicy microphonePolicyForMiniProgram'),
      );
      expect(resolver, contains('maxDurationSeconds: 3'));
      expect(microphone(await update(false))['enabled'], isTrue);
      expect(microphone(await update(false, force: true))['enabled'], isFalse);
    },
  );
  test('rejects malformed requested and accepted limits', () {
    for (final patch in <Map<String, Object?>>[
      {'recommendedMaxDurationSeconds': 601},
      {'recommendedMaxDurationSeconds': 1.5},
      {'recommendedMaxBytes': -1},
      {'recommendedMaxBytes': 104857601},
      {'url': 'content://photos'},
      {'enabled': 'yes'},
    ]) {
      expect(
        () => normalizePartnerHandoffRequestedPermissions({
          'microphone': {
            'enabled': true,
            'reason': 'Record a voice note.',
            ...patch,
          },
        }),
        throwsA(anything),
      );
    }
    expect(
      () => validateAcceptedHostPermissions({
        'microphone': {'enabled': true, 'maxDurationSeconds': 0},
      }),
      throwsA(anything),
    );
    final accepted = validateAcceptedHostPermissions({
      'microphone': {'enabled': true, 'customHostField': 'keep'},
    });
    expect(accepted['microphone'], containsPair('customHostField', 'keep'));
  });
}
