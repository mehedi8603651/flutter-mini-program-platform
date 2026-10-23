part of '../mp_screen_renderer_test.dart';

void _mpNfcTests() {
  testWidgets('NFC preflight quota failure cannot cancel an existing request', (
    tester,
  ) async {
    final nativeResult = Completer<Map<String, dynamic>>();
    final provider = _RendererNfcProvider()..pending = nativeResult;
    final manager = MiniProgramNfcManager(provider);
    final state = MpStateManager(
      policy: const MiniProgramLiveStatePolicy(maxBytes: 8, maxValueBytes: 8),
    );
    addTearDown(manager.dispose);
    addTearDown(state.dispose);
    final first = manager.run(
      miniProgramId: 'coupon',
      action: 'nfc.read',
      arguments: {},
      policy: const MiniProgramNfcPolicy(enabled: true),
    );
    final rejected =
        await _runMpAction(
              tester,
              Mp.nfc.read(targetState: 'tag', statusState: 'status').toJson(),
              stateManager: state,
              nfcManager: manager,
              nfcPolicy: const MiniProgramNfcPolicy(enabled: true),
              userGesture: true,
            )
            as HostActionResult;
    expect(rejected.errorCode, MiniProgramErrorCodes.stateLimitExceeded);
    expect(provider.calls, 1);
    expect(provider.releases, 0);
    nativeResult.complete({
      'records': [
        {'type': 'text', 'text': 'ok', 'language': ''},
      ],
    });
    expect(await first, isNotEmpty);
  });
  testWidgets(
    'NFC reading requires an accepted policy, foreground route and user gesture',
    (tester) async {
      final provider = _RendererNfcProvider();
      final manager = MiniProgramNfcManager(provider);
      final state = MpStateManager()..set('nfc.result', {'keep': true});
      addTearDown(manager.dispose);
      addTearDown(state.dispose);
      final action = Mp.nfc.read(
        targetState: 'nfc.result',
        errorState: 'nfc.error',
      );
      for (final config in [
        (
          false,
          true,
          const MiniProgramNfcPolicy(enabled: true),
          'nfc_user_gesture_required',
        ),
        (
          true,
          false,
          const MiniProgramNfcPolicy(enabled: true),
          'nfc_foreground_required',
        ),
        (true, true, const MiniProgramNfcPolicy(), 'nfc_not_accepted'),
      ]) {
        final result =
            await _runMpAction(
                  tester,
                  action.toJson(),
                  stateManager: state,
                  nfcManager: manager,
                  nfcPolicy: config.$3,
                  userGesture: config.$1,
                  isForeground: config.$2,
                )
                as HostActionResult;
        expect(result.errorCode, config.$4);
        expect(state.get('nfc.result'), {'keep': true});
      }
      expect(provider.calls, 0);
      final missing =
          await _runMpAction(
                tester,
                action.toJson(),
                stateManager: state,
                nfcPolicy: const MiniProgramNfcPolicy(enabled: true),
                userGesture: true,
              )
              as HostActionResult;
      expect(missing.errorCode, 'nfc_unavailable');
    },
  );
  testWidgets(
    'NFC writes sanitized records atomically and checks availability without a gesture',
    (tester) async {
      final provider = _RendererNfcProvider();
      final manager = MiniProgramNfcManager(provider);
      final state = MpStateManager()..set('nfc.error', {'old': true});
      addTearDown(manager.dispose);
      addTearDown(state.dispose);
      final result =
          await _runMpAction(
                tester,
                Mp.nfc
                    .read(
                      targetState: 'nfc.result',
                      statusState: 'nfc.status',
                      errorState: 'nfc.error',
                    )
                    .toJson(),
                stateManager: state,
                nfcManager: manager,
                nfcPolicy: const MiniProgramNfcPolicy(enabled: true),
                userGesture: true,
              )
              as HostActionResult;
      expect(result.isSuccess, true);
      expect(state.get('nfc.result'), {
        'records': [
          {'type': 'text', 'text': 'product-42', 'language': 'en'},
        ],
      });
      expect(state.get('nfc.status'), 'success');
      expect(state.get('nfc.error'), isNull);
      await _runMpAction(
        tester,
        Mp.nfc.getState(targetState: 'availability').toJson(),
        stateManager: state,
        nfcManager: manager,
        nfcPolicy: const MiniProgramNfcPolicy(enabled: true),
      );
      expect(state.get('availability'), {'supported': false, 'enabled': false});
    },
  );
  testWidgets(
    'NFC failures and state quota rejection preserve previous result data',
    (tester) async {
      final provider = _RendererNfcProvider();
      final manager = MiniProgramNfcManager(provider);
      final state = MpStateManager(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 2048,
          maxValueBytes: 256,
        ),
      )..set('nfc.result', {'keep': true});
      addTearDown(manager.dispose);
      addTearDown(state.dispose);
      for (final config in [
        ('nfc_tag_lost', null, 'nfc_tag_lost'),
        (
          null,
          {
            'records': [
              {'type': 'uri', 'uri': 'javascript:alert(1)'},
            ],
          },
          'nfc_invalid_result',
        ),
        (
          null,
          {
            'records': [
              {'type': 'text', 'text': 'a' * 400, 'language': 'en'},
            ],
          },
          MiniProgramErrorCodes.stateLimitExceeded,
        ),
      ]) {
        provider.errorCode = config.$1;
        provider.data = config.$2;
        final result =
            await _runMpAction(
                  tester,
                  Mp.nfc
                      .read(targetState: 'nfc.result', errorState: 'nfc.error')
                      .toJson(),
                  stateManager: state,
                  nfcManager: manager,
                  nfcPolicy: const MiniProgramNfcPolicy(enabled: true),
                  userGesture: true,
                )
                as HostActionResult;
        expect(result.errorCode, config.$3);
        expect(state.get('nfc.result'), {'keep': true});
      }
      expect(provider.releases, 3);
    },
  );
  test('NFC validates complete action schemas before rendering', () {
    for (final props in [
      {'targetState': 'data', 'tagId': 'native'},
      {'timeoutMs': 1000},
      {'targetState': 'data', 'statusState': 'data.status'},
      {'targetState': '{{state.path}}'},
      {'targetState': 'data', 'timeoutMs': '{{state.timeout}}'},
      {'targetState': 'data', 'timeoutMs': 30001},
    ]) {
      final document = MpProgram(
        screens: {
          'home': () => Mp.button(
            label: 'Read',
            action: MpAction('nfc.read', props: props),
          ),
        },
      ).buildScreensJson()['home'];
      expect(
        () => const MpScreenValidator().validate(
          _jsonMap(document!),
          expectedScreenId: 'home',
        ),
        throwsA(isA<MiniProgramRenderException>()),
      );
    }
  });
}

class _RendererNfcProvider implements MiniProgramNfcProvider {
  int calls = 0;
  int releases = 0;
  String? errorCode;
  Map<String, dynamic>? data;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> invoke({
    required String miniProgramId,
    required String sessionId,
    required String action,
    required Map<String, dynamic> arguments,
  }) async {
    calls++;
    if (errorCode != null) {
      throw MiniProgramNfcException(
        errorCode: errorCode!,
        message: 'NFC failed.',
      );
    }
    if (pending != null) return pending!.future;
    return action == 'nfc.getState'
        ? {'supported': false, 'enabled': false}
        : data ??
              {
                'nativeId': 'never exported',
                'records': [
                  {'type': 'text', 'text': 'product-42', 'language': 'en'},
                ],
              };
  }

  @override
  Future<void> release({
    required String miniProgramId,
    required String sessionId,
  }) async {
    releases++;
  }
}
