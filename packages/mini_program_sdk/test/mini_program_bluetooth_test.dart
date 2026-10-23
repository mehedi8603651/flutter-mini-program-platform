import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

const _device = 'ble_1234567890123456';
const _service = '0000180d-0000-1000-8000-00805f9b34fb';
const _characteristic = '00002a37-0000-1000-8000-00805f9b34fb';

void main() {
  test(
    'BLE policy gates writes/services and clamps scan limits before native access',
    () async {
      final provider = _Provider();
      final manager = MiniProgramBluetoothManager(provider);
      addTearDown(manager.dispose);
      Future<Map<String, dynamic>> run(
        String action,
        Map<String, dynamic> args,
        MiniProgramBluetoothPolicy policy,
      ) => manager.run(
        miniProgramId: 'shop',
        action: action,
        arguments: args,
        policy: policy,
      );
      await expectLater(
        run('bluetooth.scan', {}, const MiniProgramBluetoothPolicy()),
        throwsA(
          isA<MiniProgramBluetoothException>().having(
            (e) => e.errorCode,
            'code',
            'bluetooth_not_accepted',
          ),
        ),
      );
      await run(
        'bluetooth.scan',
        {'timeoutMs': 15000, 'maxDevices': 64},
        const MiniProgramBluetoothPolicy(
          enabled: true,
          allowedServices: ['180d'],
          maxScanMs: 1000,
          maxDevices: 1,
        ),
      );
      expect(provider.args['timeoutMs'], 1000);
      expect(provider.args['maxDevices'], 1);
      expect(provider.args['serviceUuids'], [_service]);
      final count = provider.calls;
      await expectLater(
        run('bluetooth.write', {
          'serviceUuid': _service,
          'characteristicUuid': _characteristic,
          'valueHex': '01',
        }, const MiniProgramBluetoothPolicy(enabled: true)),
        throwsA(isA<MiniProgramBluetoothException>()),
      );
      await expectLater(
        run(
          'bluetooth.read',
          {'serviceUuid': '180f', 'characteristicUuid': _characteristic},
          const MiniProgramBluetoothPolicy(
            enabled: true,
            allowedServices: ['180d'],
          ),
        ),
        throwsA(isA<MiniProgramBluetoothException>()),
      );
      await expectLater(
        run('bluetooth.connect', {
          'deviceId': 'ble_9999999999999999',
        }, const MiniProgramBluetoothPolicy(enabled: true)),
        throwsA(isA<MiniProgramBluetoothException>()),
      );
      expect(provider.calls, count);
    },
  );
  test(
    'BLE notifications are scoped, bounded and detached on session release',
    () async {
      final provider = _Provider();
      final manager = MiniProgramBluetoothManager(provider);
      addTearDown(manager.dispose);
      const policy = MiniProgramBluetoothPolicy(
        enabled: true,
        maxValueBytes: 2,
      );
      Future<Map<String, dynamic>> run(
        String action, [
        Map<String, dynamic> args = const {},
      ]) => manager.run(
        miniProgramId: 'shop',
        action: action,
        arguments: args,
        policy: policy,
        onValue: (data) {
          provider.received.add(data);
          return true;
        },
      );
      await run('bluetooth.scan');
      await run('bluetooth.connect', {'deviceId': _device});
      await run('bluetooth.subscribe', {
        'serviceUuid': _service,
        'characteristicUuid': _characteristic,
      });
      provider.emit(appId: 'other');
      provider.emit(session: 'old-session');
      expect(provider.received, isEmpty);
      provider.emit();
      expect(provider.received.single['valueHex'], '0102');
      provider.emit(value: '000000');
      await Future<void>.delayed(Duration.zero);
      expect(provider.releases, 1);
      provider.emit();
      expect(provider.received.length, 1);
    },
  );
  test(
    'BLE rejects stale completion, releases exact session and preserves new owner',
    () async {
      final provider = _Provider()
        ..pendingScan = Completer<Map<String, dynamic>>();
      final manager = MiniProgramBluetoothManager(provider);
      addTearDown(manager.dispose);
      final pending = manager.run(
        miniProgramId: 'shop',
        action: 'bluetooth.scan',
        arguments: {},
        policy: const MiniProgramBluetoothPolicy(enabled: true),
      );
      final expectation = expectLater(
        pending,
        throwsA(
          isA<MiniProgramBluetoothException>().having(
            (e) => e.errorCode,
            'code',
            'bluetooth_request_cancelled',
          ),
        ),
      );
      await manager.releaseFor('shop');
      final oldSession = provider.sessionId;
      final oldScan = provider.pendingScan!;
      provider.pendingScan = null;
      await manager.run(
        miniProgramId: 'shop',
        action: 'bluetooth.scan',
        arguments: {},
        policy: const MiniProgramBluetoothPolicy(enabled: true),
      );
      final newSession = provider.sessionId;
      expect(newSession, isNot(oldSession));
      oldScan.complete({'devices': []});
      await expectation;
      expect(provider.releasedSessions.toSet(), {oldSession});
      final connected = await manager.run(
        miniProgramId: 'shop',
        action: 'bluetooth.connect',
        arguments: {'deviceId': _device},
        policy: const MiniProgramBluetoothPolicy(enabled: true),
      );
      expect(connected['connected'], true);
      expect(provider.sessionId, newSession);
    },
  );
  test(
    'BLE refuses concurrent operations and cleans invalid provider data',
    () async {
      final provider = _Provider()
        ..pendingScan = Completer<Map<String, dynamic>>();
      final manager = MiniProgramBluetoothManager(provider);
      addTearDown(manager.dispose);
      final pending = manager.run(
        miniProgramId: 'shop',
        action: 'bluetooth.scan',
        arguments: {},
        policy: const MiniProgramBluetoothPolicy(enabled: true),
      );
      final expectation = expectLater(
        pending,
        throwsA(
          isA<MiniProgramBluetoothException>().having(
            (e) => e.errorCode,
            'code',
            'bluetooth_invalid_result',
          ),
        ),
      );
      await expectLater(
        manager.run(
          miniProgramId: 'shop',
          action: 'bluetooth.getState',
          arguments: {},
          policy: const MiniProgramBluetoothPolicy(enabled: true),
        ),
        throwsA(
          isA<MiniProgramBluetoothException>().having(
            (e) => e.errorCode,
            'code',
            'bluetooth_request_in_progress',
          ),
        ),
      );
      provider.pendingScan!.complete({
        'devices': [
          {'deviceId': 'native address'},
        ],
      });
      await expectation;
      expect(provider.releases, 1);
    },
  );
  test(
    'BLE keeps its listener on failed unsubscribe and allows cleanup after policy revocation',
    () async {
      final provider = _Provider();
      final manager = MiniProgramBluetoothManager(provider);
      addTearDown(manager.dispose);
      Future<Map<String, dynamic>> run(
        String action,
        Map<String, dynamic> args, {
        MiniProgramBluetoothPolicy policy = const MiniProgramBluetoothPolicy(
          enabled: true,
        ),
      }) => manager.run(
        miniProgramId: 'shop',
        action: action,
        arguments: args,
        policy: policy,
        onValue: (data) {
          provider.received.add(data);
          return true;
        },
      );
      await run('bluetooth.scan', {});
      await run('bluetooth.connect', {'deviceId': _device});
      final args = {
        'serviceUuid': _service,
        'characteristicUuid': _characteristic,
      };
      await run('bluetooth.subscribe', args);
      provider.deniedAction = 'bluetooth.unsubscribe';
      await expectLater(
        run('bluetooth.unsubscribe', args),
        throwsA(isA<MiniProgramBluetoothException>()),
      );
      provider.emit();
      expect(provider.received.length, 1);
      provider.deniedAction = null;
      await run(
        'bluetooth.unsubscribe',
        args,
        policy: const MiniProgramBluetoothPolicy(allowedServices: ['180f']),
      );
      provider.emit();
      expect(provider.received.length, 1);
      await run(
        'bluetooth.disconnect',
        {},
        policy: const MiniProgramBluetoothPolicy(maxScanMs: 0),
      );
      expect(provider.releases, 1);
    },
  );
  test(
    'BLE notification receiver rejection releases the exact session',
    () async {
      final provider = _Provider();
      final manager = MiniProgramBluetoothManager(provider);
      addTearDown(manager.dispose);
      await manager.run(
        miniProgramId: 'shop',
        action: 'bluetooth.subscribe',
        arguments: {
          'serviceUuid': _service,
          'characteristicUuid': _characteristic,
        },
        policy: const MiniProgramBluetoothPolicy(enabled: true),
        onValue: (_) => false,
      );
      final session = provider.sessionId;
      provider.emit();
      await Future<void>.delayed(Duration.zero);
      expect(provider.releasedSessions, [session]);
      provider.emit();
      expect(provider.releasedSessions, [session]);
    },
  );
}

