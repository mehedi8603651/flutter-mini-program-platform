import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';

/// Host-accepted authority for foreground BLE. Empty [allowedServices] means
/// any service after explicit acceptance; writes require separate opt-in.
@immutable
class MiniProgramBluetoothPolicy {
  const MiniProgramBluetoothPolicy({
    this.enabled = false,
    this.allowWrite = false,
    this.allowNotifications = true,
    this.allowedServices = const [],
    this.maxScanMs = 10000,
    this.maxDevices = 20,
    this.maxValueBytes = 512,
  });
  final bool enabled;
  final bool allowWrite;
  final bool allowNotifications;
  final List<String> allowedServices;
  final int maxScanMs;
  final int maxDevices;
  final int maxValueBytes;

  void validate() {
    MiniProgramBluetooth.uuids(allowedServices);
    if (maxScanMs < 500 ||
        maxScanMs > MiniProgramBluetooth.maxScanMs ||
        maxDevices < 1 ||
        maxDevices > MiniProgramBluetooth.maxDevices ||
        maxValueBytes < 1 ||
        maxValueBytes > MiniProgramBluetooth.maxValueBytes) {
      throw const FormatException('Invalid accepted BLE limits.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MiniProgramBluetoothPolicy &&
      enabled == other.enabled &&
      allowWrite == other.allowWrite &&
      allowNotifications == other.allowNotifications &&
      listEquals(allowedServices, other.allowedServices) &&
      maxScanMs == other.maxScanMs &&
      maxDevices == other.maxDevices &&
      maxValueBytes == other.maxValueBytes;
  @override
  int get hashCode => Object.hash(
    enabled,
    allowWrite,
    allowNotifications,
    Object.hashAll(allowedServices),
    maxScanMs,
    maxDevices,
    maxValueBytes,
  );
}

abstract interface class MiniProgramBluetoothPolicyProvider {
  MiniProgramBluetoothPolicy bluetoothPolicyFor(String miniProgramId);
}

/// A trusted host's bounded native event, scoped to one opaque session.
@immutable
class MiniProgramBluetoothEvent {
  const MiniProgramBluetoothEvent({
    required this.miniProgramId,
    required this.sessionId,
    required this.type,
    this.data = const {},
  });
  final String miniProgramId;
  final String sessionId;
  final String type;
  final Map<String, dynamic> data;
}

/// Optional native BLE central adapter. Operations use canonical bluetooth.*
/// action names and validated arguments. release must be idempotent and cancel
/// permission waits, scans, pending GATT operations, notifications and connections
/// for the exact session only. Implementations must isolate engines/tasks.
abstract interface class MiniProgramBluetoothProvider {
  Stream<MiniProgramBluetoothEvent> get events;
  Future<Map<String, dynamic>> invoke({
    required String miniProgramId,
    required String sessionId,
    required String action,
    required Map<String, dynamic> arguments,
  });
  Future<void> release({
    required String miniProgramId,
    required String sessionId,
  });
}

class MiniProgramBluetoothException implements Exception {
  const MiniProgramBluetoothException({
    required this.errorCode,
    required this.message,
  });
  final String errorCode;
  final String message;
  @override
  String toString() => message;
}

typedef MiniProgramBluetoothValueHandler =
    bool Function(Map<String, dynamic> value);

/// Owns device handles, notifications, and stale completion for one mounted
/// mini-program. Native adapters independently enforce process-wide ownership.
class MiniProgramBluetoothManager {
  MiniProgramBluetoothManager(this.provider) {
    _events = provider.events.listen(
      _onEvent,
      onError: (Object _) {
        final session = _session;
        if (session != null) unawaited(releaseFor(session.appId));
      },
    );
  }
  final MiniProgramBluetoothProvider provider;
  late final StreamSubscription<MiniProgramBluetoothEvent> _events;
  _BluetoothSession? _session;
  bool _disposed = false;
  int _sessionGeneration = 0;
  static int _sequence = 0;

  /// Changes when a new session starts. Trusted consumers use this to prevent
  /// an older operation from updating state or releasing a replacement owner.
  int get sessionGeneration => _sessionGeneration;

  Future<Map<String, dynamic>> run({
    required String miniProgramId,
    required String action,
    required Map<String, dynamic> arguments,
    required MiniProgramBluetoothPolicy policy,
    MiniProgramBluetoothValueHandler? onValue,
    MiniProgramBluetoothValueHandler? onConnection,
  }) async {
    if (_disposed) _fail('request_cancelled', 'The BLE runtime has closed.');
    final args = MiniProgramBluetooth.arguments(action, arguments);
    final cleanup =
        action == 'bluetooth.disconnect' ||
        action == 'bluetooth.stopScan' ||
        action == 'bluetooth.unsubscribe';
    if (!cleanup) policy.validate();
    if (!cleanup && !policy.enabled) {
      _fail('not_accepted', 'Bluetooth is not accepted by host policy.');
    }
    if (action == 'bluetooth.write' && !policy.allowWrite) {
      _fail('not_accepted', 'BLE writes are not accepted by host policy.');
    }
    if (action == 'bluetooth.subscribe' && !policy.allowNotifications) {
      _fail(
        'not_accepted',
        'BLE notifications are not accepted by host policy.',
      );
    }
    final allowed = cleanup
        ? <String>[]
        : MiniProgramBluetooth.uuids(policy.allowedServices);
    final valueLimit = cleanup
        ? MiniProgramBluetooth.maxValueBytes
        : policy.maxValueBytes;
    if (args['serviceUuid'] != null &&
        allowed.isNotEmpty &&
        !allowed.contains(args['serviceUuid'])) {
      _fail('not_accepted', 'This BLE service is not accepted by host policy.');
    }
    if (action == 'bluetooth.scan') {
      final filters = List<String>.from(args['serviceUuids'] as List);
      if (allowed.isNotEmpty && filters.any((id) => !allowed.contains(id))) {
        _fail('not_accepted', 'The BLE scan requests an unaccepted service.');
      }
      args['serviceUuids'] = filters.isEmpty ? allowed : filters;
      args['timeoutMs'] = (args['timeoutMs'] as int).clamp(
        500,
        policy.maxScanMs,
      );
      args['maxDevices'] = (args['maxDevices'] as int).clamp(
        1,
        policy.maxDevices,
      );
    }
    if (action == 'bluetooth.write') {
      MiniProgramBluetooth.hex(
        args['valueHex'],
        limit: policy.maxValueBytes < 20 ? policy.maxValueBytes : 20,
        empty: false,
      );
    }
    var session = _session;
    if (session != null && session.appId != miniProgramId) {
      _fail('in_use', 'Another mini-program owns this BLE session.');
    }
    if (action == 'bluetooth.disconnect') {
      await releaseFor(miniProgramId);
      return {'changed': session != null};
    }
    if (cleanup && session == null) {
      return {
        action == 'bluetooth.unsubscribe' ? 'subscribed' : 'changed': false,
      };
    }
    if (session == null) {
      session = _BluetoothSession(
        miniProgramId,
        'ble_session_${DateTime.now().microsecondsSinceEpoch}_${++_sequence}',
      );
      _sessionGeneration++;
    }
    _session = session;
    if (session.busy && !cleanup) {
      _fail('request_in_progress', 'A BLE operation is already pending.');
    }
    if (!cleanup) session.busy = true;
    final owner = session;
    if (action == 'bluetooth.connect' &&
        !owner.devices.contains(args['deviceId'])) {
      owner.busy = false;
      _fail(
        'device_not_found',
        'Use a device handle from the current BLE scan.',
      );
    }
    final key = '${args['serviceUuid']}/${args['characteristicUuid']}';
    if (action == 'bluetooth.subscribe' &&
        !owner.listeners.containsKey(key) &&
        owner.listeners.length >= MiniProgramBluetooth.maxSubscriptions) {
      owner.busy = false;
      _fail('limit_exceeded', 'Too many BLE notification subscriptions.');
    }
    try {
      final raw = await provider.invoke(
        miniProgramId: miniProgramId,
        sessionId: owner.id,
        action: action,
        arguments: {
          ...args,
          'maxValueBytes': valueLimit,
          'allowedServices': allowed,
        },
      );
      if (_disposed || !identical(_session, owner)) {
        await _release(owner);
        _fail('request_cancelled', 'The BLE session ended before completion.');
      }
      final data = MiniProgramBluetooth.result(
        action,
        raw,
        deviceLimit: action == 'bluetooth.scan'
            ? args['maxDevices'] as int
            : policy.maxDevices,
        valueLimit: valueLimit,
      );
      switch (action) {
        case 'bluetooth.scan':
          owner.devices.clear();
          owner.devices.addAll(
            (data['devices'] as List).map(
              (v) => (v as Map)['deviceId'] as String,
            ),
          );
        case 'bluetooth.connect':
          if (!owner.devices.contains(data['deviceId']) ||
              data['deviceId'] != args['deviceId'] ||
              data['connected'] != true) {
            throw const FormatException('Unexpected BLE connection.');
          }
          owner.connectionListener = onConnection;
          owner.connectedDevice = data['deviceId'] as String;
        case 'bluetooth.discoverServices':
          if (allowed.isNotEmpty) {
            data['services'] = (data['services'] as List)
                .where((s) => allowed.contains((s as Map)['uuid']))
                .toList();
          }
        case 'bluetooth.read':
          if (data['serviceUuid'] != args['serviceUuid'] ||
              data['characteristicUuid'] != args['characteristicUuid']) {
            throw const FormatException('Unexpected BLE characteristic.');
          }
        case 'bluetooth.subscribe':
          if (data['subscribed'] != true || onValue == null) {
            throw const FormatException('Missing BLE notification receiver.');
          }
          owner.listeners[key] = (policy.maxValueBytes, onValue);
        case 'bluetooth.unsubscribe':
          if (data['subscribed'] != false) {
            throw const FormatException('Unexpected BLE subscription.');
          }
          owner.listeners.remove(key);
        case 'bluetooth.write':
          if (data['bytesWritten'] !=
              (args['valueHex'] as String).length ~/ 2) {
            throw const FormatException('Unexpected BLE write length.');
          }
      }
      return data;
    } on FormatException {
      await releaseFor(miniProgramId);
      _fail('invalid_result', 'The BLE provider returned invalid data.');
    } finally {
      if (!cleanup) owner.busy = false;
    }
  }

  void _onEvent(MiniProgramBluetoothEvent event) {
    final owner = _session;
    if (_disposed ||
        owner == null ||
        owner.id != event.sessionId ||
        owner.appId != event.miniProgramId) {
      return;
    }
    try {
      if (event.type == 'disconnected') {
        final listener = owner.connectionListener;
        owner.connectionListener = null;
        owner.listeners.clear();
        if (listener != null) {
          final data = MiniProgramBluetooth.result(
            'bluetooth.connect',
            event.data,
          );
          if (data['connected'] != false ||
              data['deviceId'] != owner.connectedDevice) {
            throw const FormatException('Invalid disconnect event.');
          }
          owner.connectedDevice = null;
          if (!listener(data)) unawaited(releaseFor(owner.appId));
        }
      } else if (event.type == 'notification') {
        final key =
            '${event.data['serviceUuid']}/${event.data['characteristicUuid']}';
        final receiver = owner.listeners[key];
        if (receiver == null) return;
        final data = MiniProgramBluetooth.result(
          'bluetooth.notification',
          event.data,
          valueLimit: receiver.$1,
        );
        if (!receiver.$2(data)) unawaited(releaseFor(owner.appId));
      }
    } on Object {
      unawaited(releaseFor(owner.appId));
    }
  }

  Future<void> releaseFor(String appId, {int? sessionGeneration}) async {
    if (sessionGeneration != null && sessionGeneration != _sessionGeneration) {
      return;
    }
    final owner = _session;
    if (owner == null || owner.appId != appId) return;
    _session = null;
    owner.listeners.clear();
    final listener = owner.connectionListener;
    owner.connectionListener = null;
    if (listener != null) {
      try {
        listener({'deviceId': owner.connectedDevice, 'connected': false});
      } on Object {
        /* State may already be disposed. */
      }
    }
    await _release(owner);
  }

  Future<void> _release(_BluetoothSession owner) async {
    try {
      await provider.release(miniProgramId: owner.appId, sessionId: owner.id);
    } on Object {
      /* Native lifecycle also releases ownership. */
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final owner = _session;
    if (owner != null) await releaseFor(owner.appId);
    await _events.cancel();
  }

  Never _fail(String suffix, String message) =>
      throw MiniProgramBluetoothException(
        errorCode: 'bluetooth_$suffix',
        message: message,
      );
}

class _BluetoothSession {
  _BluetoothSession(this.appId, this.id);
  final String appId;
  final String id;
  bool busy = false;
  final devices = <String>{};
  final listeners = <String, (int, MiniProgramBluetoothValueHandler)>{};
  MiniProgramBluetoothValueHandler? connectionListener;
  String? connectedDevice;
}
