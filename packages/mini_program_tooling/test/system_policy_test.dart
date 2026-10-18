import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:test/test.dart';

void main() {
  test(
    'system requests stay denied until accepted and preserve host edits on reimport',
    () async {
      final directory = await Directory.systemTemp.createTemp('system_policy_');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/policy.json');
      final requested = normalizePartnerHandoffRequestedPermissions({
        'clipboard': {
          'enabled': true,
          'reason': 'Copy and paste booking notes.',
          'read': true,
          'write': true,
          'recommendedMaxTextLength': 128,
        },
        'vibration': {'enabled': true, 'reason': 'Confirm a selection.'},
        'phone': {'enabled': true, 'reason': 'Contact the ticket office.'},
      });
      Future<Map<String, Object?>> update({
        bool accept = false,
        bool force = false,
      }) => upsertHostPolicyFile(
        policyFile: file,
        appId: 'booking',
        sourcePath: 'booking.partner.json',
        requestedCache: {},
        requestedPublisherApi: {},
        requestedPermissions: requested,
        acceptRequestedPolicy: accept,
        forceAcceptedPolicy: force,
      );
      Map permissions(Map doc) =>
          ((doc['apps'] as Map)['booking'] as Map)['accepted']['permissions']
              as Map;
      final denied = await update();
      for (final feature in ['clipboard', 'vibration', 'phone']) {
        expect(permissions(denied)[feature]['enabled'], isFalse);
      }
      expect(permissions(denied)['clipboard']['allowRead'], isFalse);
      final accepted = await update(accept: true);
      expect(permissions(accepted)['clipboard']['allowRead'], isTrue);
      expect(permissions(accepted)['clipboard']['maxTextLength'], 128);
      permissions(accepted)['clipboard']['maxTextLength'] = 32;
      permissions(accepted)['clipboard']['allowRead'] = false;
      permissions(accepted)['clipboard']['customHostField'] = 'keep';
      await file.writeAsString(jsonEncode(accepted));
      final preserved = await update();
      expect(permissions(preserved)['clipboard']['allowRead'], isFalse);
      expect(permissions(preserved)['clipboard']['maxTextLength'], 32);
      expect(permissions(preserved)['clipboard']['customHostField'], 'keep');
      final resolver = buildHostPolicyResolverFile(preserved);
      expect(
        resolver,
        contains('allowRead: false, allowWrite: true, maxTextLength: 32'),
      );
      expect(resolver, contains('MiniProgramPhonePolicy(enabled: true)'));
      final forced = await update(force: true);
      for (final feature in ['clipboard', 'vibration', 'phone']) {
        expect(permissions(forced)[feature]['enabled'], isFalse);
      }
    },
  );

  test(
    'clipboard read is opt-in and invalid requests or accepted types fail',
    () {
      final requested = normalizePartnerHandoffRequestedPermissions({
        'clipboard': {'enabled': true, 'reason': 'Copy a ticket code.'},
      });
      expect((requested['clipboard'] as Map)['read'], isFalse);
      for (final patch in [
        {'read': 'yes'},
        {'write': 1},
        {'recommendedMaxTextLength': 32769},
        {'recommendedMaxTextLength': 0},
        {'recommendedMaxTextLength': 1.5},
        {'read': false, 'write': false},
        {'monitor': true},
      ]) {
        expect(
          () => normalizePartnerHandoffRequestedPermissions({
            'clipboard': {
              'enabled': true,
              'reason': 'Copy a ticket code.',
              ...patch,
            },
          }),
          throwsA(anything),
        );
      }
      for (final permission in ['clipboard', 'phone', 'vibration']) {
        expect(
          () => validateAcceptedHostPermissions({
            permission: {'enabled': 'true'},
          }),
          throwsA(anything),
        );
        expect(
          () => validateAcceptedHostPermissions({permission: true}),
          throwsA(anything),
        );
      }
      expect(
        () => validateAcceptedHostPermissions({
          'clipboard': {'enabled': true, 'allowRead': 'yes'},
        }),
        throwsA(anything),
      );
      expect(
        () => normalizePartnerHandoffRequestedPermissions({
          'phone': {'enabled': true, 'reason': 'Call', 'directCall': true},
        }),
        throwsA(anything),
      );
      expect(
        () => normalizePartnerHandoffRequestedPermissions({
          'vibration': {
            'enabled': true,
            'reason': 'Confirm',
            'pattern': [1, 2],
          },
        }),
        throwsA(anything),
      );
    },
  );
}
