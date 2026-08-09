import 'dart:io';

import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('display brightness is denied safely and accepted explicitly', () async {
    final requested = normalizePartnerHandoffRequestedPermissions(
      <String, Object?>{
        'displayBrightness': <String, Object?>{
          'enabled': true,
          'reason': 'Make an on-screen QR code easier to scan.',
          'recommendedMaxLevel': 0.9,
        },
      },
    );
    final directory = await Directory.systemTemp.createTemp(
      'display_brightness_policy_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'mini_program_policies.json'));

    final denied = await upsertHostPolicyFile(
      policyFile: file,
      appId: 'friends',
      sourcePath: 'friends.partner.json',
      requestedCache: const <String, Object?>{},
      requestedPublisherApi: const <String, Object?>{},
      requestedPermissions: requested,
      acceptRequestedPolicy: false,
      forceAcceptedPolicy: false,
    );
    expect(_permission(denied)['enabled'], isFalse);

    final accepted = await upsertHostPolicyFile(
      policyFile: file,
      appId: 'friends',
      sourcePath: 'friends.partner.json',
      requestedCache: const <String, Object?>{},
      requestedPublisherApi: const <String, Object?>{},
      requestedPermissions: requested,
      acceptRequestedPolicy: true,
      forceAcceptedPolicy: false,
    );
    expect(_permission(accepted), <String, Object?>{
      'enabled': true,
      'maxLevel': 0.9,
    });

    final resolver = buildHostPolicyResolverFile(accepted);
    expect(
      resolver,
      contains(
        'MiniProgramDisplayBrightnessPolicy '
        'displayBrightnessPolicyForMiniProgram',
      ),
    );
    expect(resolver, contains('maxLevel: 0.9'));
  });

  test('display brightness rejects an invalid recommended level', () {
    expect(
      () => normalizePartnerHandoffRequestedPermissions(<String, Object?>{
        'displayBrightness': <String, Object?>{
          'enabled': true,
          'reason': 'Invalid level.',
          'recommendedMaxLevel': 2,
        },
      }),
      throwsA(anything),
    );
  });
}

Map<String, Object?> _permission(Map<String, Object?> document) {
  final apps = Map<String, Object?>.from(document['apps']! as Map);
  final app = Map<String, Object?>.from(apps['friends']! as Map);
  final accepted = Map<String, Object?>.from(app['accepted']! as Map);
  final permissions = Map<String, Object?>.from(
    accepted['permissions']! as Map,
  );
  return Map<String, Object?>.from(permissions['displayBrightness']! as Map);
}
