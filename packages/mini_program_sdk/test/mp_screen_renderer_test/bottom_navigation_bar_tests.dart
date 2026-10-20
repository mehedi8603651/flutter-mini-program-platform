part of '../mp_screen_renderer_test.dart';

List<MpBottomNavigationItem> _bottomItems() => [
  MpBottomNavigationItem(
    icon: 'home',
    selectedIcon: 'star',
    label: 'Home',
    action: Mp.state.set('shop.tab', 0),
  ),
  MpBottomNavigationItem(
    icon: 'history',
    label: 'Orders',
    action: Mp.state.set('shop.tab', 1),
  ),
];

Map<String, dynamic> _bottomScreen(MpNode root) => _jsonMap(
  MpProgram(
    screens: {'coupon_home': () => root},
  ).buildScreensJson()['coupon_home']!,
);

Future<void> _pumpBottomBar(
  WidgetTester tester,
  MpNode root, {
  MpStateManager? state,
  ThemeData? theme,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  EdgeInsets padding = EdgeInsets.zero,
  MiniProgramOpenScreenHandler? onOpen,
}) async {
  final backend = MiniProgramBackendStore();
  addTearDown(backend.dispose);
  final app =
      _scopedApp(
            backendStore: backend,
            stateManager: state,
            openMiniProgramScreen: onOpen,
            screenJson: _bottomScreen(root),
          )
          as MaterialApp;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale), padding: padding),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: app.home,
    ),
  );
  await tester.pumpAndSettle();
}