class _Provider implements MiniProgramBluetoothProvider {
  final controller = StreamController<MiniProgramBluetoothEvent>.broadcast(
    sync: true,
  );
  final received = <Map<String, dynamic>>[];
  final releasedSessions = <String>[];
  int calls = 0;
  int releases = 0;
  String sessionId = '';
  Map<String, dynamic> args = {};
  Completer<Map<String, dynamic>>? pendingScan;
  String? deniedAction;
  @override
  Stream<MiniProgramBluetoothEvent> get events => controller.stream;
  @override
  Future<Map<String, dynamic>> invoke({
    required String miniProgramId,
    required String sessionId,
    required String action,
    required Map<String, dynamic> arguments,
  }) async {
    calls++;
    this.sessionId = sessionId;
    args = arguments;
    if (action == deniedAction) {
      throw const MiniProgramBluetoothException(
        errorCode: 'bluetooth_request_in_progress',
        message: 'A GATT operation is pending.',
      );
    }
    return switch (action) {
      'bluetooth.scan' =>
        pendingScan?.future ??
            Future.value({
              'devices': [
                {
                  'deviceId': _device,
                  'name': 'Sensor',
                  'rssi': -40,
                  'serviceUuids': [_service],
                },
              ],
            }),
      'bluetooth.connect' => {'connected': true, 'deviceId': _device},
      'bluetooth.subscribe' => {'subscribed': true},
      'bluetooth.unsubscribe' => {'subscribed': false},
      _ => {'available': true, 'enabled': true, 'permissionGranted': true},
    };
  }

  void emit({String appId = 'shop', String? session, String value = '0102'}) =>
      controller.add(
        MiniProgramBluetoothEvent(
          miniProgramId: appId,
          sessionId: session ?? sessionId,
          type: 'notification',
          data: {
            'serviceUuid': _service,
            'characteristicUuid': _characteristic,
            'valueHex': value,
          },
        ),
      );
  @override
  Future<void> release({
    required String miniProgramId,
    required String sessionId,
  }) async {
    releases++;
    releasedSessions.add(sessionId);
  }
}
