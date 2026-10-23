/// Shared, bounded BLE wire values. Native addresses never cross this boundary.
abstract final class MiniProgramBluetooth {
  static const actions = <String>{
    'bluetooth.getState',
    'bluetooth.scan',
    'bluetooth.stopScan',
    'bluetooth.connect',
    'bluetooth.disconnect',
    'bluetooth.discoverServices',
    'bluetooth.read',
    'bluetooth.write',
    'bluetooth.subscribe',
    'bluetooth.unsubscribe',
  };
  static const maxDevices = 64;
  static const maxScanMs = 15000;
  static const maxValueBytes = 512;
  // A single ATT write fits the default MTU on every supported connection.
  static const maxWriteBytes = 20;
  static const maxSubscriptions = 8;

  static String uuid(Object? value) {
    if (value is! String) throw const FormatException('Invalid BLE UUID.');
    var text = value.toLowerCase();
    if (RegExp(r'^[0-9a-f]{4}$').hasMatch(text)) text = '0000$text';
    if (RegExp(r'^[0-9a-f]{8}$').hasMatch(text)) {
      text = '$text-0000-1000-8000-00805f9b34fb';
    }
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(text)) {
      throw const FormatException('Invalid BLE UUID.');
    }
    return text;
  }

  static String deviceId(Object? value) {
    if (value is! String ||
        !RegExp(r'^ble_[a-zA-Z0-9_-]{16,80}$').hasMatch(value)) {
      throw const FormatException('Expected an opaque BLE device handle.');
    }
    return value;
  }

  static String hex(
    Object? value, {
    int limit = maxValueBytes,
    bool empty = true,
  }) {
    if (value is! String ||
        value.length > limit * 2 ||
        (!empty && value.isEmpty) ||
        !RegExp(r'^(?:[0-9a-fA-F]{2})*$').hasMatch(value)) {
      throw const FormatException(
        'Expected bounded, even-length BLE hex data.',
      );
    }
    return value.toLowerCase();
  }

  static List<String> uuids(Object? value) {
    if (value is! List || value.length > 16) {
      throw const FormatException('Expected at most 16 BLE service UUIDs.');
    }
    return value.map(uuid).toSet().toList(growable: false);
  }

  static Map<String, dynamic> arguments(
    String action,
    Map<String, dynamic> raw, {
    bool allowBindings = false,
  }) {
    if (!actions.contains(action)) {
      throw const FormatException('Unknown BLE action.');
    }
    final keys = <String>{
      if (action == 'bluetooth.scan') ...[
        'serviceUuids',
        'timeoutMs',
        'maxDevices',
      ],
      if (action == 'bluetooth.connect') ...['deviceId', 'timeoutMs'],
      if (const {
        'bluetooth.read',
        'bluetooth.write',
        'bluetooth.subscribe',
        'bluetooth.unsubscribe',
      }.contains(action)) ...[
        'serviceUuid',
        'characteristicUuid',
      ],
      if (action == 'bluetooth.write') ...['valueHex', 'withoutResponse'],
    };
    if (raw.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('Unknown BLE action property.');
    }
    Object bound(Object? value, Object Function(Object?) validate) {
      if (allowBindings &&
          value is String &&
          value.length <= 256 &&
          RegExp(
            r'^\{\{\s*(?:state|item|form|route)\.[^{}]+\s*\}\}$',
          ).hasMatch(value)) {
        return value;
      }
      return validate(value);
    }

    int integer(Object? value, int fallback, int minimum, int maximum) {
      value ??= fallback;
      if (value is! int || value < minimum || value > maximum) {
        throw const FormatException('Invalid BLE operation limit.');
      }
      return value;
    }

    return {
      if (action == 'bluetooth.scan') ...{
        'serviceUuids': uuids(raw['serviceUuids'] ?? const []),
        'timeoutMs': integer(raw['timeoutMs'], 5000, 500, maxScanMs),
        'maxDevices': integer(raw['maxDevices'], 20, 1, maxDevices),
      },
      if (action == 'bluetooth.connect') ...{
        'deviceId': bound(raw['deviceId'], deviceId),
        'timeoutMs': integer(raw['timeoutMs'], 10000, 1000, maxScanMs),
      },
      if (keys.contains('serviceUuid')) ...{
        'serviceUuid': bound(raw['serviceUuid'], uuid),
        'characteristicUuid': bound(raw['characteristicUuid'], uuid),
      },
      if (action == 'bluetooth.write') ...{
        'valueHex': bound(
          raw['valueHex'],
          (v) => hex(v, limit: maxWriteBytes, empty: false),
        ),
        'withoutResponse':
            raw['withoutResponse'] == null || raw['withoutResponse'] is bool
            ? raw['withoutResponse'] ?? false
            : throw const FormatException('withoutResponse must be boolean.'),
      },
    };
  }

  /// Selects known fields only, and validates all native/provider output.
  static Map<String, dynamic> result(
    String action,
    Object? raw, {
    int deviceLimit = maxDevices,
    int valueLimit = maxValueBytes,
  }) {
    if (raw is! Map) throw const FormatException('Invalid BLE result.');
    bool flag(Map value, String key) {
      if (value[key] is! bool) {
        throw const FormatException('Invalid BLE status.');
      }
      return value[key] as bool;
    }

    Map<String, dynamic> characteristic(Map value) => {
      'uuid': uuid(value['uuid']),
      for (final key in [
        'read',
        'write',
        'writeWithoutResponse',
        'notify',
        'indicate',
      ])
        key: flag(value, key),
    };
    switch (action) {
      case 'bluetooth.getState':
        return {
          for (final key in ['available', 'enabled', 'permissionGranted'])
            key: flag(raw, key),
        };
      case 'bluetooth.scan':
        final devices = raw['devices'];
        if (devices is! List || devices.length > deviceLimit) {
          throw const FormatException('Too many BLE devices.');
        }
        final seen = <String>{};
        return {
          'devices': devices
              .map((value) {
                if (value is! Map) {
                  throw const FormatException('Invalid BLE device.');
                }
                final id = deviceId(value['deviceId']);
                final name = value['name'];
                final rssi = value['rssi'];
                if (!seen.add(id) ||
                    name is! String ||
                    name.length > 80 ||
                    RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(name) ||
                    rssi is! int ||
                    rssi < -127 ||
                    rssi > 20) {
                  throw const FormatException('Invalid BLE device metadata.');
                }
                return {
                  'deviceId': id,
                  'name': name,
                  'rssi': rssi,
                  'serviceUuids': uuids(value['serviceUuids'] ?? const []),
                };
              })
              .toList(growable: false),
        };
      case 'bluetooth.connect':
        return {
          'deviceId': deviceId(raw['deviceId']),
          'connected': flag(raw, 'connected'),
        };
      case 'bluetooth.discoverServices':
        final services = raw['services'];
        if (services is! List || services.length > 32) {
          throw const FormatException('Too many BLE services.');
        }
        var count = 0;
        return {
          'services': services
              .map((value) {
                if (value is! Map) {
                  throw const FormatException('Invalid BLE service.');
                }
                final chars = value['characteristics'];
                if (chars is! List ||
                    chars.length > 64 ||
                    (count += chars.length) > 256) {
                  throw const FormatException('Too many BLE characteristics.');
                }
                return {
                  'uuid': uuid(value['uuid']),
                  'characteristics': chars
                      .map((v) {
                        if (v is! Map) {
                          throw const FormatException(
                            'Invalid BLE characteristic.',
                          );
                        }
                        return characteristic(v);
                      })
                      .toList(growable: false),
                };
              })
              .toList(growable: false),
        };
      case 'bluetooth.read':
      case 'bluetooth.notification':
        return {
          'serviceUuid': uuid(raw['serviceUuid']),
          'characteristicUuid': uuid(raw['characteristicUuid']),
          'valueHex': hex(raw['valueHex'], limit: valueLimit),
        };
      case 'bluetooth.write':
        final bytes = raw['bytesWritten'];
        if (bytes is! int || bytes < 1 || bytes > maxWriteBytes) {
          throw const FormatException('Invalid BLE write result.');
        }
        return {'bytesWritten': bytes};
      case 'bluetooth.subscribe':
      case 'bluetooth.unsubscribe':
        return {'subscribed': flag(raw, 'subscribed')};
      case 'bluetooth.stopScan':
      case 'bluetooth.disconnect':
        return {'changed': flag(raw, 'changed')};
      default:
        throw const FormatException('Unknown BLE result.');
    }
  }
}
