import 'dart:convert';

import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('public BLE authoring emits explicit deterministic pure-Dart actions', () {
    final scan = Mp.bluetooth.scan(
      serviceUuids: ['180D'],
      targetState: 'ble.devices',
    );
    expect(scan.toJson(), {
      'type': 'bluetooth.scan',
      'props': {
        'serviceUuids': ['0000180d-0000-1000-8000-00805f9b34fb'],
        'timeoutMs': 5000,
        'maxDevices': 20,
        'targetState': 'ble.devices',
      },
    });
    final actions = [
      Mp.bluetooth.getState(),
      scan,
      Mp.bluetooth.stopScan(),
      Mp.bluetooth.connect(deviceId: '{{item.deviceId}}'),
      Mp.bluetooth.disconnect(),
      Mp.bluetooth.discoverServices(targetState: 'ble.services'),
      Mp.bluetooth.read(
        serviceUuid: '180d',
        characteristicUuid: '2a37',
        targetState: 'ble.value',
      ),
      Mp.bluetooth.write(
        serviceUuid: '180d',
        characteristicUuid: '2a37',
        valueHex: 'AABB',
      ),
      Mp.bluetooth.subscribe(
        serviceUuid: '180d',
        characteristicUuid: '2a37',
        targetState: 'ble.latest',
      ),
      Mp.bluetooth.unsubscribe(serviceUuid: '180d', characteristicUuid: '2a37'),
    ];
    expect(actions.map((a) => a.type).toSet().length, 10);
    expect(
      jsonEncode(scan.toJson()),
      '{"type":"bluetooth.scan","props":{"maxDevices":20,"serviceUuids":["0000180d-0000-1000-8000-00805f9b34fb"],"targetState":"ble.devices","timeoutMs":5000}}',
    );
    expect((actions[7].toJson()['props'] as Map)['valueHex'], 'aabb');
  });
  test('BLE authoring rejects unsafe values and overlapping output state', () {
    expect(
      () => Mp.bluetooth.connect(deviceId: 'AA:BB:CC:DD:EE:FF'),
      throwsA(anything),
    );
    expect(
      () => Mp.bluetooth.scan(targetState: 'ble', errorState: 'ble.error'),
      throwsArgumentError,
    );
    expect(
      () => Mp.bluetooth.scan(targetState: 'ble.devices', maxDevices: 100),
      throwsFormatException,
    );
    expect(
      () => Mp.bluetooth.write(
        serviceUuid: '180d',
        characteristicUuid: '2a37',
        valueHex: '00' * 21,
      ),
      throwsFormatException,
    );
  });
}
