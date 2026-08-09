import 'dart:io';

import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('share request is normalized and accepted only explicitly', () async {
    final requested = normalizePartnerHandoffRequestedPermissions(
      <String, Object?>{
        'share': <String, Object?>{
          'enabled': true,
          'reason': 'Share notes and captured photos.',
          'text': true,
          'urls': true,
          'media': true,
          'recommendedMaxMediaItems': 4,
        },
      },
    );
    final directory = await Directory.systemTemp.createTemp('share_policy_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'mini_program_policies.json'));

    final denied = await upsertHostPolicyFile(
      policyFile: file,
      appId: 'notes',
      sourcePath: 'notes.partner.json',
      requestedCache: const <String, Object?>{},
      requestedPublisherApi: const <String, Object?>{},
      requestedPermissions: requested,
      acceptRequestedPolicy: false,
      forceAcceptedPolicy: false,
    );
    final deniedShare = _sharePermission(denied);
    expect(deniedShare['enabled'], isFalse);

    final accepted = await upsertHostPolicyFile(
      policyFile: file,
      appId: 'notes',
      sourcePath: 'notes.partner.json',
      requestedCache: const <String, Object?>{},
      requestedPublisherApi: const <String, Object?>{},
      requestedPermissions: requested,
      acceptRequestedPolicy: true,
      forceAcceptedPolicy: false,
    );
    final acceptedShare = _sharePermission(accepted);
    expect(acceptedShare, containsPair('enabled', true));
    expect(acceptedShare, containsPair('allowMedia', true));
    expect(acceptedShare, containsPair('maxMediaItems', 4));

    final resolver = buildHostPolicyResolverFile(accepted);
    expect(
      resolver,
      contains('MiniProgramSharePolicy sharePolicyForMiniProgram'),
    );
    expect(resolver, contains('maxMediaItems: 4'));
  });

  test('share request rejects enabled policy without content types', () {
    expect(
      () => normalizePartnerHandoffRequestedPermissions(<String, Object?>{
        'share': <String, Object?>{
          'enabled': true,
          'reason': 'Nothing requested.',
          'text': false,
          'urls': false,
          'media': false,
        },
      }),
      throwsA(anything),
    );
  });
}

Map<String, Object?> _sharePermission(Map<String, Object?> document) {
  final apps = Map<String, Object?>.from(document['apps']! as Map);
  final app = Map<String, Object?>.from(apps['notes']! as Map);
  final accepted = Map<String, Object?>.from(app['accepted']! as Map);
  final permissions = Map<String, Object?>.from(
    accepted['permissions']! as Map,
  );
  return Map<String, Object?>.from(permissions['share']! as Map);
}
