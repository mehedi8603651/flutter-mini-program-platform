import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/host_endpoint/nfc_policy.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/nfc/manifest_editor.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:test/test.dart';

void main() {
  test('NFC manifest is idempotent and leaves host hardware requirements intact', () {
    const manifest =
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application /></manifest>';
    final commented = manifest.replaceFirst(
      '<application',
      '<!-- <uses-permission android:name="android.permission.NFC" /> --><application',
    );
    final patched = patchNfcManifest(commented);
    expect(patched, contains('android.hardware.nfc" android:required="false"'));
    expect(patchNfcManifest(patched), patched);
    final hostRequired = patched.replaceAll(
      'android:required="false"',
      'android:required="true"',
    );
    expect(patchNfcManifest(hostRequired), hostRequired);
    for (final declaration in [
      '<uses-permission android:name="android.permission.NFC" android:maxSdkVersion="30" />',
      '<uses-permission android:name="android.permission.NFC" tools:node="remove" />',
      '<uses-feature android:name="android.hardware.nfc" tools:node="remove" />',
      '<uses-permission android:name="android.permission.NFC" /><uses-permission android:name="android.permission.NFC" />',
    ]) {
      expect(
        () => patchNfcManifest(
          manifest.replaceFirst('<application', '$declaration<application'),
        ),
        throwsA(anything),
      );
    }
  });
  test(
    'NFC requested policy stays advisory and host acceptance survives reimport',
    () async {
      final temp = await Directory.systemTemp.createTemp('nfc_policy_');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/policies.json');
      final requested = normalizePartnerHandoffRequestedPermissions({
        'nfc': {
          'enabled': true,
          'reason': 'Read product tags',
          'recordTypes': ['text'],
          'recommendedMaxRecords': 2,
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
        requestedPermissions: requested,
        acceptRequestedPolicy: accept,
        forceAcceptedPolicy: force,
      );
      Map nfc(Map doc) =>
          (doc['apps'] as Map)['shop']['accepted']['permissions']['nfc'] as Map;
      final initial = await update();
      expect(nfc(initial)['enabled'], false);
      expect(
        buildHostPolicyResolverFile(initial),
        contains('MiniProgramNfcPolicy(enabled: false'),
      );
      final accepted = await update(accept: true);
      expect(nfc(accepted)['enabled'], true);
      expect(nfc(accepted)['allowedRecordTypes'], ['text']);
      nfc(accepted)['maxRecords'] = 1;
      nfc(accepted)['hostCustomField'] = 'keep';
      await file.writeAsString(jsonEncode(accepted));
      final retained = await update();
      expect(nfc(retained)['maxRecords'], 1);
      expect(nfc(retained)['hostCustomField'], 'keep');
      final resolver = buildHostPolicyResolverFile(retained);
      expect(resolver, contains('allowedRecordTypes: ["text"]'));
      expect(resolver, contains('maxRecords: 1'));
      expect(nfc(await update(force: true))['enabled'], false);
    },
  );
  test(
    'NFC rejects unsupported requested authority and invalid accepted limits',
    () {
      for (final patch in [
        {'maxRecords': 17},
        {'maxReadMs': 999},
        {'maxMessageBytes': 8193},
        {'enabled': 'yes'},
        {'allowedRecordTypes': []},
        {
          'allowedRecordTypes': ['payment'],
        },
      ]) {
        expect(() => validateAcceptedNfcPermission(patch), throwsA(anything));
      }
      for (final patch in [
        {'write': true},
        {'background': true},
        {'recommendedMaxRecords': 17},
        {
          'recordTypes': ['apdu'],
        },
        {'reason': ''},
      ]) {
        expect(
          () => normalizePartnerHandoffRequestedPermissions({
            'nfc': {'enabled': true, 'reason': 'Read tags', ...patch},
          }),
          throwsA(anything),
        );
      }
    },
  );
}
