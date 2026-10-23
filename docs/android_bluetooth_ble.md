# Android Bluetooth Low Energy

The optional Bluetooth capability implements foreground BLE central operations
using Android's built-in `BluetoothLeScanner` and `BluetoothGatt` APIs. It adds
no Bluetooth Flutter plugin, Android library, background service, or advertising
permission. Mini-program authoring remains pure Dart.

This is an unreleased feature. Use the repository tooling and local package
dependencies when testing it; the previously published CLI does not install it.

## Host setup

After the normal `miniprogram embed init --project-root .`, install the adapter:

```powershell
miniprogram host capability init bluetooth --platform android --project-root .
```

For this unreleased checkout, invoke the local CLI rather than the globally
installed published version:

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_tooling
dart run bin/miniprogram.dart host capability init bluetooth --platform android --project-root "D:\your_host_app"
```

The installer generates a host-owned `app_android_bluetooth_provider.dart`, the
managed native `MiniProgramBluetoothChannel.kt`, Activity/engine registration,
and Android manifest permissions. Repeating installation is safe and preserves
host Dart customizations. The native registration works with embedded hosts and
`--android-separate-tasks`; an `embed init --force` refresh keeps the installed
provider. Installation does not accept any mini-program permission.

Review the imported app's `accepted.permissions.bluetooth` in
`lib/mini_program/mini_program_policies.json`:

```json
{
  "enabled": true,
  "allowWrite": false,
  "allowNotifications": true,
  "allowedServices": ["0000180d-0000-1000-8000-00805f9b34fb"],
  "maxScanMs": 10000,
  "maxDevices": 20,
  "maxValueBytes": 512
}
```

Empty `allowedServices` permits any service after explicit host acceptance.
Otherwise scans and GATT access are restricted to accepted service UUIDs. Service
filters match advertising data: devices that do not advertise the requested
service may not appear. Writes need independent host acceptance. Publisher
requests and recommendations never grant runtime authority.

A publisher can request access in its handoff configuration using
`requestedPermissions.bluetooth`, for example:

```json
{
  "enabled": true,
  "reason": "Read the shop sensor while this mini-program is open.",
  "write": false,
  "notifications": true,
  "serviceUuids": ["180d"],
  "recommendedMaxScanMs": 5000,
  "recommendedMaxDevices": 10,
  "recommendedMaxValueBytes": 512
}
```

Regenerate policy resolution through the normal host endpoint import workflow
after reviewing accepted policy. A manually composed host may instead provide
`MiniProgramBluetoothProvider` through `MiniProgramConfig.bluetoothProvider` and
`MiniProgramBluetoothPolicy` through its endpoint/source. Register
`CapabilityIds.bluetoothBle` only when a provider is installed.

## Pure-Dart mini-program actions

Use `package:mini_program_ui/mini_program_ui.dart`:

```dart
Mp.bluetooth.getState(targetState: 'ble.availability');

Mp.bluetooth.scan(
  serviceUuids: ['180d'],
  timeoutMs: 5000,
  maxDevices: 10,
  targetState: 'ble.scan',
  statusState: 'ble.scan_status',
  errorState: 'ble.scan_error',
);

// Pick a returned device in your UI; retain its opaque deviceId in state.
Mp.bluetooth.connect(
  deviceId: '{{state.selected_device.deviceId}}',
  targetState: 'ble.connection',
);

Mp.bluetooth.discoverServices(targetState: 'ble.services');

Mp.bluetooth.read(
  serviceUuid: '180d',
  characteristicUuid: '2a37',
  targetState: 'ble.value',
);

Mp.bluetooth.subscribe(
  serviceUuid: '180d',
  characteristicUuid: '2a37',
  targetState: 'ble.latest_value',
);

Mp.bluetooth.write(
  serviceUuid: '{{state.selected_service}}',
  characteristicUuid: '{{state.selected_characteristic}}',
  valueHex: '0102',
);

