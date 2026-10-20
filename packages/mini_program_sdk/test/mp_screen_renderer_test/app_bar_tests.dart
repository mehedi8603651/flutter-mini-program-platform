part of '../mp_screen_renderer_test.dart';

Map<String, dynamic> _appBarScreen(MpNode root) => _jsonMap(
  MpProgram(
    screens: {'coupon_home': () => root},
  ).buildScreensJson()['coupon_home']!,
);

Future<void> _pumpAppBar(
  WidgetTester tester,
  MpNode root, {
  ThemeData? theme,
  TextDirection? direction,
  double scale = 1,
  MpStateManager? stateManager,
}) async {
  final json = _appBarScreen(root);
  final backend = MiniProgramBackendStore();
  addTearDown(backend.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: direction ?? TextDirection.ltr,
            child: MiniProgramSdkScope(
              miniProgramId: 'coupon',
              hostBridge: _NoopHostBridge(),
              capabilityRegistry: CapabilityRegistry(const []),
              cacheManager: MiniProgramCacheManager.inMemory(),
              cachePolicy: const MiniProgramCachePolicy(),
              backendStore: backend,
              stateManager: stateManager,
              featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
              logger: const DebugPrintSdkLogger(),
              openMiniProgramScreen: (_, _) async =>
                  _ok('openMiniProgramScreen'),
              resetMiniProgramStack: (_, _) async =>
                  _ok('resetMiniProgramStack'),
              replaceMiniProgramScreen: (_, _) async =>
                  _ok('replaceMiniProgramScreen'),
              popMiniProgramScreen: (_, _) async => _ok('popMiniProgramScreen'),
              popToMiniProgramRoot: (_, _) async => _ok('popToMiniProgramRoot'),
              popToMiniProgramScreen: (_, _) async =>
                  _ok('popToMiniProgramScreen'),
              child: Builder(
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
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _mpAppBarTests() {
  group('app bars', () {
    test('validator accepts custom content and all styling', () {
      const MpScreenValidator().validate(
        _appBarScreen(
          Mp.appBar(
            title: Mp.row(children: [Mp.icon('home'), Mp.text('Shop')]),
            leading: Mp.icon('menu'),
            actions: [
              Mp.iconButton(
                'search',
                semanticLabel: 'Search',
                action: Mp.navigation.openScreen('search'),
              ),
            ],
            centerTitle: true,
            height: 80,
            leadingWidth: 72,
            paddingHorizontal: 16,
            spacing: 4,
            elevation: 3,
            backgroundColor: '#123456',
            foregroundColor: '#FFFFFF',
            shadowColor: '#80000000',
          ),
        ),
        expectedScreenId: 'coupon_home',
      );
    });

    test('validator rejects invalid values, metadata and unknown fields', () {
      for (final change in <Map<String, dynamic>>[
        {'height': 47},
        {'height': 161},
        {'height': double.nan},
        {'height': double.infinity},
        {'height': '{{state.height}}'},
        {'leadingWidth': -1},
        {'leadingWidth': 257},
        {'paddingHorizontal': -1},
        {'paddingHorizontal': 49},
        {'spacing': -1},
        {'spacing': 25},
        {'elevation': -1},
        {'elevation': 25},
        {'centerTitle': null},
        {'centerTitle': 'true'},
        {'hasLeading': 1},
        {'actionCount': -1},
        {'actionCount': 1},
        {'actionCount': 5},
        {'actionCount': 0.5},
        {'backgroundColor': 'blue'},
        {'foregroundColor': '{{state.color}}'},
        {'shadowColor': null},
        {'automaticallyImplyLeading': true},
        {'primary': true},
        {'onTap': 'callback'},
      ]) {
        final json = _appBarScreen(Mp.appBar(title: Mp.text('Shop')));
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
      for (final missing in [
        'hasLeading',
        'actionCount',
        'centerTitle',
        'height',
        'leadingWidth',
        'paddingHorizontal',
        'spacing',
        'elevation',
      ]) {
        final json = _appBarScreen(Mp.appBar(title: Mp.text('Shop')));
        (json['root']['props'] as Map).remove(missing);
        expect(
          () => const MpScreenValidator().validate(
            json,
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
          reason: missing,
        );
      }
      for (final invalidChildren in <List<dynamic>>[
        [],
        [Mp.text('One').toJson(), Mp.text('Two').toJson()],
      ]) {
        final json = _appBarScreen(Mp.appBar(title: Mp.text('Shop')));
        json['root']['children'] = invalidChildren;
        expect(
          () => const MpScreenValidator().validate(
            json,
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
      final legacy = _appBarScreen(Mp.appBar(title: Mp.text('Shop')));
      legacy['root']['type'] = 'topBar';
      expect(
        () => const MpScreenValidator().validate(
          legacy,
          expectedScreenId: 'coupon_home',
        ),
        throwsA(isA<MiniProgramRenderException>()),
      );
    });

    testWidgets('renders a sized Material app bar with explicit styling', (
      tester,
    ) async {
      await _pumpAppBar(
        tester,
        Mp.page(
          child: Mp.column(
            children: [
              Mp.appBar(
                title: Mp.text('Shop'),
                leading: Mp.icon('home'),
                centerTitle: true,
                height: 80,
                leadingWidth: 72,
                elevation: 3,
                paddingHorizontal: 16,
                spacing: 4,
                backgroundColor: '#123456',
                foregroundColor: '#FFFFFF',
                shadowColor: '#80000000',
              ),
              Mp.expanded(child: Mp.text('Body')),
            ],
          ),
        ),
      );
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.toolbarHeight, 80);
      expect(tester.getSize(find.byType(AppBar)).height, 80);
      expect(bar.centerTitle, isTrue);
      expect(bar.leadingWidth, 88);
      expect(bar.titleSpacing, 4);
      expect(bar.elevation, 3);
      expect(bar.backgroundColor, const Color(0xFF123456));
      expect(bar.foregroundColor, Colors.white);
      expect(bar.shadowColor, const Color(0x80000000));
      expect(bar.primary, isFalse);
      expect(bar.automaticallyImplyLeading, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'foreground and text defaults are scoped and child styles win',
      (tester) async {
        final theme = ThemeData(
          appBarTheme: const AppBarThemeData(
            foregroundColor: Color(0xFFABCDEF),
            backgroundColor: Color(0xFF123456),
            titleTextStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        await _pumpAppBar(
          tester,
          Mp.page(
            child: Mp.column(
              children: [
                Mp.appBar(
                  title: Mp.text('Inherited title'),
                  leading: Mp.icon('menu', semanticLabel: 'Inherited menu'),
                  actions: [
                    Mp.iconButton(
                      'search',
                      semanticLabel: 'Inherited action',
                      action: Mp.toast(message: 'Search'),
                    ),
                    Mp.iconButton(
                      'edit',
                      semanticLabel: 'Custom action',
                      action: Mp.toast(message: 'Edit'),
                      color: '#FF0000',
                    ),
                  ],
                ),
                Mp.appBar(
                  foregroundColor: '#FFFFFF',
                  title: Mp.text(
                    'Custom title',
                    color: '#00FF00',
                    size: 18,
                    weight: 'bold',
                  ),
                  leading: Mp.icon(
                    'home',
                    color: '#FF0000',
                    semanticLabel: 'Custom home',
                  ),
                ),
                Mp.text('Outside title'),
                Mp.iconButton(
                  'add',
                  semanticLabel: 'Outside action',
                  action: Mp.toast(message: 'Add'),
                ),
              ],
            ),
          ),
          theme: theme,
        );
        final title = tester.widget<Text>(find.text('Inherited title'));
        expect(title.style!.color, const Color(0xFFABCDEF));
        expect(title.style!.fontSize, 22);
        expect(title.style!.fontWeight, FontWeight.w600);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.search)).color,
          const Color(0xFFABCDEF),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.edit)).color,
          const Color(0xFFFF0000),
        );
        expect(
          tester
              .widget<Icon>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is Icon &&
                      widget.semanticLabel == 'Inherited menu',
                ),
              )
              .color,
          const Color(0xFFABCDEF),
        );
        expect(
          tester.widget<Text>(find.text('Custom title')).style!.color,
          const Color(0xFF00FF00),
        );
        expect(
          tester.widget<Text>(find.text('Custom title')).style!.fontSize,
          18,
        );
        expect(
          tester.widget<Text>(find.text('Custom title')).style!.fontWeight,
          FontWeight.bold,
        );
        expect(
          tester
              .widget<Icon>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is Icon && widget.semanticLabel == 'Custom home',
                ),
              )
              .color,
          const Color(0xFFFF0000),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.add)).color,
          const Color(0xFF9CA3AF),
        );
        expect(
          tester.widget<Text>(find.text('Outside title')).style!.color,
          const Color(0xFF263238),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('leading and actions use existing navigation and live state', (
      tester,
    ) async {
      final backend = MiniProgramBackendStore();
      final state = MpStateManager();
      addTearDown(backend.dispose);
      addTearDown(state.dispose);
      state.set('toolbar.count', 0);
      final opened = <String>[];
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          stateManager: state,
          openMiniProgramScreen: (id, _) async {
            opened.add(id.screenId);
            return _ok('openMiniProgramScreen');
          },
          screenJson: _appBarScreen(
            Mp.page(
              child: Mp.column(
                children: [
                  Mp.appBar(
                    title: Mp.stateBuilder(
                      keys: ['toolbar.count'],
                      child: Mp.text('Count {{state.toolbar.count}}'),
                    ),
                    leading: Mp.iconButton(
                      'menu',
                      semanticLabel: 'Open menu',
                      action: Mp.navigation.openScreen('menu'),
                    ),
                    actions: [
                      Mp.iconButton(
                        'add',
                        semanticLabel: 'Increment',
                        action: Mp.state.increment('toolbar.count'),
                      ),
                      Mp.iconButton(
                        'search',
                        semanticLabel: 'Open search',
                        action: Mp.navigation.openScreen('search'),
                      ),
                    ],
                  ),
                  Mp.expanded(child: Mp.text('Body')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Increment'));
      await tester.pumpAndSettle();
      expect(find.text('Count 1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Open menu'));
      await tester.tap(find.bySemanticsLabel('Open search'));
      await tester.pumpAndSettle();
      expect(opened, ['menu', 'search']);
      expect(state.get('toolbar.count'), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('body text input stays usable after a toolbar state action', (
      tester,
    ) async {
      final state = MpStateManager()..set('toolbar.count', 0);
      addTearDown(state.dispose);
      await _pumpAppBar(
        tester,
        Mp.page(
          child: Mp.column(
            children: [
              Mp.appBar(
                title: Mp.stateBuilder(
                  keys: ['toolbar.count'],
                  child: Mp.text('Count {{state.toolbar.count}}'),
                ),
                actions: [
                  Mp.iconButton(
                    'add',
                    semanticLabel: 'Add booking',
                    action: Mp.state.increment('toolbar.count'),
                  ),
                ],
              ),
              Mp.expanded(
                child: Mp.scrollView(
                  child: Mp.stateTextField(
                    stateKey: 'booking.draft',
                    label: 'Booking details',
                  ),
                ),
              ),
            ],
          ),
        ),
        stateManager: state,
      );
      await tester.tap(find.bySemanticsLabel('Add booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
      tester.testTextInput.enterText('booking123');
      await tester.pump();
      expect(state.get('booking.draft'), 'booking123');
      expect(find.text('Count 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('narrow toolbar keeps large text and four actions usable', (
      tester,
    ) async {
      final state = MpStateManager();
      addTearDown(state.dispose);
      await tester.binding.setSurfaceSize(const Size(240, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpAppBar(
        tester,
        Mp.page(
          child: Mp.column(
            children: [
              Mp.appBar(
                title: Mp.text('A very long shop title'),
                centerTitle: true,
                leading: Mp.icon('menu'),
                actions: [
                  for (var index = 0; index < 4; index++)
                    Mp.button(
                      label: 'Action $index',
                      height: 48,
                      action: Mp.state.set('toolbar.pressed', index),
                    ),
                ],
              ),
              Mp.expanded(child: Mp.text('Body')),
            ],
          ),
        ),
        scale: 2,
        stateManager: state,
      );
      final horizontal = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontal, findsOneWidget);
      await tester.drag(horizontal, const Offset(-1200, 0));
      await tester.pumpAndSettle();
      final visible = tester
          .getRect(find.text('Action 3'))
          .intersect(tester.getRect(horizontal));
      expect(visible.isEmpty, isFalse);
      await tester.tapAt(visible.center);
      await tester.pump();
      expect(state.get('toolbar.pressed'), 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'app bar stays fixed while body scrolls without extra safe padding',
      (tester) async {
        await _pumpAppBar(
          tester,
          Mp.page(
            child: Mp.column(
              children: [
                Mp.appBar(title: Mp.text('Fixed header')),
                Mp.expanded(
                  child: Mp.scrollView(
                    child: Mp.column(
                      children: [
                        for (var index = 0; index < 40; index++)
                          Mp.container(
                            height: 60,
                            child: Mp.text('Item $index'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final before = tester.getRect(find.byType(AppBar));
        final vertical = find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.vertical,
        );
        expect(vertical, findsOneWidget);
        await tester.drag(vertical, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(AppBar)), before);
        expect(before.height, 64);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'no automatic host back or drawer controls; system Back still works',
      (tester) async {
        final json = _appBarScreen(
          Mp.page(
            child: Mp.column(
              children: [
                Mp.appBar(title: Mp.text('Own toolbar')),
                Mp.expanded(child: Mp.text('Mini-program body')),
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        drawer: const Drawer(),
                        endDrawer: const Drawer(),
                        body: const MpScreenRenderer().render(
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
                  ),
                  child: const Text('Host screen'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Host screen'));
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsNothing);
        expect(find.byType(DrawerButton), findsNothing);
        expect(find.byType(EndDrawerButton), findsNothing);
        expect(find.text('Own toolbar'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Host screen'), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('centered title and leading respect RTL layout', (
      tester,
    ) async {
      await _pumpAppBar(
        tester,
        Mp.page(
          child: Mp.column(
            children: [
              Mp.appBar(
                title: Mp.text('Centered'),
                centerTitle: true,
                leading: Mp.icon('menu', semanticLabel: 'RTL menu'),
              ),
              Mp.expanded(child: Mp.text('Body')),
            ],
          ),
        ),
        direction: TextDirection.rtl,
      );
      final bar = tester.getRect(find.byType(AppBar));
      expect(
        tester.getCenter(find.text('Centered')).dx,
        closeTo(bar.center.dx, 1),
      );
      expect(
        tester
            .getCenter(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Icon && widget.semanticLabel == 'RTL menu',
              ),
            )
            .dx,
        greaterThan(bar.center.dx),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
