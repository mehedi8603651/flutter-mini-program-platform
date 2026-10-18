part of '../mp_screen_renderer_test.dart';

void _mpSystemTests() {
  testWidgets('accepted system actions fail cleanly without native providers', (
    tester,
  ) async {
    final state = MpStateManager();
    for (final action in [
      Mp.clipboard.writeText(text: 'note'),
      Mp.vibration.trigger(),
      Mp.phone.openDialer(number: '5550101234'),
    ]) {
      final result =
          await _runMpAction(
                tester,
                action.toJson(),
                stateManager: state,
                clipboardPolicy: const MiniProgramClipboardPolicy(
                  enabled: true,
                ),
                vibrationPolicy: const MiniProgramVibrationPolicy(
                  enabled: true,
                ),
                phonePolicy: const MiniProgramPhonePolicy(enabled: true),
                userGesture: true,
              )
              as HostActionResult;
      expect(
        result.errorCode,
        '${action.toJson()['type'].toString().split('.').first}_unavailable',
      );
    }
    state.dispose();
  });

  testWidgets(
    'system actions reject OS background and failure stops action sequences',
    (tester) async {
      final provider = _SystemProvider();
      final state = MpStateManager()..set('number', '*123#');
      await _runMpAction(
        tester,
        Mp.state.set('ready', true).toJson(),
        stateManager: state,
        clipboardProvider: provider,
        clipboardPolicy: const MiniProgramClipboardPolicy(enabled: true),
      );
      final actionContext = tester.element(find.byType(SizedBox).last);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final inactive =
          await const MpActionRunner().run(
                actionContext,
                Mp.clipboard.writeText(text: 'no background copy').toJson(),
                userGesture: true,
              )
              as HostActionResult;
      expect(
        inactive.errorCode,
        MiniProgramErrorCodes.clipboardForegroundRequired,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _runMpAction(
        tester,
        Mp.action.sequence([
          Mp.phone.openDialer(number: '{{state.number}}'),
          Mp.state.set('after', true),
        ]).toJson(),
        stateManager: state,
        phoneProvider: provider,
        phonePolicy: const MiniProgramPhonePolicy(enabled: true),
        userGesture: true,
      );
      expect(state.contains('after'), isFalse);
      expect(provider.calls, isEmpty);
      state.dispose();
    },
  );

  testWidgets(
    'system actions require gesture, foreground and accepted policy',
    (tester) async {
      final provider = _SystemProvider();
      for (final action in [
        Mp.clipboard.readText(targetState: 'result'),
        Mp.clipboard.writeText(text: 'note'),
        Mp.vibration.trigger(),
        Mp.phone.openDialer(number: '5550101234'),
      ]) {
        final feature = action.toJson()['type'].toString().split('.').first;
        final state = MpStateManager()..set('result', {'previous': true});
        for (final gesture in [false, true]) {
          final result =
              await _runMpAction(
                    tester,
                    action.toJson(),
                    stateManager: state,
                    clipboardProvider: provider,
                    vibrationProvider: provider,
                    phoneProvider: provider,
                    userGesture: gesture,
                  )
                  as HostActionResult;
          expect(
            result.errorCode,
            '${feature}_${gesture ? 'not_accepted' : 'user_gesture_required'}',
          );
        }
        final hidden =
            await _runMpAction(
                  tester,
                  action.toJson(),
                  stateManager: state,
                  clipboardProvider: provider,
                  clipboardPolicy: const MiniProgramClipboardPolicy(
                    enabled: true,
                    allowRead: true,
                  ),
                  vibrationProvider: provider,
                  vibrationPolicy: const MiniProgramVibrationPolicy(
                    enabled: true,
                  ),
                  phoneProvider: provider,
                  phonePolicy: const MiniProgramPhonePolicy(enabled: true),
                  isForeground: false,
                  userGesture: true,
                )
                as HostActionResult;
        expect(hidden.errorCode, '${feature}_foreground_required');
        expect(state.get('result'), {'previous': true});
        state.dispose();
      }
      expect(provider.calls, isEmpty);
    },
  );

  testWidgets(
    'clipboard requires independent read acceptance and preserves exact text',
    (tester) async {
      final state = MpStateManager();
      final provider = _SystemProvider()..text = '  booking\n';
      final read = Mp.clipboard.readText(
        targetState: 'result',
        statusState: 'status',
        errorState: 'error',
      );
      final denied =
          await _runMpAction(
                tester,
                read.toJson(),
                stateManager: state,
                clipboardProvider: provider,
                clipboardPolicy: const MiniProgramClipboardPolicy(
                  enabled: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      expect(denied.errorCode, MiniProgramErrorCodes.clipboardNotAccepted);
      final result =
          await _runMpAction(
                tester,
                read.toJson(),
                stateManager: state,
                clipboardProvider: provider,
                clipboardPolicy: const MiniProgramClipboardPolicy(
                  enabled: true,
                  allowRead: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      expect(result.data, {'hasText': true, 'text': '  booking\n'});
      expect(state.get('result'), result.data);
      expect(state.get('status'), 'success');
      expect(state.contains('error'), isFalse);
      provider.text = null;
      final empty =
          await _runMpAction(
                tester,
                read.toJson(),
                stateManager: state,
                clipboardProvider: provider,
                clipboardPolicy: const MiniProgramClipboardPolicy(
                  enabled: true,
                  allowRead: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      expect(empty.data, {'hasText': false, 'text': null});
      state.dispose();
    },
  );

  testWidgets(
    'resolved clipboard limits reject writes and invalid provider results atomically',
    (tester) async {
      final state = MpStateManager()
        ..set('value', '12345')
        ..set('result', {'kept': true});
      final provider = _SystemProvider()..text = '12345';
      for (final action in [
        Mp.clipboard.writeText(text: '{{state.value}}', targetState: 'result'),
        Mp.clipboard.readText(targetState: 'result'),
      ]) {
        final result =
            await _runMpAction(
                  tester,
                  action.toJson(),
                  stateManager: state,
                  clipboardProvider: provider,
                  clipboardPolicy: const MiniProgramClipboardPolicy(
                    enabled: true,
                    allowRead: true,
                    maxTextLength: 4,
                  ),
                  userGesture: true,
                )
                as HostActionResult;
        expect(result.errorCode, MiniProgramErrorCodes.clipboardInvalidRequest);
        expect(state.get('result'), {'kept': true});
      }
      expect(provider.calls, ['read']);
      state.set('value', ' a\n');
      final written =
          await _runMpAction(
                tester,
                Mp.clipboard.writeText(text: '{{state.value}}').toJson(),
                stateManager: state,
                clipboardProvider: provider,
                clipboardPolicy: const MiniProgramClipboardPolicy(
                  enabled: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      expect(written.data, {'written': true});
      expect(provider.text, ' a\n');
      expect(provider.sensitive, isTrue);
      state.dispose();
    },
  );

  testWidgets(
    'haptics report system refusal and dialer normalizes bound numbers',
    (tester) async {
      final state = MpStateManager()..set('phone', '+1 (555) 010-1234');
      final provider = _SystemProvider();
      final vibration =
          await _runMpAction(
                tester,
                Mp.vibration
                    .trigger(effect: MpVibrationEffect.success)
                    .toJson(),
                stateManager: state,
                vibrationProvider: provider,
                vibrationPolicy: const MiniProgramVibrationPolicy(
                  enabled: true,
                ),
                userGesture: true,
              )
              as HostActionResult;
      expect(vibration.data, {'performed': false, 'effect': 'success'});
      final dial = Mp.phone.openDialer(
        number: '{{state.phone}}',
        targetState: 'result',
      );
      final opened =
          await _runMpAction(
                tester,
                dial.toJson(),
                stateManager: state,
                phoneProvider: provider,
                phonePolicy: const MiniProgramPhonePolicy(enabled: true),
                userGesture: true,
              )
              as HostActionResult;
      expect(opened.data, {'dialerOpened': true});
      expect(provider.calls.last, 'dial:+15550101234');
      for (final value in <Object?>[
        'tel:123',
        '*123#',
        '123;4',
        '1' * 33,
        123,
        null,
      ]) {
        state.set('phone', value);
        final invalid =
            await _runMpAction(
                  tester,
                  dial.toJson(),
                  stateManager: state,
                  phoneProvider: provider,
                  phonePolicy: const MiniProgramPhonePolicy(enabled: true),
                  userGesture: true,
                )
                as HostActionResult;
        expect(invalid.errorCode, MiniProgramErrorCodes.phoneInvalidRequest);
        expect(state.get('result'), {'dialerOpened': true});
      }
      expect(provider.calls.where((c) => c.startsWith('dial:')), hasLength(1));
      state.dispose();
    },
  );

  testWidgets(
    'late clipboard completion never writes into a closed mini-program',
    (tester) async {
      final provider = _SystemProvider()..pending = Completer<String?>();
      final state = MpStateManager()..set('result', {'kept': true});
      // Mount through the shared fixture, then begin a deliberately pending read.
      await _runMpAction(
        tester,
        Mp.state.set('mounted', true).toJson(),
        stateManager: state,
        clipboardProvider: provider,
        clipboardPolicy: const MiniProgramClipboardPolicy(
          enabled: true,
          allowRead: true,
        ),
      );
      final context = tester.element(find.byType(SizedBox).last);
      final pending = const MpActionRunner().run(
        context,
        Mp.clipboard.readText(targetState: 'result').toJson(),
        userGesture: true,
      );
      await tester.pumpWidget(const SizedBox());
      provider.pending!.complete('private text');
      final result = await pending as HostActionResult;
      expect(result.errorCode, MiniProgramErrorCodes.clipboardRequestCancelled);
      expect(result.data.toString(), isNot(contains('private text')));
      expect(state.get('result'), {'kept': true});
      state.dispose();
    },
  );

  test(
    'strict schemas reject unknown fields, control codes and raw vibration patterns',
    () {
      for (final action in <Map<String, dynamic>>[
        {
          'type': 'phone.openDialer',
          'props': {'number': '*123#'},
        },
        {
          'type': 'phone.openDialer',
          'props': {'number': 'tel:123'},
        },
        {
          'type': 'vibration.trigger',
          'props': {'duration': 10000},
        },
        {
          'type': 'vibration.trigger',
          'props': {'effect': 'forever'},
        },
        {'type': 'clipboard.readText', 'props': {}},
        {
          'type': 'clipboard.writeText',
          'props': {'text': 3},
        },
        {
          'type': 'clipboard.writeText',
          'props': {'text': 'a' * 32769},
        },
        {
          'type': 'clipboard.writeText',
          'props': {'text': 'a', 'sensitive': 'false'},
        },
      ]) {
        final screen = _jsonMap(
          MpProgram(
            screens: {
              'home': () => Mp.primaryButton(
                label: 'Run',
                action: MpAction(
                  action['type'] as String,
                  props: Map<String, Object?>.from(action['props'] as Map),
                ),
              ),
            },
          ).buildScreensJson()['home']!,
        );
        expect(
          () => const MpScreenValidator().validate(
            screen,
            expectedScreenId: 'home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
    },
  );
}

class _SystemProvider
    implements
        MiniProgramClipboardProvider,
        MiniProgramVibrationProvider,
        MiniProgramPhoneProvider {
  String? text;
  bool? sensitive;
  Completer<String?>? pending;
  final calls = <String>[];
  @override
  Future<String?> readText({
    required String miniProgramId,
    required int maxTextLength,
  }) async {
    calls.add('read');
    return pending == null ? text : pending!.future;
  }

  @override
  Future<void> writeText({
    required String miniProgramId,
    required String text,
    required bool sensitive,
  }) async {
    calls.add('write');
    this.text = text;
    this.sensitive = sensitive;
  }

  @override
  Future<bool> trigger({
    required String miniProgramId,
    required MiniProgramVibrationEffect effect,
  }) async {
    calls.add('haptic:${effect.name}');
    return false;
  }

  @override
  Future<void> openDialer({
    required String miniProgramId,
    required String number,
  }) async {
    calls.add('dial:$number');
  }
}
