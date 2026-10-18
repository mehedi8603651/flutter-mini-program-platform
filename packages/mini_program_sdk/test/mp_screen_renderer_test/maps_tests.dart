part of '../mp_screen_renderer_test.dart';

void _mpMapsTests() {
  for (final directions in [false, true]) {
    MpAction action({
      Object latitude = 23.8103,
      String? target = 'map.result',
    }) => directions
        ? Mp.maps.openDirections(
            latitude: latitude,
            longitude: 90.4125,
            name: 'Food & tea 店',
            mode: MpMapTravelMode.walking,
            targetState: target,
            statusState: 'map.status',
            errorState: 'map.error',
          )
        : Mp.maps.openLocation(
            latitude: latitude,
            longitude: 90.4125,
            name: 'Food & tea 店',
            targetState: target,
            statusState: 'map.status',
            errorState: 'map.error',
          );

    testWidgets(
      'maps ${directions ? 'directions' : 'pin'} require gesture, visibility and independent host acceptance',
      (tester) async {
        final provider = _MapsProvider();
        final state = MpStateManager()..set('map.result', {'kept': true});
        addTearDown(state.dispose);
        for (final config in [
          (
            false,
            true,
            const MiniProgramMapsPolicy(),
            'maps_user_gesture_required',
          ),
          (
            true,
            false,
            const MiniProgramMapsPolicy(enabled: true),
            'maps_foreground_required',
          ),
          (true, true, const MiniProgramMapsPolicy(), 'maps_not_accepted'),
          (
            true,
            true,
            MiniProgramMapsPolicy(
              enabled: true,
              allowOpenLocation: directions,
              allowDirections: !directions,
            ),
            'maps_not_accepted',
          ),
        ]) {
          final result =
              await _runMpAction(
                    tester,
                    action().toJson(),
                    stateManager: state,
                    mapsProvider: provider,
                    mapsPolicy: config.$3,
                    userGesture: config.$1,
                    isForeground: config.$2,
                  )
                  as HostActionResult;
          expect(result.errorCode, config.$4);
          expect(state.get('map.result'), {'kept': true});
        }
        expect(provider.calls, isEmpty);
        final missing =
            await _runMpAction(
                  tester,
                  action().toJson(),
                  stateManager: state,
                  mapsPolicy: const MiniProgramMapsPolicy(enabled: true),
                  userGesture: true,
                )
                as HostActionResult;
        expect(missing.errorCode, 'maps_unavailable');
      },
    );

    testWidgets(
      'maps resolves numeric bindings and commits only sanitized opened metadata',
      (tester) async {
        final provider = _MapsProvider();
        final state = MpStateManager()
          ..set('shop.lat', -33.8666)
          ..set('map.error', {'old': true});
        addTearDown(state.dispose);
        final snapshots = <Map<String, dynamic>>[];
        final watcher = state.watch('map.status');
        void onStatus() {
          snapshots.add(Map<String, dynamic>.from(state.get('map') as Map));
        }

        watcher.addListener(onStatus);
        addTearDown(() => watcher.removeListener(onStatus));
        final result =
            await _runMpAction(
                  tester,
                  action(latitude: '{{state.shop.lat}}').toJson(),
                  stateManager: state,
                  mapsProvider: provider,
                  mapsPolicy: const MiniProgramMapsPolicy(enabled: true),
                  userGesture: true,
                )
                as HostActionResult;
        expect(result.data, {
          'mapOpened': true,
          'operation': directions ? 'directions' : 'location',
        });
        expect(state.get('map.result'), result.data);
        expect(state.get('map.status'), 'success');
        expect(state.contains('map.error'), isFalse);
        expect(provider.calls.single.$1.latitude, -33.8666);
        expect(
          provider.calls.single.$1.coordinateSystem,
          MiniProgramMapCoordinateSystem.wgs84,
        );
        expect(
          provider.calls.single.$2,
          directions ? MiniProgramMapTravelMode.walking : null,
        );
        expect(snapshots.last['result'], result.data);
      },
    );

    testWidgets(
      'maps rejects invalid resolved coordinates before launching and stops sequences',
      (tester) async {
        final provider = _MapsProvider();
        final state = MpStateManager()..set('map.result', {'kept': true});
        addTearDown(state.dispose);
        for (final value in <Object?>[91, '23.8', null, true, {}, []]) {
          state.set('latitude', value);
          await _runMpAction(
            tester,
            Mp.action.sequence([
              action(latitude: '{{state.latitude}}'),
              Mp.state.set('after', true),
            ]).toJson(),
            stateManager: state,
            mapsProvider: provider,
            mapsPolicy: const MiniProgramMapsPolicy(enabled: true),
            userGesture: true,
          );
          expect(state.get('map.error.code'), 'maps_invalid_request');
          expect(state.get('map.result'), {'kept': true});
          expect(state.contains('after'), isFalse);
        }
        expect(provider.calls, isEmpty);
      },
    );
  }

  testWidgets('maps rejects lifecycle background and covered Flutter routes', (
    tester,
  ) async {
    final provider = _MapsProvider();
    final state = MpStateManager();
    addTearDown(state.dispose);
    await _runMpAction(
      tester,
      Mp.state.set('mount', true).toJson(),
      stateManager: state,
      mapsProvider: provider,
      mapsPolicy: const MiniProgramMapsPolicy(enabled: true),
    );
    final context = tester.element(find.byType(SizedBox).last);
    final action = Mp.maps
        .openLocation(latitude: 0, longitude: 0, name: 'Shop')
        .toJson();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final background =
        await const MpActionRunner().run(context, action, userGesture: true)
            as HostActionResult;
    expect(background.errorCode, 'maps_foreground_required');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const Text('Chat'))),
    );
    await tester.pumpAndSettle();
    final covered =
        await const MpActionRunner().run(context, action, userGesture: true)
            as HostActionResult;
    expect(covered.errorCode, 'maps_foreground_required');
    expect(provider.calls, isEmpty);
  });

  testWidgets(
    'maps sanitizes unavailable and provider errors and preserves previous state',
    (tester) async {
      final provider = _MapsProvider();
      final state = MpStateManager()..set('result', {'old': true});
      addTearDown(state.dispose);
      for (final code in [
        'maps_unavailable',
        'maps_coordinate_system_unsupported',
        'maps_foreground_required',
        'unknown_native_error',
      ]) {
        provider.failure = MiniProgramMapsException(
          errorCode: code,
          message: 'secret://native/path',
        );
        final result =
            await _runMpAction(
                  tester,
                  Mp.maps
                      .openLocation(
                        latitude: 0,
                        longitude: 0,
                        name: 'Shop',
                        targetState: 'result',
                        errorState: 'error',
                      )
                      .toJson(),
                  stateManager: state,
                  mapsProvider: provider,
                  mapsPolicy: const MiniProgramMapsPolicy(enabled: true),
                  userGesture: true,
                )
                as HostActionResult;
        expect(
          result.errorCode,
          code == 'unknown_native_error' ? 'maps_operation_failed' : code,
        );
        expect(state.get('result'), {'old': true});
        expect(state.get('error').toString(), isNot(contains('secret')));
      }
    },
  );

  testWidgets('external map launch may pause Activity without losing state', (
    tester,
  ) async {
    final provider = _MapsProvider()..pending = Completer<void>();
    final state = MpStateManager()..set('draft', 'Booking 123');
    addTearDown(state.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _runMpAction(
      tester,
      Mp.state.set('mount', true).toJson(),
      stateManager: state,
      mapsProvider: provider,
      mapsPolicy: const MiniProgramMapsPolicy(enabled: true),
    );
    final context = tester.element(find.byType(SizedBox).last);
    final pending = const MpActionRunner().run(
      context,
      Mp.maps
          .openLocation(
            latitude: 0,
            longitude: 0,
            name: 'Shop',
            targetState: 'result',
          )
          .toJson(),
      userGesture: true,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    provider.pending!.complete();
    expect((await pending as HostActionResult).data['mapOpened'], isTrue);
    expect(state.get('draft'), 'Booking 123');
  });

  testWidgets(
    'late map completion cannot write into another or disposed mini-program',
    (tester) async {
      for (final unmount in [false, true]) {
        final provider = _MapsProvider()..pending = Completer<void>();
        final state = MpStateManager()..set('result', {'old': true});
        await _runMpAction(
          tester,
          Mp.state.set('mount', true).toJson(),
          stateManager: state,
          mapsProvider: provider,
          mapsPolicy: const MiniProgramMapsPolicy(enabled: true),
        );
        final context = tester.element(find.byType(SizedBox).last);
        final pending = const MpActionRunner().run(
          context,
          Mp.maps
              .openLocation(
                latitude: 0,
                longitude: 0,
                name: 'Shop',
                targetState: 'result',
              )
              .toJson(),
          userGesture: true,
        );
        if (unmount) {
          await tester.pumpWidget(const SizedBox());
        } else {
          await _runMpAction(
            tester,
            Mp.state.set('other', true).toJson(),
            miniProgramId: 'other',
            stateManager: state,
          );
        }
        provider.pending!.complete();
        expect(
          (await pending as HostActionResult).errorCode,
          'maps_request_cancelled',
        );
        expect(state.get('result'), {'old': true});
        state.dispose();
      }
    },
  );

  test(
    'map schema rejects unknown properties, bad types, enums and unsafe coordinates',
    () {
      final base =
          Mp.maps
                  .openLocation(latitude: 0, longitude: 0, name: 'Shop')
                  .toJson()['props']
              as Map;
      for (final patch in <Map<String, dynamic>>[
        {'latitude': 91},
        {'latitude': '23.8'},
        {'longitude': -181},
        {'coordinateSystem': 'auto'},
        {'name': ''},
        {'name': 'x' * 121},
        {'name': 'shop\n'},
        {'address': '\u0000'},
        {'address': 'x' * 513},
        {'url': 'https://evil.test'},
        {'package': 'evil.app'},
        {'mode': 'walking'},
        {'origin': '{{state.position}}'},
      ]) {
        final screen = _cacheActionScreen('maps.openLocation', {
          ...base,
          ...patch,
        });
        expect(
          () => const MpScreenValidator().validate(
            screen,
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
      final screen = _cacheActionScreen('maps.openDirections', {
        ...base,
        'mode': 'flying',
      });
      expect(
        () => const MpScreenValidator().validate(
          screen,
          expectedScreenId: 'coupon_home',
        ),
        throwsA(isA<MiniProgramRenderException>()),
      );
    },
  );
}

class _MapsProvider implements MiniProgramMapsProvider {
  final calls = <(MiniProgramMapDestination, MiniProgramMapTravelMode?)>[];
  Completer<void>? pending;
  MiniProgramMapsException? failure;
  @override
  Future<void> openLocation({
    required String miniProgramId,
    required MiniProgramMapDestination destination,
  }) async {
    calls.add((destination, null));
    if (failure != null) throw failure!;
    if (pending != null) await pending!.future;
  }

  @override
  Future<void> openDirections({
    required String miniProgramId,
    required MiniProgramMapDestination destination,
    required MiniProgramMapTravelMode mode,
  }) async {
    calls.add((destination, mode));
    if (failure != null) throw failure!;
    if (pending != null) await pending!.future;
  }
}
