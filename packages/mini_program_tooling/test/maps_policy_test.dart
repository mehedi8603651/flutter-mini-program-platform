import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:test/test.dart';

void main() {
  test(
    'map requests require acceptance, preserve host edits, and force resets access',
    () async {
      final dir = await Directory.systemTemp.createTemp('maps_policy_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/policies.json');
      final request = normalizePartnerHandoffRequestedPermissions({
        'maps': {
          'enabled': true,
          'reason': 'Open our shop and directions.',
          'openLocation': true,
          'directions': true,
        },
      });
      Future<Map<String, Object?>> update({
        bool accept = false,
        bool force = false,
      }) => upsertHostPolicyFile(
        policyFile: file,
        appId: 'shop',
        sourcePath: 'shop.partner.json',
        requestedCache: {},
        requestedPublisherApi: {},
        requestedPermissions: request,
        acceptRequestedPolicy: accept,
        forceAcceptedPolicy: force,
      );
      Map maps(Map doc) =>
          doc['apps']['shop']['accepted']['permissions']['maps'] as Map;
      final denied = await update();
      expect(maps(denied)['enabled'], isFalse);
      expect(
        buildHostPolicyResolverFile(denied),
        contains('MiniProgramMapsPolicy(enabled: false'),
      );
      final accepted = await update(accept: true);
      expect(maps(accepted)['enabled'], isTrue);
      maps(accepted)['allowDirections'] = false;
      maps(accepted)['customField'] = 'keep';
      await file.writeAsString(jsonEncode(accepted));
      final preserved = await update();
      expect(maps(preserved)['enabled'], isTrue);
      expect(maps(preserved)['allowDirections'], isFalse);
      expect(maps(preserved)['customField'], 'keep');
      final resolver = buildHostPolicyResolverFile(preserved);
      expect(
        resolver,
        contains(
          'MiniProgramMapsPolicy(enabled: true, allowOpenLocation: true, allowDirections: false)',
        ),
      );
      // Runtime reads accepted values even when publisher requests more access.
      preserved['apps'] = {
        'shop': {
          'requested': {'permissions': request},
          'accepted': {'permissions': {}},
        },
      };
      expect(
        buildHostPolicyResolverFile(preserved),
        contains('MiniProgramMapsPolicy(enabled: false'),
      );
      expect(maps(await update(force: true))['enabled'], isFalse);
    },
  );

  test(
    'maps rejects unsupported request fields and invalid accepted operations',
    () {
      for (final patch in <Map<String, Object?>>[
        {'directions': 'yes'},
        {'openLocation': 1},
        {'enabled': 1},
        {'reason': ''},
        {'openLocation': false, 'directions': false},
        {'url': 'https://evil.test'},
        {'provider': 'arbitrary'},
        {'package': 'some.app'},
        {'currentLocation': true},
      ]) {
        expect(
          () => normalizePartnerHandoffRequestedPermissions({
            'maps': {'enabled': true, 'reason': 'Shop directions', ...patch},
          }),
          throwsA(anything),
        );
      }
      for (final value in <Object?>[
        true,
        {'enabled': 'true'},
        {'allowDirections': 1},
        {'enabled': true, 'allowDirections': false, 'allowOpenLocation': false},
      ]) {
        expect(
          () => validateAcceptedHostPermissions({'maps': value}),
          throwsA(anything),
        );
      }
      expect(
        validateAcceptedHostPermissions({
          'maps': {'enabled': true, 'hostExtra': 7},
        })['maps'],
        containsPair('hostExtra', 7),
      );
    },
  );
}