void _mpBottomNavigationBarTests() {
  group('bottom navigation bars', () {
    test('validator accepts authoring output and every label behavior', () {
      for (final behavior in ['alwaysShow', 'onlyShowSelected', 'alwaysHide']) {
        const MpScreenValidator().validate(
          _bottomScreen(
            Mp.bottomNavigationBar(
              items: _bottomItems(),
              selectedIndex: '{{state.shop.tab}}',
              labelBehavior: behavior,
              height: 96,
              elevation: 2,
              backgroundColor: '#123456',
              indicatorColor: '#223344',
              selectedItemColor: '#FFFFFF',
              unselectedItemColor: '#AABBCC',
            ),
          ),
          expectedScreenId: 'coupon_home',
        );
      }
    });

    test(
      'validator rejects malformed bars, destinations, bindings and actions',
      () {
        void reject(void Function(Map<String, dynamic>) mutate) {
          final json = _bottomScreen(
            Mp.bottomNavigationBar(items: _bottomItems()),
          );
          mutate(json);
          expect(
            () => const MpScreenValidator().validate(
              json,
              expectedScreenId: 'coupon_home',
            ),
            throwsA(isA<MiniProgramRenderException>()),
          );
        }

        for (final change in <Map<String, dynamic>>[
          {'items': null},
          {'items': {}},
          {'items': []},
          {
            'items': [null, null],
          },
          {'selectedIndex': -1},
          {'selectedIndex': 2},
          {'selectedIndex': 0.0},
          {'selectedIndex': null},
          {'selectedIndex': true},
          {'selectedIndex': '1'},
          {'selectedIndex': 'x {{state.tab}}'},
          {'selectedIndex': '{{state.token}}'},
          {'selectedIndex': '{{unknown.tab}}'},
          {'labelBehavior': null},
          {'labelBehavior': 'bad'},
          {'labelBehavior': '{{state.behavior}}'},
          {'height': 63},
          {'height': 129},
          {'height': double.nan},
          {'height': '{{state.height}}'},
          {'elevation': -1},
          {'elevation': 25},
          {'elevation': double.infinity},
          {'backgroundColor': 'red'},
          {'indicatorColor': null},
          {'selectedItemColor': '{{state.color}}'},
          {'unselectedItemColor': '#12'},
          {'onTap': 'callback'},
        ]) {
          reject((json) => (json['root']['props'] as Map).addAll(change));
        }
        for (final missing in [
          'items',
          'selectedIndex',
          'labelBehavior',
          'height',
          'elevation',
        ]) {
          reject((json) => (json['root']['props'] as Map).remove(missing));
        }
        for (final count in [1, 6]) {
          reject(
            (json) => json['root']['props']['items'] = List.generate(
              count,
              (_) => _bottomItems().first.toJson(),
            ),
          );
        }
        for (final change in <Map<String, dynamic>>[
          {'icon': 'unknown'},
          {'icon': '{{state.icon}}'},
          {'selectedIcon': null},
          {'selectedIcon': 'unknown'},
          {'label': ''},
          {'label': 'x' * 513},
          {'label': '{{state.password}}'},
          {'enabled': null},
          {'enabled': 'true'},
          {'action': null},
          {
            'action': {'type': 'unknown', 'props': {}},
          },
          {'extra': 1},
        ]) {
          reject(
            (json) => (json['root']['props']['items'][0] as Map).addAll(change),
          );
        }
        for (final missing in ['icon', 'label', 'action', 'enabled']) {
          reject(
            (json) =>
                (json['root']['props']['items'][0] as Map).remove(missing),
          );
        }
        reject(
          (json) => json['root']['children'] = [Mp.text('Unexpected').toJson()],
        );
      },
    );

    testWidgets('selection and labels react locally without a state builder', (
      tester,
    ) async {
      final state = MpStateManager()..set('orders.label', 'Orders');
      addTearDown(state.dispose);
      final semantics = tester.ensureSemantics();
      await _pumpBottomBar(
        tester,
        Mp.bottomNavigationBar(
          selectedIndex: '{{state.shop.tab}}',
          items: [
            _bottomItems().first,
            MpBottomNavigationItem(
              icon: 'history',
              label: '{{state.orders.label}}',
              action: Mp.state.set('shop.tab', 1),
            ),
          ],
        ),
        state: state,
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(state.get('shop.tab'), 1);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      state.set('orders.label', 'My orders');
      await tester.pumpAndSettle();
      expect(find.text('My orders'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('My orders')), findsWidgets);
      for (final invalid in <Object?>[null, -1, 2, 1.0, '1', true, {}]) {
        state.set('shop.tab', invalid);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0,
          reason: '$invalid',
        );
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets(
      'literal selection stays controlled and disabled items ignore taps',
      (tester) async {
        final state = MpStateManager();
        addTearDown(state.dispose);
        await _pumpBottomBar(
          tester,
          Mp.bottomNavigationBar(items: _bottomItems()),
          state: state,
        );
        await tester.tap(find.text('Orders'));
        await tester.pumpAndSettle();
        expect(state.get('shop.tab'), 1);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0,
        );
        final disabled = MpBottomNavigationItem(
          icon: 'history',
          label: 'Disabled',
          enabled: false,
          action: Mp.state.set('shop.tab', 9),
        );
        await _pumpBottomBar(
          tester,
          Mp.bottomNavigationBar(items: [_bottomItems().first, disabled]),
          state: state,
        );
        await tester.tap(find.text('Disabled'));
        await tester.pumpAndSettle();
        expect(state.get('shop.tab'), 1);
      },
    );

    testWidgets(
      'pending actions ignore rapid taps and safely finish after disposal',
      (tester) async {
        final pending = Completer<HostActionResult>();
        var calls = 0;
        await _pumpBottomBar(
          tester,
          Mp.bottomNavigationBar(
            items: [
              _bottomItems().first,
              MpBottomNavigationItem(
                icon: 'history',
                label: 'Open orders',
                action: Mp.navigation.openScreen('orders'),
              ),
            ],
          ),
          onOpen: (_, _) {
            calls++;
            return pending.future;
          },
        );
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        bar.onDestinationSelected!(1);
        bar.onDestinationSelected!(1);
        await tester.pump();
        expect(calls, 1);
        expect(
          tester
              .widgetList<NavigationDestination>(
                find.byType(NavigationDestination),
              )
              .every((item) => !item.enabled),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete(_ok('openMiniProgramScreen'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'item taps provide gestures while host capability denial stays enforced',
      (tester) async {
        final state = MpStateManager();
        addTearDown(state.dispose);
        await _pumpBottomBar(
          tester,
          Mp.bottomNavigationBar(
            items: [
              _bottomItems().first,
              MpBottomNavigationItem(
                icon: 'bolt',
                label: 'Haptic',
                action: Mp.vibration.trigger(errorState: 'haptic.error'),
              ),
            ],
          ),
          state: state,
        );
        await tester.tap(find.text('Haptic'));
        await tester.pumpAndSettle();
        expect(state.get('haptic.error.code'), 'vibration_not_accepted');
      },
    );

    testWidgets('custom colors and selected icons use Material navigation', (
      tester,
    ) async {
      await _pumpBottomBar(
        tester,
        Mp.bottomNavigationBar(
          items: _bottomItems(),
          selectedIndex: 1,
          height: 96,
          backgroundColor: '#123456',
          indicatorColor: '#223344',
          selectedItemColor: '#FFFFFF',
          unselectedItemColor: '#AABBCC',
        ),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.height, 96);
      expect(bar.backgroundColor, const Color(0xFF123456));
      expect(bar.indicatorColor, const Color(0xFF223344));
      final context = tester.element(find.byType(NavigationBar));
      final theme = NavigationBarTheme.of(context);
      expect(
        theme.iconTheme!.resolve({WidgetState.selected})!.color,
        Colors.white,
      );
      expect(theme.labelTextStyle!.resolve({})!.color, const Color(0xFFAABBCC));
      expect(
        tester
            .widgetList<NavigationDestination>(
              find.byType(NavigationDestination),
            )
            .first
            .selectedIcon,
        isA<Icon>(),
      );
    });

    testWidgets('five long labels fit narrow RTL layouts with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(240, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpBottomBar(
        tester,
        Mp.page(
          child: Mp.column(
            children: [
              Mp.expanded(child: Mp.text('Shop content')),
              Mp.bottomNavigationBar(
                items: List.generate(
                  5,
                  (index) => MpBottomNavigationItem(
                    icon: 'home',
                    label: 'Long destination label $index',
                    action: Mp.toast(message: 'Selected'),
                  ),
                ),
              ),
            ],
          ),
        ),
        textScale: 2.5,
        direction: TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(find.text('Long destination label 0'));
      final defaults = DefaultTextStyle.of(
        tester.element(find.text('Long destination label 0')),
      );
      expect(label.maxLines ?? defaults.maxLines, 1);
      expect(label.overflow ?? defaults.overflow, TextOverflow.ellipsis);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );
    });

    testWidgets('fixed bar and form state survive content section switches', (
      tester,
    ) async {
      final state = MpStateManager()..set('shop.home', true);
      addTearDown(state.dispose);
      final bar = Mp.bottomNavigationBar(
        selectedIndex: '{{state.shop.tab}}',
        items: [
          MpBottomNavigationItem(
            icon: 'home',
            label: 'Home',
            action: Mp.state.patch({'shop.tab': 0, 'shop.home': true}),
          ),
          MpBottomNavigationItem(
            icon: 'history',
            label: 'Orders',
            action: Mp.state.patch({'shop.tab': 1, 'shop.home': false}),
          ),
        ],
      );
      await _pumpBottomBar(
        tester,
        Mp.page(
          child: Mp.column(
            children: [
              Mp.appBar(title: Mp.text('My shop')),
              Mp.expanded(
                child: Mp.condition(
                  condition: '{{state.shop.home}}',
                  whenTrue: Mp.scrollView(
                    child: Mp.column(
                      children: [
                        Mp.stateTextField(
                          stateKey: 'draft.home',
                          label: 'Home note',
                        ),
                        for (var i = 0; i < 30; i++) Mp.text('Product $i'),
                      ],
                    ),
                  ),
                  whenFalse: Mp.stateTextField(
                    stateKey: 'draft.orders',
                    label: 'Order note',
                  ),
                ),
              ),
              bar,
            ],
          ),
        ),
        state: state,
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );
      final position = tester.getTopLeft(find.byType(NavigationBar));
      expect(tester.getSize(find.byType(NavigationBar)).height, 80);
      await tester.enterText(find.byType(EditableText), 'booking draft');
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'order draft');
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('booking draft'), findsOneWidget);
      expect(state.get('draft.orders'), 'order draft');
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(NavigationBar)), position);
      expect(tester.takeException(), isNull);
    });
  });
}
