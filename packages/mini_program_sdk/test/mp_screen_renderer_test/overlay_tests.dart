part of '../mp_screen_renderer_test.dart';

Map<String, dynamic> _overlayScreen(MpAction action, {MpNode? before}) =>
    _bottomScreen(
      Mp.column(
        children: [
          if (before != null) before,
          Mp.primaryButton(label: 'Open panel', action: action),
        ],
      ),
    );

Future<void> _pumpOverlay(
  WidgetTester tester,
  MpAction action, {
  MpStateManager? state,
  MpNode? before,
}) async {
  final backend = MiniProgramBackendStore();
  addTearDown(backend.dispose);
  await tester.pumpWidget(
    _scopedApp(
      backendStore: backend,
      stateManager: state,
      screenJson: _overlayScreen(action, before: before),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open panel'));
  await tester.pumpAndSettle();
}

class _DelayedOverlayGalleryProvider extends _ResultGalleryProvider {
  final ready = Completer<void>();
  @override
  Future<MiniProgramGalleryResult> pickImages(
    MiniProgramGalleryRequest request,
  ) async {
    await ready.future;
    return super.pickImages(request);
  }
}

void _mpOverlayTests() {
  group('drawers, sheets and dialogs', () {
    testWidgets('dismissed panels do not refocus an earlier text field', (
      tester,
    ) async {
      final backend = MiniProgramBackendStore();
      final state = MpStateManager();
      addTearDown(backend.dispose);
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          stateManager: state,
          screenJson: _overlayScreen(
            Mp.drawer.left(child: Mp.text('Menu')),
            before: Mp.stateTextField(stateKey: 'draft', label: 'Draft'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Saved draft');
      final focus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(focus.hasFocus, isTrue);
      await tester.tap(find.text('Open panel'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(state.get<String>('draft'), 'Saved draft');
    });

    testWidgets('system picker pauses keep panel selection contexts alive', (
      tester,
    ) async {
      final backend = MiniProgramBackendStore();
      final state = MpStateManager();
      final provider = _DelayedOverlayGalleryProvider();
      final media = MiniProgramMediaManager(provider);
      final gallery = MiniProgramGalleryManager(provider, mediaManager: media);
      addTearDown(backend.dispose);
      addTearDown(state.dispose);
      addTearDown(media.dispose);
      addTearDown(gallery.dispose);
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          stateManager: state,
          galleryManager: gallery,
          mediaManager: media,
          galleryPolicy: const MiniProgramGalleryPolicy(enabled: true),
          screenJson: _overlayScreen(
            Mp.drawer.left(
              child: Mp.primaryButton(
                label: 'Choose photo',
                action: Mp.gallery.pickImages(
                  targetState: 'photos',
                  statusState: 'selection.status',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open panel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      provider.ready.complete();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Choose photo'), findsOneWidget);
      expect(state.get<String>('selection.status'), 'success');
      expect(state.get<Map>('photos')?['images'], isNotEmpty);
      expect(provider.released, isEmpty);
    });
    testWidgets('panels keep current host permissions and gesture checks', (
      tester,
    ) async {
      final backend = MiniProgramBackendStore();
      final state = MpStateManager();
      final provider = _SystemProvider();
      addTearDown(backend.dispose);
      addTearDown(state.dispose);
      final json = _overlayScreen(
        Mp.drawer.left(
          child: Mp.primaryButton(
            label: 'Copy note',
            action: Mp.clipboard.writeText(text: 'Booking note'),
          ),
        ),
      );
      Widget app(bool accepted) => _scopedApp(
        backendStore: backend,
        stateManager: state,
        clipboardProvider: provider,
        clipboardPolicy: MiniProgramClipboardPolicy(enabled: accepted),
        screenJson: json,
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open panel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy note'));
      await tester.pumpAndSettle();
      expect(provider.calls, hasLength(1));
      final panelContext = tester.element(find.text('Copy note'));
      final noGesture =
          await const MpActionRunner().run(
                panelContext,
                Mp.clipboard.writeText(text: 'No gesture').toJson(),
              )
              as HostActionResult;
      expect(
        noGesture.errorCode,
        MiniProgramErrorCodes.clipboardUserGestureRequired,
      );
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy note'));
      await tester.pumpAndSettle();
      expect(provider.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'panel fields can share the opening form and its current bindings',
      (tester) async {
        final backend = MiniProgramBackendStore();
        final state = MpStateManager();
        addTearDown(backend.dispose);
        addTearDown(state.dispose);
        final root = Mp.form(
          id: 'booking',
          children: [
            Mp.primaryButton(
              label: 'Open panel',
              action: Mp.drawer.right(
                child: Mp.column(
                  children: [
                    Mp.textInput(name: 'traveler', label: 'Traveler'),
                    Mp.primaryButton(
                      label: 'Save traveler',
                      action: Mp.state.set('saved', '{{form.traveler}}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _bottomScreen(root),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open panel'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'Alice');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save traveler'));
        await tester.pumpAndSettle();
        expect(state.get<String>('saved'), 'Alice');
      },
    );

    testWidgets(
      'repeated opening is bounded and close without a panel is harmless',
      (tester) async {
        final backend = MiniProgramBackendStore();
        addTearDown(backend.dispose);
        final action = Mp.drawer.left(
          child: Mp.primaryButton(
            label: 'Next panel',
            action: Mp.action.call('openNext'),
          ),
        );
        final root = Mp.actionScope(
          actions: {'openNext': action},
          child: Mp.column(
            children: [
              Mp.primaryButton(label: 'Close none', action: Mp.drawer.close()),
              Mp.primaryButton(
                label: 'Open panel',
                action: Mp.action.call('openNext'),
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          _scopedApp(backendStore: backend, screenJson: _bottomScreen(root)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close none'));
        await tester.pumpAndSettle();
        expect(find.text('Open panel'), findsOneWidget);
        await tester.tap(find.text('Open panel'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 9; i++) {
          await tester.tap(find.text('Next panel').last);
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(const ValueKey('mp-drawer-left'), skipOffstage: false),
          findsNWidgets(8),
        );
        for (var i = 0; i < 8; i++) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        expect(find.text('Open panel'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('late confirmation never closes an unrelated host route', (
      tester,
    ) async {
      final backend = MiniProgramBackendStore();
      addTearDown(backend.dispose);
      final completion = Completer<HostActionResult>();
      final app = _scopedApp(
        backendStore: backend,
        openMiniProgramScreen: (_, _) => completion.future,
        screenJson: _overlayScreen(
          Mp.dialog(
            message: 'Pending confirmation',
            onConfirm: Mp.navigation.openScreen('details'),
          ),
        ),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open panel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pump();
      final navigator = Navigator.of(
        tester.element(find.text('Pending confirmation')),
      );
      await tester.pumpWidget(const MaterialApp(home: Text('Host screen')));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(builder: (_) => const Text('New host route')),
        ),
      );
      await tester.pumpAndSettle();
      completion.complete(_ok('openMiniProgramScreen'));
      await tester.pumpAndSettle();
      expect(find.text('New host route'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay actions fail cleanly without a renderer owner', (
      tester,
    ) async {
      final result =
          await _runMpAction(
                tester,
                Mp.drawer.left(child: Mp.text('Unowned')).toJson(),
              )
              as HostActionResult;
      expect(result.errorCode, MiniProgramErrorCodes.overlayUnavailable);
    });

    test('validator accepts all authoring variants and nesting', () {
      final actions = [
        Mp.drawer.left(child: Mp.text('Left')),
        Mp.drawer.right(child: Mp.text('Right')),
        Mp.sheet.bottom(child: Mp.text('Bottom')),
        Mp.sheet.top(child: Mp.text('Top')),
        Mp.dialog(message: 'Alert', onConfirm: Mp.state.set('confirmed', true)),
        Mp.dialog.custom(
          child: Mp.primaryButton(label: 'Close', action: Mp.dialog.close()),
        ),
        Mp.drawer.left(
          child: Mp.primaryButton(
            label: 'Sheet',
            action: Mp.sheet.bottom(child: Mp.text('Nested')),
          ),
        ),
        Mp.drawer.close(),
        Mp.sheet.close(),
        Mp.dialog.close(),
      ];
      for (final action in actions) {
        const MpScreenValidator().validate(
          _overlayScreen(action),
          expectedScreenId: 'coupon_home',
        );
      }
    });

    test(
      'validator rejects invalid props, untrusted nested content and actions',
      () {
        void reject(
          MpAction action,
          void Function(Map<String, dynamic>) mutate,
        ) {
          final json = _overlayScreen(action);
          final props =
              json['root']['children'].last['props']['action']['props']
                  as Map<String, dynamic>;
          mutate(props);
          expect(
            () => const MpScreenValidator().validate(
              json,
              expectedScreenId: 'coupon_home',
            ),
            throwsA(isA<MiniProgramRenderException>()),
          );
        }

        final drawer = Mp.drawer.left(child: Mp.text('Safe'));
        for (final entry in <String, Object?>{
          'side': 'top',
          'width': 0,
          'dismissible': 'yes',
          'enableDrag': 1,
          'padding': -1,
          'borderRadius': 80,
          'backgroundColor': 'red',
          'barrierColor': '{{state.color}}',
          'unknown': true,
          'child': '{{state.node}}',
        }.entries) {
          reject(drawer, (props) => props[entry.key] = entry.value);
        }
        reject(drawer, (props) => props['child']['type'] = 'untrustedWidget');
        reject(
          drawer,
          (props) => props['child']['props']['data'] = '{{auth.token}}',
        );
        reject(Mp.drawer.close(), (props) => props['screenId'] = 'host');
        reject(
          Mp.sheet.top(child: Mp.text('Top')),
          (props) => props['heightFactor'] = 1.1,
        );
        reject(
          Mp.sheet.bottom(child: Mp.text('Bottom')),
          (props) => props['showDragHandle'] = 1,
        );
        reject(
          Mp.dialog(message: 'Alert'),
          (props) => props['onConfirm'] = {'type': 'unknown', 'props': {}},
        );
        reject(
          Mp.dialog.custom(child: Mp.text('Custom')),
          (props) => props['message'] = 'Mixed',
        );
      },
    );

    test('nested panel content cannot reset the payload node/depth budget', () {
      Map<String, dynamic> node = Mp.text(
        'Deep',
      ).toJson().cast<String, dynamic>();
      for (var i = 0; i < 90; i++) {
        node = {
          'type': 'primaryButton',
          'props': {
            'label': 'Open',
            'action': {
              'type': 'ui.drawer.open',
              'props': {'side': 'left', 'child': node},
            },
          },
          'children': [],
        };
      }
      expect(
        () => const MpScreenValidator().validate({
          'schemaVersion': 1,
          'screenId': 'coupon_home',
          'root': node,
        }, expectedScreenId: 'coupon_home'),
        throwsA(isA<MiniProgramRenderException>()),
      );
      final children = List.generate(500, (_) => Mp.text('Item'));
      final action = Mp.drawer.left(
        child: Mp.column(
          children: [
            for (var i = 0; i < 5; i++)
              Mp.primaryButton(
                label: 'Next',
                action: Mp.sheet.bottom(child: Mp.column(children: children)),
              ),
          ],
        ),
      );
      expect(
        () => const MpScreenValidator().validate(
          _overlayScreen(action),
          expectedScreenId: 'coupon_home',
        ),
        throwsA(isA<MiniProgramRenderException>()),
      );
    });

    test('omitting optional node props cannot bypass the combined budget', () {
      final minimalNodes = List.generate(
        180,
        (_) => <String, dynamic>{'type': 'sizedBox'},
      );
      final json = _overlayScreen(Mp.drawer.left(child: Mp.text('Menu')));
      json['root']['children'].last['props']['action']['props']['child'] = {
        'type': 'column',
        'children': [
          for (var i = 0; i < 12; i++)
            {
              'type': 'primaryButton',
              'props': {
                'label': 'More',
                'action': {
                  'type': 'ui.sheet.open',
                  'props': {
                    'side': 'bottom',
                    'child': {'type': 'column', 'children': minimalNodes},
                  },
                },
              },
            },
        ],
      };
      expect(
        () => const MpScreenValidator().validate(
          json,
          expectedScreenId: 'coupon_home',
        ),
        throwsA(isA<MiniProgramRenderException>()),
      );
    });

    for (final side in ['left', 'right', 'bottom', 'top']) {
      testWidgets(
        '$side panel opens at the correct edge and closes explicitly',
        (tester) async {
          final close = side == 'left' || side == 'right'
              ? Mp.drawer.close()
              : Mp.sheet.close();
          final child = Mp.primaryButton(label: 'Close panel', action: close);
          final action = switch (side) {
            'left' => Mp.drawer.left(child: child),
            'right' => Mp.drawer.right(child: child),
            'top' => Mp.sheet.top(child: child),
            _ => Mp.sheet.bottom(child: child),
          };
          await _pumpOverlay(tester, action);
          final kind = side == 'left' || side == 'right' ? 'drawer' : 'sheet';
          final rect = tester.getRect(find.byKey(ValueKey('mp-$kind-$side')));
          if (side == 'left') expect(rect.left, 0);
          if (side == 'right') expect(rect.right, 800);
          if (side == 'top') expect(rect.top, 0);
          if (side == 'bottom') expect(rect.bottom, 600);
          await tester.tap(find.text('Close panel'));
          await tester.pumpAndSettle();
          expect(find.text('Close panel'), findsNothing);
          expect(find.text('Open panel'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('drawer actions and bindings share the existing live state', (
      tester,
    ) async {
      final state = MpStateManager();
      addTearDown(state.dispose);
      state.set('shop.count', 2);
      await _pumpOverlay(
        tester,
        Mp.drawer.left(
          child: Mp.column(
            children: [
              Mp.stateBuilder(
                keys: ['shop.count'],
                child: Mp.text('Count {{state.shop.count}}'),
              ),
              Mp.primaryButton(
                label: 'Increment',
                action: Mp.state.increment('shop.count'),
              ),
              Mp.primaryButton(label: 'Close panel', action: Mp.drawer.close()),
            ],
          ),
        ),
        state: state,
        before: Mp.stateBuilder(
          keys: ['shop.count'],
          child: Mp.text('Body {{state.shop.count}}'),
        ),
      );
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(state.get<int>('shop.count'), 3);
      expect(find.text('Count 3'), findsOneWidget);
      expect(find.text('Increment'), findsOneWidget);
      await tester.tap(find.text('Close panel'));
      await tester.pumpAndSettle();
      expect(find.text('Body 3'), findsOneWidget);
    });

    testWidgets(
      'panel controls preserve named actions and list item bindings',
      (tester) async {
        final state = MpStateManager();
        addTearDown(state.dispose);
        final backend = MiniProgramBackendStore();
        addTearDown(backend.dispose);
        final root = Mp.actionScope(
          actions: {'choose': Mp.state.set('chosen', '{{item.name}}')},
          child: Mp.repeat(
            source: '{{state.shops}}',
            itemTemplate: Mp.primaryButton(
              label: 'Open panel',
              action: Mp.drawer.left(
                child: Mp.primaryButton(
                  label: 'Choose {{item.name}}',
                  action: Mp.action.call('choose'),
                ),
              ),
            ),
          ),
        );
        state.set('shops', [
          {'name': 'Shop A'},
        ]);
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _bottomScreen(root),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open panel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose Shop A'));
        await tester.pumpAndSettle();
        expect(state.get<String>('chosen'), 'Shop A');
      },
    );

    testWidgets('Back dismisses only the top panel before the page', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        Mp.drawer.left(
          child: Mp.primaryButton(
            label: 'Open sheet',
            action: Mp.sheet.bottom(child: Mp.text('Nested sheet')),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Nested sheet'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Nested sheet'), findsNothing);
      expect(find.text('Open sheet'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open panel'), findsOneWidget);
    });

    testWidgets('a family close action never pops a different panel', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        Mp.sheet.bottom(
          child: Mp.column(
            children: [
              Mp.primaryButton(
                label: 'Close drawer',
                action: Mp.drawer.close(),
              ),
              Mp.text('Sheet stays'),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Close drawer'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet stays'), findsOneWidget);
    });

    testWidgets('outside taps respect dismissible while Back stays available', (
      tester,
    ) async {
      await _pumpOverlay(
        tester,
        Mp.drawer.left(child: Mp.text('Persistent panel'), dismissible: false),
      );
      await tester.tapAt(const Offset(750, 300));
      await tester.pumpAndSettle();
      expect(find.text('Persistent panel'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Persistent panel'), findsNothing);
      await _pumpOverlay(
        tester,
        Mp.drawer.right(child: Mp.text('Dismissible panel')),
      );
      await tester.tapAt(const Offset(10, 300));
      await tester.pumpAndSettle();
      expect(find.text('Dismissible panel'), findsNothing);
    });

    testWidgets(
      'sheet handles and drawers support directional swipe dismissal',
      (tester) async {
        await _pumpOverlay(
          tester,
          Mp.sheet.bottom(child: Mp.text('Swipe sheet')),
        );
        final sheet = tester.getRect(
          find.byKey(const ValueKey('mp-sheet-bottom')),
        );
        await tester.dragFrom(
          sheet.topCenter + const Offset(0, 20),
          const Offset(0, 120),
        );
        await tester.pumpAndSettle();
        expect(find.text('Swipe sheet'), findsNothing);
        await _pumpOverlay(
          tester,
          Mp.drawer.right(child: Mp.text('Swipe drawer')),
        );
        await tester.drag(find.text('Swipe drawer'), const Offset(150, 0));
        await tester.pumpAndSettle();
        expect(find.text('Swipe drawer'), findsNothing);
      },
    );

    testWidgets(
      'dialog confirmation is explicit and preserves existing call syntax',
      (tester) async {
        final state = MpStateManager();
        addTearDown(state.dispose);
        final action = Mp.dialog(
          title: 'Order',
          message: 'Confirm booking?',
          confirmLabel: 'Confirm',
          cancelLabel: 'Cancel',
          onConfirm: Mp.state.set('confirmed', true),
          onCancel: Mp.state.set('confirmed', false),
        );
        await _pumpOverlay(tester, action, state: state);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(state.contains('confirmed'), isFalse);
        await tester.tap(find.text('Open panel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(state.get<bool>('confirmed'), isTrue);
        expect(find.text('Confirm booking?'), findsNothing);
        await tester.tap(find.text('Open panel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(state.get<bool>('confirmed'), isFalse);
      },
    );

    testWidgets('custom dialogs support state fields and explicit close', (
      tester,
    ) async {
      final state = MpStateManager();
      addTearDown(state.dispose);
      await _pumpOverlay(
        tester,
        Mp.dialog.custom(
          child: Mp.column(
            children: [
              Mp.stateTextField(
                stateKey: 'booking.note',
                label: 'Booking note',
              ),
              Mp.primaryButton(label: 'Save note', action: Mp.dialog.close()),
            ],
          ),
        ),
        state: state,
      );
      await tester.enterText(find.byType(EditableText), 'Window seat');
      await tester.pump();
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open panel'));
      await tester.pumpAndSettle();
      expect(find.text('Window seat'), findsOneWidget);
      expect(state.get<String>('booking.note'), 'Window seat');
    });

    testWidgets(
      'OS pauses retain panels while owner disposal removes them safely',
      (tester) async {
        await _pumpOverlay(
          tester,
          Mp.drawer.left(child: Mp.text('Owned panel')),
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.text('Owned panel'), findsOneWidget);
        await tester.pumpWidget(const MaterialApp(home: Text('Host remains')));
        await tester.pumpAndSettle();
        expect(find.text('Owned panel'), findsNothing);
        expect(find.text('Host remains'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'hidden or changed app owners invalidate panels and preserve state',
      (tester) async {
        final state = MpStateManager();
        addTearDown(state.dispose);
        final backend = MiniProgramBackendStore();
        addTearDown(backend.dispose);
        final json = _overlayScreen(
          Mp.sheet.top(child: Mp.text('Owned sheet')),
        );
        Widget app({bool visible = true, String appId = 'coupon'}) =>
            _scopedApp(
              backendStore: backend,
              stateManager: state,
              miniProgramId: appId,
              isForeground: visible,
              screenJson: json,
            );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        state.set('booking.draft', 'Keep');
        await tester.tap(find.text('Open panel'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(app(visible: false));
        await tester.pumpAndSettle();
        expect(find.text('Owned sheet'), findsNothing);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open panel'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(app(appId: 'other'));
        await tester.pumpAndSettle();
        expect(find.text('Owned sheet'), findsNothing);
        expect(state.get<String>('booking.draft'), 'Keep');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'narrow viewports and keyboard insets keep content scrollable',
      (tester) async {
        tester.view.physicalSize = const Size(280, 420);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: 180);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await _pumpOverlay(
          tester,
          Mp.sheet.bottom(
            heightFactor: 1,
            child: Mp.column(
              children: [
                for (var i = 0; i < 30; i++) Mp.text('Filter $i'),
                Mp.primaryButton(
                  label: 'Apply filters',
                  action: Mp.sheet.close(),
                ),
              ],
            ),
          ),
        );
        final rect = tester.getRect(
          find.byKey(const ValueKey('mp-sheet-bottom')),
        );
        expect(rect.bottom, lessThanOrEqualTo(240));
        await tester.scrollUntilVisible(
          find.text('Apply filters'),
          120,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('mp-sheet-bottom')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('Apply filters'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('very short sheets and large text stay within layout bounds', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(220, 140);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpOverlay(
        tester,
        Mp.sheet.top(heightFactor: 0.1, child: Mp.text('Small sheet')),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('mp-sheet-top'))).height,
        14,
      );
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });
  });
}
