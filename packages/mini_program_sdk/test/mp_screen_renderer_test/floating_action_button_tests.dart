part of '../mp_screen_renderer_test.dart';

Map<String, dynamic> _floatingButtonScreen(MpNode root) => _jsonMap(
  MpProgram(
    screens: {'coupon_home': () => root},
  ).buildScreensJson()['coupon_home']!,
);

void _mpFloatingActionButtonTests() {
  group('floating action buttons', () {
    final increment = Mp.state.increment('booking.count');
    final variants = <String, MpNode>{
      'standard': Mp.floatingActionButton(
        icon: 'add',
        semanticLabel: 'Add booking',
        action: increment,
      ),
      'small': Mp.floatingActionButton.small(
        icon: 'edit',
        semanticLabel: 'Edit booking',
        action: increment,
      ),
      'large': Mp.floatingActionButton.large(
        icon: 'add',
        semanticLabel: 'Create booking',
        action: increment,
      ),
      'extended': Mp.floatingActionButton.extended(
        label: 'Book now',
        icon: 'add',
        action: increment,
      ),
      'textOnly': Mp.floatingActionButton.extended(
        label: 'Continue',
        action: increment,
      ),
    };

    test('validator accepts every pure-Dart variant', () {
      for (final button in variants.values) {
        const MpScreenValidator().validate(
          _floatingButtonScreen(button),
          expectedScreenId: 'coupon_home',
        );
      }
    });

    test(
      'validator rejects invalid properties, variants, actions and children',
      () {
        for (final change in <Map<String, dynamic>>[
          {'variant': 'giant'},
          {'variant': '{{state.variant}}'},
          {'variant': null},
          {'icon': null},
          {'icon': 'unknown'},
          {'icon': '{{state.icon}}'},
          {'semanticLabel': ''},
          {'semanticLabel': 'x' * 513},
          {'semanticLabel': '{{state.token}}'},
          {'label': 'Icon buttons cannot have labels'},
          {'enabled': 'true'},
          {'enabled': null},
          {'enabled': 1},
          {'backgroundColor': 'blue'},
          {'backgroundColor': null},
          {'foregroundColor': '{{state.color}}'},
          {'action': null},
          {
            'action': {'type': 'unknown', 'props': {}},
          },
          {'heroTag': 'app'},
          {'tooltip': 'Unexpected property'},
        ]) {
          final json = _floatingButtonScreen(variants['standard']!);
          (json['root']['props'] as Map).addAll(change);
          expect(
            () => const MpScreenValidator().validate(
              json,
              expectedScreenId: 'coupon_home',
            ),
            throwsA(isA<MiniProgramRenderException>()),
            reason: '$change',
          );
        }
        for (final missing in ['icon', 'variant', 'semanticLabel', 'action']) {
          final json = _floatingButtonScreen(variants['standard']!);
          (json['root']['props'] as Map).remove(missing);
          expect(
            () => const MpScreenValidator().validate(
              json,
              expectedScreenId: 'coupon_home',
            ),
            throwsA(isA<MiniProgramRenderException>()),
          );
        }
        for (final label in [null, '', 'x' * 513, 5]) {
          final json = _floatingButtonScreen(variants['extended']!);
          json['root']['props']['label'] = label;
          expect(
            () => const MpScreenValidator().validate(
              json,
              expectedScreenId: 'coupon_home',
            ),
            throwsA(isA<MiniProgramRenderException>()),
          );
        }
        final withChild = _floatingButtonScreen(variants['small']!);
        withChild['root']['children'] = [Mp.text('Unexpected').toJson()];
        expect(
          () => const MpScreenValidator().validate(
            withChild,
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      },
    );

    for (final entry in variants.entries) {
      testWidgets('${entry.key} renders and dispatches an existing action', (
        tester,
      ) async {
        final state = MpStateManager();
        final backend = MiniProgramBackendStore();
        addTearDown(state.dispose);
        addTearDown(backend.dispose);
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _floatingButtonScreen(entry.value),
          ),
        );
        await tester.pumpAndSettle();
        final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton),
        );
        expect(fab.heroTag, isNull);
        expect(fab.onPressed, isNotNull);
        if (entry.key == 'extended' || entry.key == 'textOnly') {
          expect(fab.isExtended, isTrue);
        } else {
          final size = tester
              .widget<RawMaterialButton>(find.byType(RawMaterialButton))
              .constraints;
          final dimension = {
            'standard': 56.0,
            'small': 40.0,
            'large': 96.0,
          }[entry.key]!;
          expect(size.maxWidth, dimension);
          expect(size.maxHeight, dimension);
        }
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(state.get('booking.count'), 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('disabled button has an accessible name and cannot dispatch', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final state = MpStateManager();
      final backend = MiniProgramBackendStore();
      addTearDown(state.dispose);
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          stateManager: state,
          screenJson: _floatingButtonScreen(
            Mp.floatingActionButton(
              icon: 'add',
              semanticLabel: 'Disabled booking',
              action: increment,
              enabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Disabled booking'), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(state.contains('booking.count'), isFalse);
      semantics.dispose();
    });

    testWidgets('literal colors override the host theme', (tester) async {
      final backend = MiniProgramBackendStore();
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          screenJson: _floatingButtonScreen(
            Mp.floatingActionButton.extended(
              label: 'Book',
              action: increment,
              backgroundColor: '#123456',
              foregroundColor: '#FFAABBCC',
            ),
          ),
        ),
      );
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.backgroundColor, const Color(0xFF123456));
      expect(fab.foregroundColor, const Color(0xFFAABBCC));
    });

    testWidgets('keyboard activation dispatches an existing action', (
      tester,
    ) async {
      final state = MpStateManager();
      final backend = MiniProgramBackendStore();
      addTearDown(state.dispose);
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          stateManager: state,
          screenJson: _floatingButtonScreen(variants['standard']!),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.get('booking.count'), 1);
    });

    testWidgets(
      'press supplies a gesture while preserving host capability denial',
      (tester) async {
        final state = MpStateManager();
        final backend = MiniProgramBackendStore();
        addTearDown(state.dispose);
        addTearDown(backend.dispose);
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _floatingButtonScreen(
              Mp.floatingActionButton(
                icon: 'bolt',
                semanticLabel: 'Request haptic',
                action: Mp.vibration.trigger(errorState: 'haptic.error'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(state.get('haptic.error.code'), 'vibration_not_accepted');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'labels rebuild locally and actions read current state bindings',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final state = MpStateManager()..set('choice', 'First');
        final backend = MiniProgramBackendStore();
        addTearDown(state.dispose);
        addTearDown(backend.dispose);
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _floatingButtonScreen(
              Mp.stateBuilder(
                keys: ['choice'],
                child: Mp.floatingActionButton.extended(
                  label: 'Book {{state.choice}}',
                  action: Mp.state.set('selected', '{{state.choice}}'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Book First'), findsOneWidget);
        state.set('choice', 'Second');
        await tester.pumpAndSettle();
        expect(find.text('Book Second'), findsOneWidget);
        expect(find.bySemanticsLabel('Book Second'), findsOneWidget);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(state.get('selected'), 'Second');
        semantics.dispose();
      },
    );

    testWidgets('extended labels fit narrow bounds at large text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(240, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final json = _floatingButtonScreen(
        Mp.floatingActionButton.extended(
          label:
              'A very long booking description that must stay inside the button',
          icon: 'add',
          action: increment,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => const MpScreenRenderer().render(
              MiniProgramRenderRequest(
                context: context,
                manifest: _mpManifest,
                screenId: 'coupon_home',
                screenJson: json,
                logger: const DebugPrintSdkLogger(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = find.text(
        'A very long booking description that must stay inside the button',
      );
      final buttonRect = tester.getRect(find.byType(FloatingActionButton));
      final textRect = tester.getRect(text);
      expect(textRect.left, greaterThanOrEqualTo(buttonRect.left));
      expect(textRect.right, lessThanOrEqualTo(buttonRect.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('positioned button stays fixed while content scrolls', (
      tester,
    ) async {
      final backend = MiniProgramBackendStore();
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          screenJson: _floatingButtonScreen(
            Mp.page(
              child: Mp.stack(
                children: [
                  Mp.scrollView(
                    child: Mp.column(
                      children: List.generate(
                        40,
                        (index) => Mp.container(
                          height: 50,
                          child: Mp.text('Booking $index'),
                        ),
                      ),
                    ),
                  ),
                  Mp.positioned(
                    right: 16,
                    bottom: 16,
                    child: variants['standard']!,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialPosition = tester.getTopLeft(
        find.byType(FloatingActionButton),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(FloatingActionButton)),
        initialPosition,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('several buttons coexist during navigation', (tester) async {
      final backend = MiniProgramBackendStore();
      addTearDown(backend.dispose);
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          screenJson: _floatingButtonScreen(
            Mp.wrap(children: variants.values.toList()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNWidgets(5));
      final context = tester.element(find.byType(FloatingActionButton).first);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Booking details')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Booking details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Booking details'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'pending navigation ignores duplicate taps and reenables after failure',
      (tester) async {
        final backend = MiniProgramBackendStore();
        addTearDown(backend.dispose);
        final pending = Completer<HostActionResult>();
        var calls = 0;
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            openMiniProgramScreen: (_, _) {
              calls++;
              return pending.future;
            },
            screenJson: _floatingButtonScreen(
              Mp.floatingActionButton(
                icon: 'add',
                semanticLabel: 'Open booking',
                action: Mp.navigation.openScreen('booking'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FloatingActionButton));
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        expect(calls, 1);
        expect(
          tester
              .widget<FloatingActionButton>(find.byType(FloatingActionButton))
              .onPressed,
          isNull,
        );
        pending.complete(
          HostActionResult.failed(
            actionName: 'openMiniProgramScreen',
            message: 'Unavailable',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FloatingActionButton>(find.byType(FloatingActionButton))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('disposal during an action has no late widget update', (
      tester,
    ) async {
      final backend = MiniProgramBackendStore();
      addTearDown(backend.dispose);
      final pending = Completer<HostActionResult>();
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          openMiniProgramScreen: (_, _) => pending.future,
          screenJson: _floatingButtonScreen(
            Mp.floatingActionButton(
              icon: 'add',
              semanticLabel: 'Open booking',
              action: Mp.navigation.openScreen('booking'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(_ok('openMiniProgramScreen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
