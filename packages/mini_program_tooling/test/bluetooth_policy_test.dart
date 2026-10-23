import 'dart:convert';
import 'dart:io';

import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/host_endpoint/bluetooth_policy.dart';
import 'package:mini_program_tooling/src/host_integration/capabilities/bluetooth/manifest_editor.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:test/test.dart';

void main() {
  test(
    'BLE manifest setup ignores commented permissions and rejects restrictive host declarations',
    () {
      const manifest =
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application /></manifest>';
      final commented = manifest.replaceFirst(
        '<application',
        '<!-- <uses-permission android:name="android.permission.BLUETOOTH_SCAN" /> -->\n<application',
      );
      final patched = patchBluetoothManifest(commented);
      expect(
        patched,
        contains('android:usesPermissionFlags="neverForLocation"'),
      );
      expect(patchBluetoothManifest(patched), patched);
      for (final permission in [
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="28" />',
        '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" tools:node="remove" />',
        '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="not_neverForLocation" />',
      ]) {
        expect(
          () => patchBluetoothManifest(
            manifest.replaceFirst('<application', '$permission<application'),
          ),
          throwsA(anything),
        );
      }
      final hostLocation = manifest.replaceFirst(
        '<application',
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" /><application',
      );
      expect(
        patchBluetoothManifest(hostLocation),
        contains('android.permission.ACCESS_FINE_LOCATION" />'),
      );
    },
  );
  test(
    'BLE requests stay denied, preserve host edits and generate accepted policy only',
    () async {
      final temp = await Directory.systemTemp.createTemp('ble_policy_');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/policies.json');
      final requested = normalizePartnerHandoffRequestedPermissions({
        'bluetooth': {
          'enabled': true,
          'reason': 'Read the shop sensor',
          'write': true,
          'serviceUuids': ['180D'],
          'recommendedMaxDevices': 5,
        },
      });
      Future<Map<String, Object?>> update({
        bool accept = false,
        bool force = false,
      }) => upsertHostPolicyFile(
        policyFile: file,
        appId: 'sensor',
        sourcePath: 'sensor.partner.json',
        requestedCache: {},
        requestedPublisherApi: {},
        requestedPermissions: requested,
        acceptRequestedPolicy: accept,
        forceAcceptedPolicy: force,
      );
      Map ble(Map doc) =>
          (doc['apps'] as Map)['sensor']['accepted']['permissions']['bluetooth']
              as Map;
      expect(ble(await update())['enabled'], false);
      final accepted = await update(accept: true);
      expect(ble(accepted)['enabled'], true);
      expect(ble(accepted)['allowWrite'], true);
      expect(ble(accepted)['maxDevices'], 5);
      ble(accepted)['allowWrite'] = false;
      ble(accepted)['maxDevices'] = 2;
      ble(accepted)['hostCustomField'] = 'keep';
      await file.writeAsString(jsonEncode(accepted));
      final retained = await update();
      expect(ble(retained)['allowWrite'], false);
      expect(ble(retained)['hostCustomField'], 'keep');
      final resolver = buildHostPolicyResolverFile(retained);
      expect(resolver, contains('allowWrite: false'));
      expect(resolver, contains('maxDevices: 2'));
      expect(resolver, contains('0000180d-0000-1000-8000-00805f9b34fb'));
      expect(ble(await update(force: true))['enabled'], false);
    },
  );
  test(
    'BLE policy rejects invalid limits, unsafe UUIDs, and unknown requested authority',
    () {
      for (final patch in [
        {'maxDevices': 65},
        {'maxScanMs': 0},
        {'maxValueBytes': 513},
        {'allowWrite': 1},
        {
          'allowedServices': ['invalid'],
        },
      ]) {
        expect(
          () => validateAcceptedBluetoothPermission(patch),
          throwsA(anything),
        );
      }
      for (final patch in [
        {
          'serviceUuids': ['bad'],
        },
        {'background': true},
        {'write': 'yes'},
        {'recommendedMaxDevices': 65},
      ]) {
        expect(
          () => normalizePartnerHandoffRequestedPermissions({
            'bluetooth': {'enabled': true, 'reason': 'Read sensor', ...patch},
          }),
          throwsA(anything),
        );
      }
    },
  );
}
