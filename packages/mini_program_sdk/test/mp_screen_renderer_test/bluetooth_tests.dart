part of '../mp_screen_renderer_test.dart';

void _mpBluetoothTests() {
  testWidgets(
    'BLE actions require accepted policy, a visible route, and a user gesture',
    (tester) async {
      final provider = _RendererBleProvider();
      final manager = MiniProgramBluetoothManager(provider);
      final state = MpStateManager()..set('ble.result', {'keep': true});
      addTearDown(manager.dispose);
      addTearDown(state.dispose);
      final action = Mp.bluetooth.scan(
        targetState: 'ble.result',
        statusState: 'ble.status',
        errorState: 'ble.error',
      );
      for (final config in [
        (
          false,
          true,
          const MiniProgramBluetoothPolicy(enabled: true),
          'bluetooth_user_gesture_required',
        ),
        (
          true,
          false,
          const MiniProgramBluetoothPolicy(enabled: true),
          'bluetooth_foreground_required',
        ),
        (
          true,
          true,
          const MiniProgramBluetoothPolicy(),
          'bluetooth_not_accepted',
        ),
      ]) {
        final result =
            await _runMpAction(
                  tester,
                  action.toJson(),
                  stateManager: state,
                  bluetoothManager: manager,
                  bluetoothPolicy: config.$3,
                  userGesture: config.$1,
                  isForeground: config.$2,
                )
                as HostActionResult;
        expect(result.errorCode, config.$4);
        expect(state.get('ble.result'), {'keep': true});
      }
      expect(provider.calls, 0);
      final missing =
          await _runMpAction(
                tester,
                action.toJson(),
                stateManager: state,
                bluetoothPolicy: const MiniProgramBluetoothPolicy(
                  enabled: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      expect(missing.errorCode, 'bluetooth_unavailable');
    },
  );
  testWidgets(
    'BLE normalizes results and rejects resolved invalid data before native access',
    (tester) async {
      final provider = _RendererBleProvider();
      final manager = MiniProgramBluetoothManager(provider);
      final state = MpStateManager();
      addTearDown(manager.dispose);
      addTearDown(state.dispose);
      await _runMpAction(
        tester,
        Mp.bluetooth
            .scan(targetState: 'ble.result', statusState: 'ble.status')
            .toJson(),
        stateManager: state,
        bluetoothManager: manager,
        bluetoothPolicy: const MiniProgramBluetoothPolicy(enabled: true),
        userGesture: true,
      );
      expect(state.get('ble.result.devices'), isEmpty);
      expect(state.get('ble.status'), 'success');
      state.set('ble.result', {'keep': true});
      state.set('device', 'AA:BB:CC:DD:EE:FF');
      await _runMpAction(
        tester,
        Mp.action.sequence([
          Mp.bluetooth.connect(
            deviceId: '{{state.device}}',
            targetState: 'ble.result',
            errorState: 'ble.error',
          ),
          Mp.state.set('after', true),
        ]).toJson(),
        stateManager: state,
        bluetoothManager: manager,
        bluetoothPolicy: const MiniProgramBluetoothPolicy(enabled: true),
        userGesture: true,
      );
      expect(state.get('ble.error.code'), 'bluetooth_invalid_request');
      expect(state.get('ble.result'), {'keep': true});
      expect(state.contains('after'), isFalse);
      expect(provider.calls, 1);
    },
  );
  test(
    'BLE JSON rejects unknown properties, missing outputs, and overlapping state paths',
    () {
      final validator = const MpScreenValidator();
      for (final props in [
        {'targetState': 'ble.result', 'nativeAddress': 'AA:BB:CC:DD:EE:FF'},
        {'timeoutMs': 500},
        {'targetState': 'ble', 'statusState': 'ble.status'},
        {'targetState': 'ble.result', 'maxDevices': 65},
      ]) {
        final document = MpProgram(
          screens: {
            'home': () => Mp.button(
              label: 'Scan',
              action: MpAction('bluetooth.scan', props: props),
            ),
          },
        ).buildScreensJson()['home'];
        expect(
          () =>
              validator.validate(_jsonMap(document!), expectedScreenId: 'home'),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
    },
  );
  testWidgets('BLE permission denial keeps existing result data', (
    tester,
  ) async {
    final provider = _RendererBleProvider()..denied = true;
    final manager = MiniProgramBluetoothManager(provider);
    final state = MpStateManager()..set('ble.result', {'keep': true});
    addTearDown(manager.dispose);
    addTearDown(state.dispose);
    final result =
        await _runMpAction(
              tester,
              Mp.bluetooth
                  .scan(
                    targetState: 'ble.result',
                    statusState: 'ble.status',
                    errorState: 'ble.error',
                  )
                  .toJson(),
              stateManager: state,
              bluetoothManager: manager,
              bluetoothPolicy: const MiniProgramBluetoothPolicy(enabled: true),
              userGesture: true,
            )
            as HostActionResult;
    expect(result.errorCode, 'bluetooth_permission_denied');
    expect(state.get('ble.result'), {'keep': true});
    expect(state.get('ble.status'), 'error');
    expect(state.get('ble.error.code'), 'bluetooth_permission_denied');
  });
  testWidgets(
    'BLE ignores notifications during permission inactivity and resumes afterward',
    (tester) async {
      final provider = _RendererBleProvider();
      final manager = MiniProgramBluetoothManager(provider);
      final state = MpStateManager()..set('ble.value', {'keep': true});
      addTearDown(manager.dispose);
      addTearDown(state.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _runMpAction(
        tester,
        Mp.bluetooth
            .subscribe(
              serviceUuid: '180d',
              characteristicUuid: '2a37',
              targetState: 'ble.value',
            )
            .toJson(),
        stateManager: state,
        bluetoothManager: manager,
        bluetoothPolicy: const MiniProgramBluetoothPolicy(enabled: true),
        userGesture: true,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      provider.notify('01');
      expect(state.get('ble.value'), {'keep': true});
      expect(provider.releases, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      provider.notify('02');
      expect(state.get<Map>('ble.value')!['valueHex'], '02');
      await tester.pumpWidget(const SizedBox.shrink());
      provider.notify('03');
      await tester.pump();
      expect(provider.releases, 1);
      expect(state.get<Map>('ble.value')!['valueHex'], '02');
    },
  );
  testWidgets(
    'BLE notification state quota failure rolls back and releases the session',
    (tester) async {
      final provider = _RendererBleProvider();
      final manager = MiniProgramBluetoothManager(provider);
      final state = MpStateManager(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 1024,
          maxValueBytes: 128,
        ),
      )..set('ble.value', {'keep': true});
      addTearDown(manager.dispose);
      addTearDown(state.dispose);
      await _runMpAction(
        tester,
        Mp.bluetooth
            .subscribe(
              serviceUuid: '180d',
              characteristicUuid: '2a37',
              targetState: 'ble.value',
            )
            .toJson(),
        stateManager: state,
        bluetoothManager: manager,
        bluetoothPolicy: const MiniProgramBluetoothPolicy(enabled: true),
        userGesture: true,
      );
      provider.notify('01' * 80);
      await tester.pump();
      expect(provider.releases, 1);
      expect(state.get('ble.value'), {'keep': true});
      provider.notify('01');
      expect(state.get('ble.value'), {'keep': true});
    },
  );
}

class _RendererBleProvider implements MiniProgramBluetoothProvider {
  int calls = 0;
  int releases = 0;
  bool denied = false;
  String appId = '';
  String session = '';
  final controller = StreamController<MiniProgramBluetoothEvent>.broadcast(
    sync: true,
  );
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
    appId = miniProgramId;
    session = sessionId;
    if (denied) {
      throw const MiniProgramBluetoothException(
        errorCode: 'bluetooth_permission_denied',
        message: 'Nearby Devices permission was denied.',
      );
    }
    return action == 'bluetooth.subscribe'
        ? {'subscribed': true}
        : {'devices': []};
  }

  void notify(String value) => controller.add(
    MiniProgramBluetoothEvent(
      miniProgramId: appId,
      sessionId: session,
      type: 'notification',
      data: {
        'serviceUuid': '0000180d-0000-1000-8000-00805f9b34fb',
        'characteristicUuid': '00002a37-0000-1000-8000-00805f9b34fb',
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
  }
}
