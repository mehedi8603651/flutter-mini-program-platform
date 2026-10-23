import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('BLE UUIDs normalize while device handles stay opaque', () {
    expect(
      MiniProgramBluetooth.uuid('180D'),
      '0000180d-0000-1000-8000-00805f9b34fb',
    );
    expect(
      MiniProgramBluetooth.uuid('12345678'),
      '12345678-0000-1000-8000-00805f9b34fb',
    );
    for (final value in [
      'AA:BB:CC:DD:EE:FF',
      '',
      '../../device',
      'ble_short',
    ]) {
      expect(() => MiniProgramBluetooth.deviceId(value), throwsFormatException);
    }
    for (final value in ['180', '180D ', '{180d}', 'g800']) {
      expect(() => MiniProgramBluetooth.uuid(value), throwsFormatException);
    }
  });
  test(
    'BLE arguments enforce operations, payload limits and binding phase',
    () {
      expect(
        MiniProgramBluetooth.arguments('bluetooth.read', {
          'serviceUuid': '180d',
          'characteristicUuid': '{{state.characteristic}}',
        }, allowBindings: true)['characteristicUuid'],
        '{{state.characteristic}}',
      );
      expect(
        () => MiniProgramBluetooth.arguments('bluetooth.read', {
          'serviceUuid': '180d',
          'characteristicUuid': '{{state.characteristic}}',
        }),
        throwsFormatException,
      );
      for (final args in [
        {'timeoutMs': 15001},
        {'timeoutMs': 1.5},
        {'maxDevices': 65},
        {
          'serviceUuids': ['bad'],
        },
        {'address': 'AA:BB:CC:DD:EE:FF'},
      ]) {
        expect(
          () => MiniProgramBluetooth.arguments('bluetooth.scan', args),
          throwsFormatException,
        );
      }
      for (final hex in ['a', 'zz', '00 ', '00' * 21, '']) {
        expect(
          () => MiniProgramBluetooth.arguments('bluetooth.write', {
            'serviceUuid': '180d',
            'characteristicUuid': '2a37',
            'valueHex': hex,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test('BLE output strips native metadata and rejects oversized values', () {
    final device = {
      'deviceId': 'ble_1234567890123456',
      'name': 'Scale',
      'rssi': -45,
      'serviceUuids': ['180d'],
      'address': 'AA:BB:CC:DD:EE:FF',
      'raw': [1, 2, 3],
    };
    final result = MiniProgramBluetooth.result('bluetooth.scan', {
      'devices': [device],
    });
    expect((result['devices'] as List).single, {
      'deviceId': 'ble_1234567890123456',
      'name': 'Scale',
      'rssi': -45,
      'serviceUuids': ['0000180d-0000-1000-8000-00805f9b34fb'],
    });
    expect(
      () => MiniProgramBluetooth.result('bluetooth.scan', {
        'devices': [device, device],
      }),
      throwsFormatException,
    );
    expect(
      () => MiniProgramBluetooth.result('bluetooth.notification', {
        'serviceUuid': '180d',
        'characteristicUuid': '2a37',
        'valueHex': '00' * 513,
      }),
      throwsFormatException,
    );
  });
}