Mp.bluetooth.unsubscribe(serviceUuid: '180d', characteristicUuid: '2a37');
Mp.bluetooth.stopScan();
Mp.bluetooth.disconnect();
```

Run scan, connect, discovery, read, write, and subscribe from existing explicit
user actions such as button taps. `getState` does not prompt for permission;
cleanup actions may run without another gesture. Call discovery after connecting
before accessing characteristics. Use the remote device's documented protocol
and characteristic properties; the UUIDs above illustrate the API and do not
imply that every heart-rate characteristic supports reading or writing.
On Android 12+, `getState.enabled` is reported as false until Nearby Devices
permission is granted; check `permissionGranted` before interpreting it as a
known radio-off state.

`scan` completes after its bounded timeout or `stopScan` and writes
`{"devices":[{"deviceId":"ble_...","name":"Sensor","rssi":-45,"serviceUuids":[]}]}`.
Device IDs are opaque, app/session-owned handles from the current scan, not MAC
addresses. A new scan replaces available handles; hiding or disconnecting ends
the session. Do not persist handles for a later session.

`connect` writes `{"deviceId":"ble_...","connected":true}`; its result state is
updated to disconnected when the current mounted receiver can still accept it.
`discoverServices` writes bounded service/characteristic UUIDs and supported
read/write/notification properties. Read and notification results contain
`serviceUuid`, `characteristicUuid`, and an even-length lowercase `valueHex`.
Unknown native fields are never forwarded into mini-program state.

Notifications replace the latest value in `targetState`, with at most eight
subscriptions and at most ten deliveries per second per characteristic. The
adapter drops excess updates rather than buffering a history. State quota
rejection or a stale/disposed notification receiver releases the BLE session.
An empty, missing, or unauthorized native result does not replace prior data.

## Limits and lifecycle

- One foreground connection per mini-program, with process-wide native ownership
  across separate Android tasks/Flutter engines. Another active owner receives
  `bluetooth_in_use`; it cannot disconnect the other owner's session.
- Scans last 500–15000 ms and return at most 64 devices, further limited by host
  policy. Android may throttle frequently repeated scans.
- GATT operations are serialized by rejecting overlapping operations with
  `bluetooth_request_in_progress`; they have bounded timeouts.
- Reads/notifications contain at most 512 bytes, further limited by host policy.
  Writes contain 1–20 bytes per operation, fitting the default ATT MTU. No automatic
  message fragmentation, MTU negotiation, or claim of peripheral-level delivery
  for a write without response is provided.
- Hidden/background mini-programs stop scanning, unsubscribe, cancel pending
  operations, and disconnect. The Flutter screen and entered data remain mounted.
  Returning requires reconnecting with a fresh scan handle. Background BLE,
  Classic Bluetooth, peripheral/server mode, pairing UI, and auto-reconnect are
  outside this initial capability.
- Permission-dialog inactivity does not cancel a pending request. Actual
  backgrounding, Activity/engine detachment, configuration changes, app changes,
  and disposal release resources. Late callbacks cannot mutate a new session.

Android 12+ uses runtime Nearby Devices permissions (`BLUETOOTH_SCAN` and
`BLUETOOTH_CONNECT`). Android 6–11 requires foreground fine-location permission
and enabled location services for scanning; no coordinates are requested or
returned. The generated legacy declarations are limited to Android 11.
`neverForLocation` on modern scanning can cause Android to filter some BLE
beacons. Phones without BLE can still install the host and receive a structured
unavailable result. Android system permission dialogs still require user consent.

Errors include `bluetooth_not_accepted`, `bluetooth_permission_denied`,
`bluetooth_disabled`, `bluetooth_device_not_found`, `bluetooth_not_connected`,
`bluetooth_characteristic_unsupported`, `bluetooth_timeout`,
`bluetooth_request_cancelled`, and `bluetooth_limit_exceeded`. Action
`statusState` values are `loading`, `success`, `disconnected`, `cancelled`, or
`error`. Result/status/error paths must not overlap.

## Validation

Automated coverage checks contract normalization, pure-Dart serialization,
malformed/bound action values, default-denied and accepted policy, optional
installation/reinstallation, ownership, stale completion, and notification limits.
Lifecycle tests cover permission-dialog inactivity, hiding, backgrounding,
disposal, preserved UI state, and an old scan completing after a replacement
session. Generated-host adapter tests cover session identity, missing installation,
and sanitized platform errors. The generated Kotlin BLE adapter was compiled
with Kotlin 2.2.20 against Android API 36 and Flutter embedding; a fresh host was
generated with both standard and separate-task setup and analyzed successfully.

No Android device or BLE accessory was connected for this validation. Radio and
system permission UI behavior remain unverified on hardware; no emulator result
is claimed.

A real BLE peripheral is required to validate radio discovery, Android permission
UI, GATT read/write behavior, CCCD notifications, unexpected disconnects, and
switching between separate tasks. An emulator's unavailable/empty scan behavior
cannot prove interoperability with physical devices.

Android references:
[permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions),
[BLE data transfer](https://developer.android.com/develop/connectivity/bluetooth/ble/transfer-ble-data),
and [GATT callbacks](https://developer.android.com/reference/android/bluetooth/BluetoothGattCallback).
