part of '../mp_screen_renderer_test.dart';

void _mpScreenRendererTests() {
  group('MpScreenRenderer', () {
    testWidgets('renders basic Mp nodes with Flutter widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return const MpScreenRenderer().render(
                MiniProgramRenderRequest(
                  context: context,
                  manifest: _mpManifest,
                  screenId: 'coupon_home',
                  screenJson: _fullBasicScreen,
                  logger: DebugPrintSdkLogger(),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Publisher account'), findsOneWidget);
      expect(find.text('Sign in to continue'), findsOneWidget);
      expect(find.text('Inside card'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders generic activity icons', (tester) async {
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.row(
              children: <MpNode>[
                for (final name in <String>[
                  'brain',
                  'trophy',
                  'timer',
                  'close',
                  'refresh',
                  'bolt',
                ])
                  Mp.icon(name, semanticLabel: '$name icon'),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => const MpScreenRenderer().render(
              MiniProgramRenderRequest(
                context: context,
                manifest: _mpManifest,
                screenId: 'coupon_home',
                screenJson: screenJson,
                logger: DebugPrintSdkLogger(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Icon), findsNWidgets(6));
    });

    testWidgets('condition reacts to bound state without stateBuilder', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager()..set('screen.ready', false);
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.condition(
              condition: '{{state.screen.ready}}',
              whenTrue: Mp.text('Ready content'),
              whenFalse: Mp.text('Waiting content'),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      expect(find.text('Waiting content'), findsOneWidget);
      expect(find.text('Ready content'), findsNothing);

      state.set('screen.ready', true);
      await tester.pump();
      expect(find.text('Ready content'), findsOneWidget);
      expect(find.text('Waiting content'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('ifElse resolves bindings at its sequence step', (
      tester,
    ) async {
      final state = MpStateManager()..set('flow.allowed', false);
      final branchAction = Mp.action.ifElse(
        condition: '{{state.flow.allowed}}',
        thenAction: Mp.state.set('flow.status', 'accepted'),
        elseAction: Mp.state.set('flow.status', 'rejected'),
      );
      final action = Mp.action.sequence(<MpAction>[
        Mp.state.set('flow.allowed', true),
        branchAction,
      ]);

      final result = await _runMpAction(
        tester,
        _jsonMap(action.toJson()),
        stateManager: state,
      );

      expect(result, isA<HostActionResult>());
      expect((result! as HostActionResult).isSuccess, isTrue);
      expect(state.get<String>('flow.status'), 'accepted');

      state.set('flow.allowed', false);
      final elseResult = await _runMpAction(
        tester,
        _jsonMap(branchAction.toJson()),
        stateManager: state,
      );
      expect((elseResult! as HostActionResult).isSuccess, isTrue);
      expect(state.get<String>('flow.status'), 'rejected');
      state.dispose();
    });

    testWidgets('ifElse fails clearly for a non-boolean bound value', (
      tester,
    ) async {
      final state = MpStateManager()..set('flow.allowed', 'yes');
      final result = await _runMpAction(
        tester,
        _jsonMap(
          Mp.action
              .ifElse(
                condition: '{{state.flow.allowed}}',
                thenAction: Mp.state.set('flow.status', 'accepted'),
                elseAction: Mp.state.set('flow.status', 'rejected'),
              )
              .toJson(),
        ),
        stateManager: state,
      );

      expect(result, isA<HostActionResult>());
      final failure = result! as HostActionResult;
      expect(failure.isSuccess, isFalse);
      expect(failure.errorCode, MiniProgramErrorCodes.conditionInvalidValue);
      expect(state.contains('flow.status'), isFalse);
      state.dispose();
    });

    testWidgets('scoped action calls reuse definitions and resolve each step', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager()..set('flow.count', 0);
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.actionScope(
              actions: <String, MpAction>{
                'incrementCount': Mp.action.sequence(<MpAction>[
                  Mp.state.increment('flow.count'),
                  Mp.state.set('flow.snapshot', '{{state.flow.count}}'),
                ]),
              },
              child: Mp.stateBuilder(
                keys: const <String>['flow.count'],
                child: Mp.column(
                  children: <MpNode>[
                    Mp.text('Count {{state.flow.count}}'),
                    Mp.button(
                      label: 'Increment',
                      action: Mp.action.call('incrementCount'),
                    ),
                  ],
                ),
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count 1'), findsOneWidget);
      expect(state.get<num>('flow.snapshot'), 1);
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('recursive scoped calls fail with a stable initialize error', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.actionScope(
              actions: <String, MpAction>{
                'recursiveCall': Mp.action.call('recursiveCall'),
              },
              child: Mp.initialize(
                actions: <MpAction>[Mp.action.call('recursiveCall')],
                errorState: 'screen.error',
                error: Mp.text('Action failed'),
                child: Mp.text('Ready'),
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Action failed'), findsOneWidget);
      expect(
        state.get<Map<String, dynamic>>('screen.error')?['code'],
        MiniProgramErrorCodes.actionCallLimitExceeded,
      );
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('missing scoped calls fail with a stable initialize error', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.actionScope(
              actions: <String, MpAction>{
                'availableAction': Mp.state.set('screen.ready', true),
              },
              child: Mp.initialize(
                actions: <MpAction>[Mp.action.call('missingAction')],
                errorState: 'screen.error',
                error: Mp.text('Action failed'),
                child: Mp.text('Ready'),
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        state.get<Map<String, dynamic>>('screen.error')?['code'],
        MiniProgramErrorCodes.actionNotFound,
      );
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('countdown writes seconds and completes exactly once', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.stateBuilder(
              keys: const <String>['timer.remaining'],
              child: Mp.timer.countdown(
                duration: const Duration(seconds: 2),
                remainingState: 'timer.remaining',
                onComplete: Mp.state.increment('timer.completions'),
                child: Mp.text('Remaining: {{state.timer.remaining}}'),
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pump();
      expect(find.text('Remaining: 2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Remaining: 1'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Remaining: 0'), findsOneWidget);
      expect(state.get<num>('timer.completions'), 1);

      await tester.pump(const Duration(seconds: 3));
      expect(state.get<num>('timer.completions'), 1);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('countdown pauses, restarts by token, and cancels on dispose', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager()
        ..set('timer.running', true)
        ..set('timer.restart_id', 1);
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.timer.countdown(
              duration: const Duration(seconds: 2),
              running: '{{state.timer.running}}',
              restartToken: '{{state.timer.restart_id}}',
              remainingState: 'timer.remaining',
              onComplete: Mp.state.increment('timer.completions'),
              child: Mp.text('Remaining: {{state.timer.remaining}}'),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(state.get<int>('timer.remaining'), 1);

      state.set('timer.running', false);
      await tester.pump(const Duration(seconds: 3));
      expect(state.contains('timer.completions'), isFalse);

      state.set('timer.restart_id', 2);
      await tester.pump();
      expect(state.get<int>('timer.remaining'), 2);
      state.set('timer.running', true);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(state.contains('timer.completions'), isFalse);

      state.set('timer.restart_id', 3);
      await tester.pump();
      expect(state.get<int>('timer.remaining'), 2);
      await tester.pump(const Duration(seconds: 1));
      expect(state.contains('timer.completions'), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(state.contains('timer.completions'), isFalse);
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('renders lightweight text styles and UTF-8 text safely', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      const bangla = 'বাংলা লেখা এখানে';
      const arabic = 'مرحبا';
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.text(
                  'Styled body',
                  size: 18,
                  color: '#112233',
                  weight: 'semibold',
                  align: 'center',
                  maxLines: 2,
                  overflow: 'ellipsis',
                  softWrap: false,
                  lineHeight: 1.4,
                  textDirection: 'ltr',
                  locale: 'en-US',
                  variant: 'body_large',
                ),
                Mp.heading(
                  'Styled heading',
                  level: 3,
                  color: '#FF111827',
                  align: 'right',
                  overflow: 'fade',
                  textDirection: 'rtl',
                ),
                Mp.text(bangla, locale: 'bn'),
                Mp.text(arabic, textDirection: 'auto'),
                Mp.text('Plain auto', textDirection: 'auto'),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      final styledBody = tester.widget<Text>(find.text('Styled body'));
      expect(styledBody.maxLines, 2);
      expect(styledBody.overflow, TextOverflow.ellipsis);
      expect(styledBody.softWrap, isFalse);
      expect(styledBody.textAlign, TextAlign.center);
      expect(styledBody.textDirection, TextDirection.ltr);
      expect(styledBody.locale, const Locale('en', 'US'));
      expect(styledBody.style?.fontSize, 18);
      expect(styledBody.style?.height, 1.4);
      expect(styledBody.style?.fontWeight, FontWeight.w600);
      expect(styledBody.style?.color, const Color(0xFF112233));

      final styledHeading = tester.widget<Text>(find.text('Styled heading'));
      expect(styledHeading.textAlign, TextAlign.right);
      expect(styledHeading.textDirection, TextDirection.rtl);
      expect(styledHeading.overflow, TextOverflow.fade);
      expect(styledHeading.style?.fontSize, 20);
      expect(styledHeading.style?.fontWeight, FontWeight.w700);
      expect(styledHeading.style?.color, const Color(0xFF111827));

      final banglaText = tester.widget<Text>(find.text(bangla));
      expect(banglaText.locale, const Locale('bn'));
      expect(banglaText.textDirection, TextDirection.ltr);

      final arabicText = tester.widget<Text>(find.text(arabic));
      expect(arabicText.textDirection, TextDirection.rtl);

      final plainAutoText = tester.widget<Text>(find.text('Plain auto'));
      expect(plainAutoText.textDirection, TextDirection.ltr);

      backendStore.dispose();
    });

    testWidgets('renders lightweight theme typography variants', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.theme(
                  colors: const <String, String>{'text': '#123456'},
                  typography: const <String, Map<String, Object?>>{
                    'title': <String, Object?>{
                      'size': 21,
                      'weight': 'bold',
                      'lineHeight': 1.2,
                      'color': 'text',
                    },
                    'ghost': <String, Object?>{
                      'size': 13,
                      'color': 'missingColor',
                    },
                  },
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.text('Theme title', variant: 'title'),
                      Mp.text(
                        'Direct wins',
                        variant: 'title',
                        size: 30,
                        color: '#FF0000',
                        weight: 'medium',
                        lineHeight: 1.7,
                      ),
                      Mp.text('Missing variant', variant: 'missing'),
                      Mp.text('Missing token', variant: 'ghost'),
                    ],
                  ),
                ),
                Mp.text('Outside title', variant: 'title'),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      final themedTitle = tester.widget<Text>(find.text('Theme title'));
      expect(themedTitle.style?.fontSize, 21);
      expect(themedTitle.style?.fontWeight, FontWeight.w700);
      expect(themedTitle.style?.height, 1.2);
      expect(themedTitle.style?.color, const Color(0xFF123456));

      final directWins = tester.widget<Text>(find.text('Direct wins'));
      expect(directWins.style?.fontSize, 30);
      expect(directWins.style?.fontWeight, FontWeight.w500);
      expect(directWins.style?.height, 1.7);
      expect(directWins.style?.color, const Color(0xFFFF0000));

      final missingVariant = tester.widget<Text>(find.text('Missing variant'));
      expect(missingVariant.style?.fontSize, 15);
      expect(missingVariant.style?.color, const Color(0xFF263238));

      final missingToken = tester.widget<Text>(find.text('Missing token'));
      expect(missingToken.style?.fontSize, 13);
      expect(missingToken.style?.color, const Color(0xFF263238));

      final outsideTitle = tester.widget<Text>(find.text('Outside title'));
      expect(outsideTitle.style?.fontSize, 15);
      expect(outsideTitle.style?.color, const Color(0xFF263238));

      backendStore.dispose();
    });

    testWidgets('merges nested lightweight themes', (tester) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.theme(
              colors: const <String, String>{'text': '#111111'},
              typography: const <String, Map<String, Object?>>{
                'title': <String, Object?>{
                  'size': 20,
                  'weight': 'bold',
                  'color': 'text',
                },
              },
              child: Mp.column(
                children: <MpNode>[
                  Mp.text('Parent title', variant: 'title'),
                  Mp.theme(
                    colors: const <String, String>{'text': '#222222'},
                    typography: const <String, Map<String, Object?>>{
                      'title': <String, Object?>{
                        'size': 25,
                        'weight': 'medium',
                        'color': 'text',
                      },
                    },
                    child: Mp.text('Nested title', variant: 'title'),
                  ),
                ],
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      final parentTitle = tester.widget<Text>(find.text('Parent title'));
      expect(parentTitle.style?.fontSize, 20);
      expect(parentTitle.style?.fontWeight, FontWeight.w700);
      expect(parentTitle.style?.color, const Color(0xFF111111));

      final nestedTitle = tester.widget<Text>(find.text('Nested title'));
      expect(nestedTitle.style?.fontSize, 25);
      expect(nestedTitle.style?.fontWeight, FontWeight.w500);
      expect(nestedTitle.style?.color, const Color(0xFF222222));

      backendStore.dispose();
    });

    testWidgets('renders async image sources and placeholders', (tester) async {
      final backendStore = MiniProgramBackendStore();
      const base64Image =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.image(
                  src: 'https://example.com/a.png',
                  headers: const <String, String>{'x-image': 'product'},
                  semanticLabel: 'Network image',
                  width: 120,
                  height: 80,
                  fit: MpImageFit.fitHeight,
                  placeholder: Mp.text('Loading network image'),
                ),
                Mp.image(
                  src: 'assets/logo.png',
                  fit: MpImageFit.contain,
                  semanticLabel: 'Asset image',
                ),
                Mp.image(
                  src: base64Image,
                  fit: MpImageFit.none,
                  semanticLabel: 'Base64 image',
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Loading network image'), findsOneWidget);

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final network = images.firstWhere((image) => image.image is NetworkImage);
      final networkProvider = network.image as NetworkImage;
      expect(networkProvider.url, 'https://example.com/a.png');
      expect(networkProvider.headers, <String, String>{'x-image': 'product'});
      expect(network.fit, BoxFit.fitHeight);
      expect(network.semanticLabel, 'Network image');

      final asset = images.firstWhere((image) => image.image is AssetImage);
      final assetProvider = asset.image as AssetImage;
      expect(assetProvider.assetName, 'assets/logo.png');
      expect(asset.fit, BoxFit.contain);
      expect(asset.semanticLabel, 'Asset image');

      final memory = images.firstWhere((image) => image.image is MemoryImage);
      expect(memory.fit, BoxFit.none);
      expect(memory.semanticLabel, 'Base64 image');

      backendStore.dispose();
    });

    testWidgets('renders async image error fallbacks in priority order', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.image(
                  src: 'assets/missing-error.png',
                  source: MpImageSource.asset,
                  error: Mp.text('Image failed'),
                ),
                Mp.image(
                  src: 'assets/missing-semantic.png',
                  source: MpImageSource.asset,
                  semanticLabel: 'Semantic fallback',
                ),
                Mp.image(
                  src: 'assets/missing-alt.png',
                  source: MpImageSource.asset,
                  alt: 'Legacy alt fallback',
                ),
                Mp.image(
                  src: 'assets/missing-default.png',
                  source: MpImageSource.asset,
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );
      await tester.pumpAndSettle();

      expect(find.text('Image failed'), findsOneWidget);
      expect(find.text('Semantic fallback'), findsOneWidget);
      expect(find.text('Legacy alt fallback'), findsOneWidget);
      expect(find.text('Image unavailable'), findsOneWidget);

      backendStore.dispose();
    });

    testWidgets('renders theme-aware skeleton components', (tester) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.theme(
                  colors: const <String, String>{
                    'placeholder': '#222222',
                    'skeleton': '#111111',
                  },
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.skeleton.box(
                        width: 24,
                        height: 24,
                        colorToken: 'placeholder',
                      ),
                      Mp.skeleton.box(
                        width: 26,
                        height: 26,
                        colorToken: 'missingToken',
                      ),
                      Mp.skeleton.text(width: 120),
                      Mp.skeleton.circle(size: 32),
                      Mp.skeleton.card(width: 160),
                      Mp.skeleton.list(count: 2, width: 140, spacing: 3),
                      Mp.image(
                        src: 'https://example.com/a.png',
                        placeholder: Mp.skeleton.box(
                          width: 30,
                          height: 30,
                          colorToken: 'placeholder',
                        ),
                      ),
                    ],
                  ),
                ),
                Mp.skeleton.box(width: 28, height: 28),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      final decorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(
        decorations.where(
          (decoration) => decoration.color == const Color(0xFF222222),
        ),
        hasLength(greaterThanOrEqualTo(2)),
      );
      expect(
        decorations.any(
          (decoration) => decoration.color == const Color(0xFF111111),
        ),
        isTrue,
      );
      expect(
        decorations.any(
          (decoration) => decoration.color == const Color(0xFFE5E7EB),
        ),
        isTrue,
      );
      expect(
        decorations.any(
          (decoration) =>
              decoration.shape == BoxShape.circle &&
              decoration.color == const Color(0xFF111111),
        ),
        isTrue,
      );
      expect(tester.widgetList<ListView>(find.byType(ListView)), isEmpty);
      expect(
        tester
            .widgetList<Column>(find.byType(Column))
            .any(
              (column) =>
                  column.children.length == 3 &&
                  column.children.whereType<SizedBox>().any(
                    (box) => box.height == 3,
                  ),
            ),
        isTrue,
      );

      backendStore.dispose();
    });

    testWidgets('renders theme-aware component polish', (tester) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.theme(
              colors: const <String, String>{
                'primary': '#880000',
                'primaryHover': '#990000',
                'primaryPressed': '#660000',
                'onPrimary': '#FFFFFF',
                'surface': '#FAFAFA',
                'surfaceMuted': '#F5EEEE',
                'border': '#008800',
                'text': '#101010',
                'textMuted': '#606060',
                'icon': '#303030',
                'info': '#000088',
                'infoBg': '#EEEEFF',
                'infoBorder': '#CCCCFF',
                'success': '#008800',
                'successBg': '#EEFFEE',
                'successBorder': '#CCFFCC',
                'warning': '#884400',
                'warningBg': '#FFF4DD',
                'warningBorder': '#FFD699',
              },
              typography: const <String, Map<String, Object?>>{
                'button': <String, Object?>{
                  'size': 16,
                  'weight': 'bold',
                  'lineHeight': 1.1,
                },
                'listTileTitle': <String, Object?>{
                  'size': 18,
                  'weight': 'bold',
                },
                'listTileSubtitle': <String, Object?>{
                  'size': 12,
                  'color': 'textMuted',
                },
                'chip': <String, Object?>{'size': 14, 'weight': 'medium'},
                'badge': <String, Object?>{'size': 11, 'weight': 'regular'},
                'alertTitle': <String, Object?>{'size': 15, 'weight': 'bold'},
                'alertMessage': <String, Object?>{
                  'size': 12,
                  'lineHeight': 1.4,
                },
              },
              child: Mp.column(
                children: <MpNode>[
                  Mp.card(child: Mp.text('Themed card body')),
                  Mp.primaryButton(
                    label: 'Primary themed',
                    action: Mp.state.set('theme.primary', true),
                  ),
                  Mp.secondaryButton(
                    label: 'Secondary themed',
                    action: Mp.state.set('theme.secondary', true),
                  ),
                  Mp.listTile(
                    title: 'Themed tile',
                    subtitle: 'Tile subtitle',
                    leadingIcon: 'person',
                    badge: 'Tile badge',
                    action: Mp.state.set('theme.tile', true),
                  ),
                  Mp.chip(
                    label: 'Chip themed',
                    tone: 'success',
                    leadingIcon: 'star',
                  ),
                  Mp.badge(label: 'Badge themed', tone: 'warning'),
                  Mp.alert(
                    title: 'Alert themed',
                    message: 'Alert message',
                    tone: 'info',
                  ),
                  Mp.divider(),
                  Mp.icon('settings', semanticLabel: 'Theme icon'),
                ],
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      final primaryButton = tester.widget<Text>(find.text('Primary themed'));
      expect(primaryButton.style?.color, const Color(0xFFFFFFFF));
      expect(primaryButton.style?.fontSize, 16);
      expect(primaryButton.style?.fontWeight, FontWeight.w700);
      expect(primaryButton.style?.height, 1.1);

      final secondaryButton = tester.widget<Text>(
        find.text('Secondary themed'),
      );
      expect(secondaryButton.style?.color, const Color(0xFF880000));
      expect(secondaryButton.style?.fontSize, 16);

      final tileTitle = tester.widget<Text>(find.text('Themed tile'));
      expect(tileTitle.style?.color, const Color(0xFF101010));
      expect(tileTitle.style?.fontSize, 18);
      expect(tileTitle.style?.fontWeight, FontWeight.w700);

      final tileSubtitle = tester.widget<Text>(find.text('Tile subtitle'));
      expect(tileSubtitle.style?.color, const Color(0xFF606060));
      expect(tileSubtitle.style?.fontSize, 12);

      final tileBadge = tester.widget<Text>(find.text('Tile badge'));
      expect(tileBadge.style?.color, const Color(0xFF000088));
      expect(tileBadge.style?.fontSize, 11);

      final chip = tester.widget<Text>(find.text('Chip themed'));
      expect(chip.style?.color, const Color(0xFF008800));
      expect(chip.style?.fontSize, 14);
      expect(chip.style?.fontWeight, FontWeight.w500);

      final badge = tester.widget<Text>(find.text('Badge themed'));
      expect(badge.style?.color, const Color(0xFF884400));
      expect(badge.style?.fontSize, 11);
      expect(badge.style?.fontWeight, FontWeight.w400);

      final alertTitle = tester.widget<Text>(find.text('Alert themed'));
      expect(alertTitle.style?.color, const Color(0xFF000088));
      expect(alertTitle.style?.fontSize, 15);

      final alertMessage = tester.widget<Text>(find.text('Alert message'));
      expect(alertMessage.style?.color, const Color(0xFF000088));
      expect(alertMessage.style?.fontSize, 12);
      expect(alertMessage.style?.height, 1.4);

      final themedDecorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();
      expect(
        themedDecorations.any(
          (decoration) => decoration.color == const Color(0xFFFAFAFA),
        ),
        isTrue,
      );
      expect(
        themedDecorations.any(
          (decoration) =>
              decoration.color == const Color(0xFFEEEEFF) &&
              decoration.border is Border &&
              (decoration.border! as Border).top.color ==
                  const Color(0xFFCCCCFF),
        ),
        isTrue,
      );

      final icons = tester.widgetList<Icon>(find.byType(Icon));
      expect(
        icons.any((icon) => icon.color == const Color(0xFF303030)),
        isTrue,
      );

      backendStore.dispose();
    });

    testWidgets('renders core design widgets and dispatches row actions', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.stateBuilder(
                  keys: const <String>['selected.profile', 'filter.featured'],
                  child: Mp.text(
                    'Profile: {{state.selected.profile}} '
                    'Featured: {{state.filter.featured}}',
                  ),
                ),
                Mp.padding(all: 12, child: Mp.text('Padded')),
                Mp.container(
                  paddingAll: 8,
                  backgroundColor: '#FFFFFFFF',
                  borderColor: '#E5E7EB',
                  borderWidth: 1,
                  borderRadius: 8,
                  child: Mp.text('Box'),
                ),
                Mp.scrollView(
                  paddingVertical: 4,
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.text('Scrollable item'),
                      Mp.text('Scrollable item 2'),
                    ],
                  ),
                ),
                Mp.divider(thickness: 2, spacing: 10),
                Mp.icon('settings', semanticLabel: 'Settings'),
                Mp.listTile(
                  title: 'Profile',
                  subtitle: 'Manage account',
                  leadingIcon: 'person',
                  badge: 'New',
                  action: Mp.state.set('selected.profile', true),
                ),
                Mp.chip(
                  label: 'Featured',
                  tone: 'success',
                  leadingIcon: 'star',
                  action: Mp.state.set('filter.featured', true),
                ),
                Mp.badge(label: 'Beta', tone: 'warning'),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );

      expect(find.text('Padded'), findsOneWidget);
      expect(find.text('Box'), findsOneWidget);
      expect(find.text('Scrollable item'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Manage account'), findsOneWidget);
      expect(find.text('Featured'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.byType(Icon), findsWidgets);
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 2,
        ),
        findsWidgets,
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(find.text('Profile: true Featured: '), findsOneWidget);

      await tester.tap(find.text('Featured'));
      await tester.pump();
      expect(find.text('Profile: true Featured: true'), findsOneWidget);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('does not clamp unbounded scrollView content height', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.scrollView(
              child: Mp.column(
                children: <MpNode>[
                  Mp.sizedBox(height: 500),
                  Mp.text('Below old clamp'),
                ],
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Below old clamp'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox && widget.constraints.maxHeight == 420,
        ),
        findsNothing,
      );

      backendStore.dispose();
    });

    testWidgets('renders future display and layout widgets with actions', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.stateBuilder(
                  keys: const <String>['empty.retry', 'section.more'],
                  child: Mp.text(
                    'Retry: {{state.empty.retry}} '
                    'More: {{state.section.more}}',
                  ),
                ),
                Mp.alert(
                  title: 'Network notice',
                  message: 'Some data may be delayed',
                  tone: 'warning',
                ),
                Mp.row(
                  children: <MpNode>[
                    Mp.avatar(initials: 'MH', semanticLabel: 'Mehedi'),
                    Mp.avatar(icon: 'person', semanticLabel: 'Profile'),
                  ],
                ),
                Mp.grid(
                  columns: 2,
                  spacing: 8,
                  children: <MpNode>[
                    Mp.container(paddingAll: 8, child: Mp.text('Tile one')),
                    Mp.container(paddingAll: 8, child: Mp.text('Tile two')),
                  ],
                ),
                Mp.wrap(
                  children: <MpNode>[
                    Mp.chip(label: 'Alpha'),
                    Mp.badge(label: 'Ready'),
                  ],
                ),
                Mp.progress(
                  value: 3,
                  max: 6,
                  label: 'Setup progress',
                  tone: 'success',
                ),
                Mp.emptyState(
                  title: 'Nothing here',
                  message: 'Try refreshing this view',
                  icon: 'search',
                  actionLabel: 'Retry empty',
                  action: Mp.state.set('empty.retry', true),
                ),
                Mp.section(
                  title: 'Latest',
                  subtitle: 'Fresh picks',
                  actionLabel: 'Open all',
                  action: Mp.state.set('section.more', true),
                  child: Mp.text('Section body'),
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );

      expect(find.text('Network notice'), findsOneWidget);
      expect(find.text('Some data may be delayed'), findsOneWidget);
      expect(find.text('MH'), findsOneWidget);
      expect(find.text('Tile one'), findsOneWidget);
      expect(find.text('Tile two'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Setup progress'), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Section body'), findsOneWidget);
      expect(find.byType(Wrap), findsAtLeastNWidgets(2));
      expect(find.byType(FractionallySizedBox), findsWidgets);

      await tester.ensureVisible(find.text('Retry empty'));
      await tester.tap(find.text('Retry empty'));
      await tester.pump();
      expect(find.text('Retry: true More: '), findsOneWidget);

      await tester.ensureVisible(find.text('Open all'));
      await tester.tap(find.text('Open all'));
      await tester.pump();
      expect(find.text('Retry: true More: true'), findsOneWidget);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('renders safe layout primitives without nested scrolling', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.align(alignment: 'bottomRight', child: Mp.text('Aligned')),
                Mp.center(child: Mp.text('Centered')),
                Mp.row(
                  children: <MpNode>[
                    Mp.text('Left'),
                    Mp.spacer(flex: 2),
                    Mp.text('Right'),
                  ],
                ),
                Mp.container(
                  height: 80,
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.text('Top'),
                      Mp.spacer(),
                      Mp.text('Bottom'),
                    ],
                  ),
                ),
                Mp.listView(
                  spacing: 5,
                  paddingVertical: 3,
                  children: <MpNode>[Mp.text('List one'), Mp.text('List two')],
                ),
                Mp.safeArea(
                  left: false,
                  bottom: false,
                  child: Mp.text('Safe child'),
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Aligned'), findsOneWidget);
      expect(find.text('Centered'), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
      expect(find.text('List one'), findsOneWidget);
      expect(find.text('List two'), findsOneWidget);
      expect(find.text('Safe child'), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
      expect(find.byType(Spacer), findsNWidgets(2));
      expect(find.byType(SafeArea), findsAtLeastNWidgets(2));

      final listView = tester.widget<ListView>(find.byType(ListView).last);
      expect(listView.shrinkWrap, isTrue);
      expect(listView.primary, isFalse);
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());

      backendStore.dispose();
    });

    testWidgets('renders visual layout primitives with stack positioning', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.visibility(
                  visible: false,
                  maintainSize: true,
                  child: Mp.text('Hidden kept'),
                ),
                Mp.opacity(
                  opacity: 0,
                  alwaysIncludeSemantics: true,
                  child: Mp.text('Invisible paint'),
                ),
                Mp.aspectRatio(aspectRatio: 2, child: Mp.text('Ratio child')),
                Mp.container(
                  height: 120,
                  child: Mp.stack(
                    alignment: 'bottomRight',
                    clip: false,
                    children: <MpNode>[
                      Mp.text('Base layer'),
                      Mp.positioned(
                        top: 8,
                        right: 8,
                        child: Mp.badge(label: 'New'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Invisible paint'), findsOneWidget);
      expect(find.text('Ratio child'), findsOneWidget);
      expect(find.text('Base layer'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);

      final visibility = tester
          .widgetList<Visibility>(find.byType(Visibility))
          .singleWhere((widget) => widget.maintainSize);
      expect(visibility.visible, isFalse);
      expect(visibility.maintainState, isTrue);
      expect(visibility.maintainAnimation, isTrue);

      final opacity = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .singleWhere(
            (widget) => widget.opacity == 0 && widget.alwaysIncludeSemantics,
          );
      expect(opacity.alwaysIncludeSemantics, isTrue);

      final ratio = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .singleWhere((widget) => widget.aspectRatio == 2);
      expect(ratio.aspectRatio, 2);

      final stack = tester
          .widgetList<Stack>(find.byType(Stack))
          .singleWhere((widget) => widget.clipBehavior == Clip.none);
      expect(stack.alignment, Alignment.bottomRight);

      final positioned = tester
          .widgetList<Positioned>(find.byType(Positioned))
          .singleWhere((widget) => widget.top == 8 && widget.right == 8);
      expect(positioned.child, isNotNull);

      backendStore.dispose();
    });

    testWidgets('renders positioned outside stack as normal child fallback', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () =>
                Mp.positioned(top: 8, child: Mp.text('Outside fallback')),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Outside fallback'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Positioned && widget.top == 8,
        ),
        findsNothing,
      );

      backendStore.dispose();
    });

    testWidgets(
      'renders nested positioned inside stack as normal child fallback',
      (tester) async {
        final backendStore = MiniProgramBackendStore();
        final screenJson = _jsonMap(
          MpProgram(
            screens: <String, MpScreenBuilder>{
              'coupon_home': () => Mp.stack(
                children: <MpNode>[
                  Mp.container(
                    child: Mp.positioned(
                      top: 8,
                      child: Mp.text('Nested fallback'),
                    ),
                  ),
                ],
              ),
            },
          ).buildScreensJson()['coupon_home']!,
        );

        await tester.pumpWidget(
          _scopedApp(backendStore: backendStore, screenJson: screenJson),
        );

        expect(find.text('Nested fallback'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Positioned && widget.top == 8,
          ),
          findsNothing,
        );

        backendStore.dispose();
      },
    );

    testWidgets('renders flex sizing primitives in bounded row and column', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.row(
                  children: <MpNode>[
                    Mp.expanded(flex: 2, child: Mp.text('Row expanded')),
                    Mp.flexible(
                      flex: 3,
                      fit: 'tight',
                      child: Mp.text('Row flexible'),
                    ),
                  ],
                ),
                Mp.container(
                  height: 200,
                  child: Mp.column(
                    children: <MpNode>[
                      Mp.expanded(flex: 4, child: Mp.text('Column expanded')),
                      Mp.flexible(child: Mp.text('Column flexible')),
                    ],
                  ),
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Row expanded'), findsOneWidget);
      expect(find.text('Row flexible'), findsOneWidget);
      expect(find.text('Column expanded'), findsOneWidget);
      expect(find.text('Column flexible'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Expanded && widget.flex == 2,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Flexible && widget.flex == 3,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Expanded && widget.flex == 4,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Flexible &&
              widget.fit == FlexFit.loose &&
              widget.flex == 1,
        ),
        findsAtLeastNWidgets(1),
      );

      backendStore.dispose();
    });

    testWidgets('renders unbounded column flex nodes as safe fallback', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.scrollView(
              child: Mp.column(
                children: <MpNode>[
                  Mp.expanded(flex: 5, child: Mp.text('Unbounded expanded')),
                  Mp.flexible(
                    flex: 6,
                    fit: 'tight',
                    child: Mp.text('Unbounded flexible'),
                  ),
                ],
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Unbounded expanded'), findsOneWidget);
      expect(find.text('Unbounded flexible'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Expanded && widget.flex == 5,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Flexible && widget.flex == 6,
        ),
        findsNothing,
      );

      backendStore.dispose();
    });

    testWidgets('renders standalone and nested flex nodes as normal fallback', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.expanded(flex: 7, child: Mp.text('Standalone expanded')),
                Mp.row(
                  children: <MpNode>[
                    Mp.container(
                      child: Mp.flexible(
                        flex: 8,
                        fit: 'tight',
                        child: Mp.text('Nested flexible'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.text('Standalone expanded'), findsOneWidget);
      expect(find.text('Nested flexible'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Expanded && widget.flex == 7,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Flexible && widget.flex == 8,
        ),
        findsNothing,
      );

      backendStore.dispose();
    });

    testWidgets('renders standalone spacer as safe zero-size fallback', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.spacer(flex: 3),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );

      expect(find.byType(Spacer), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 0 && widget.height == 0,
        ),
        findsWidgets,
      );

      backendStore.dispose();
    });

    testWidgets('auth button opens the SDK email auth sheet without tokens', (
      tester,
    ) async {
      final controller = MiniProgramAuthController(
        store: InMemoryMiniProgramAuthStore(),
        clock: () => DateTime.utc(2026, 6, 3, 12),
      );
      final connector = _AuthConnector();
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        MaterialApp(
          home: MiniProgramSdkScope(
            miniProgramId: 'coupon',
            hostBridge: _NoopHostBridge(),
            capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
              CapabilityIds.auth,
            ]),
            backendConnector: connector,
            authController: controller,
            cacheManager: MiniProgramCacheManager.inMemory(),
            cachePolicy: const MiniProgramCachePolicy(),
            backendStore: backendStore,
            featureFlagEvaluator: const AllowAllFeatureFlagEvaluator(),
            logger: const DebugPrintSdkLogger(),
            openMiniProgramScreen: (_, _) async => _ok('openMiniProgramScreen'),
            resetMiniProgramStack: (_, _) async => _ok('resetMiniProgramStack'),
            replaceMiniProgramScreen: (_, _) async =>
                _ok('replaceMiniProgramScreen'),
            popMiniProgramScreen: (_, _) async => _ok('popMiniProgramScreen'),
            popToMiniProgramRoot: (_, _) async => _ok('popToMiniProgramRoot'),
            popToMiniProgramScreen: (_, _) async =>
                _ok('popToMiniProgramScreen'),
            child: Builder(
              builder: (context) {
                return const MpScreenRenderer().render(
                  MiniProgramRenderRequest(
                    context: context,
                    manifest: _mpManifest,
                    screenId: 'coupon_home',
                    screenJson: _uiGeneratedScreenConst,
                    logger: DebugPrintSdkLogger(),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.textContaining('id-token'), findsNothing);
      expect(find.textContaining('refresh-token'), findsNothing);

      backendStore.dispose();
    });

    testWidgets('authBuilder renders auth state and sign-out action', (
      tester,
    ) async {
      final store = InMemoryMiniProgramAuthStore();
      await store.write('coupon', _session());
      final controller = MiniProgramAuthController(
        store: store,
        clock: _fixedNow,
      );
      await controller.restore(miniProgramId: 'coupon', connector: null);

      final backendStore = MiniProgramBackendStore();
      final cacheManager = MiniProgramCacheManager.inMemory();
      await cacheManager.set(
        appId: 'coupon',
        key: 'login_state',
        value: true,
        bucket: MiniProgramCacheBucket.session,
      );
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          authController: controller,
          backendConnector: _AuthConnector(),
          cacheManager: cacheManager,
          screenJson: _authBuilderScreen,
        ),
      );
      await tester.pump();

      expect(find.text('Signed in as user@example.com'), findsOneWidget);
      expect(find.textContaining('id-token'), findsNothing);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(controller.snapshot('coupon').signedOut, isTrue);
      expect(find.text('Signed out'), findsOneWidget);
      expect(
        await cacheManager.has(
          appId: 'coupon',
          key: 'login_state',
          bucket: MiniProgramCacheBucket.session,
        ),
        isFalse,
      );

      backendStore.dispose();
    });

    testWidgets('backendBuilder queries data with auth bearer bindings', (
      tester,
    ) async {
      final authStore = InMemoryMiniProgramAuthStore();
      await authStore.write('coupon', _session());
      final controller = MiniProgramAuthController(
        store: authStore,
        clock: _fixedNow,
      );
      await controller.restore(miniProgramId: 'coupon', connector: null);
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: 'home/bootstrap',
            method: 'GET',
            data: const <String, dynamic>{'title': 'Backend title'},
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          authController: controller,
          backendConnector: connector,
          screenJson: _backendBuilderScreen,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Backend title'), findsOneWidget);
      expect(connector.calls.single.endpoint, 'home/bootstrap');
      expect(
        connector.calls.single.headers['authorization'],
        'Bearer id-token',
      );

      backendStore.dispose();
    });

    testWidgets(
      'backend.call uses optional runtime middle-server API and fails predictably without it',
      (tester) async {
        final connector = _RecordingBackendConnector(
          responses: <MiniProgramBackendResult>[
            _runtimeApiSuccess(
              requestId: 'runtime_call',
              endpoint: '/products',
              data: const <String, dynamic>{'title': 'Runtime product'},
            ),
          ],
        );

        final success =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.backend.call(
                      requestId: 'runtime_call',
                      endpoint: '/products',
                    ),
                  ),
                  backendConnector: connector,
                )
                as MiniProgramBackendResult;

        expect(success.isSuccess, isTrue);
        expect(success.data['title'], 'Runtime product');
        expect(success.data['traceId'], 'trace_runtime_success');
        expect(connector.calls.single.endpoint, '/products');

        final failure =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.backend.call(
                      requestId: 'runtime_call',
                      endpoint: '/products',
                    ),
                  ),
                )
                as MiniProgramBackendResult;

        expect(failure.isFailure, isTrue);
        expect(failure.errorCode, 'publisher_backend_not_configured');
        expect(
          failure.message,
          'Publisher API is not configured for mini-program "coupon".',
        );
      },
    );

    testWidgets(
      'backend.query writes runtime API snapshots and no-API failure snapshots',
      (tester) async {
        final connector = _RecordingBackendConnector(
          responses: <MiniProgramBackendResult>[
            _runtimeApiSuccess(
              requestId: 'products_query',
              endpoint: '/products',
              data: const <String, dynamic>{'title': 'Runtime products'},
            ),
          ],
        );
        final backendStore = MiniProgramBackendStore();

        final success =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.backend.query(
                      requestId: 'products_query',
                      endpoint: '/products',
                    ),
                  ),
                  backendConnector: connector,
                  backendStore: backendStore,
                )
                as Map<String, dynamic>;

        expect(success['status'], 'success');
        expect(success['data'], containsPair('title', 'Runtime products'));
        expect(
          success['data'],
          containsPair('traceId', 'trace_runtime_success'),
        );
        expect(backendStore.snapshot('products_query').isSuccess, isTrue);
        expect(connector.calls.single.endpoint, '/products');
        backendStore.dispose();

        final missingBackendStore = MiniProgramBackendStore();
        final failure =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.backend.query(
                      requestId: 'products_query',
                      endpoint: '/products',
                    ),
                  ),
                  backendStore: missingBackendStore,
                )
                as Map<String, dynamic>;

        expect(failure['status'], 'failed');
        expect(failure['errorCode'], 'publisher_backend_not_configured');
        expect(
          failure['message'],
          'Publisher API is not configured for mini-program "coupon".',
        );
        expect(
          missingBackendStore.snapshot('products_query').isFailure,
          isTrue,
        );
        missingBackendStore.dispose();
      },
    );

    testWidgets('backendBuilder renders no-API failure state gracefully', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.backendBuilder(
              requestId: 'home',
              endpoint: 'home/bootstrap',
              loading: Mp.text('Loading runtime API'),
              error: Mp.text('Runtime API error: {{backend.home.message}}'),
              child: Mp.text('{{backend.home.data.title}}'),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: screenJson),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Runtime API error: Publisher API is not configured for mini-program "coupon".',
        ),
        findsOneWidget,
      );
      backendStore.dispose();
    });

    testWidgets('pagedBackendBuilder appends items through load more', (
      tester,
    ) async {
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: 'coupons/page?limit=1',
            method: 'GET',
            data: const <String, dynamic>{
              'items': [
                <String, dynamic>{'title': 'Coupon 1'},
              ],
              'nextCursor': 'coupon-1',
              'hasMore': true,
            },
          ),
          MiniProgramBackendResult.success(
            endpoint: 'coupons/page?limit=1&cursor=coupon-1',
            method: 'GET',
            data: const <String, dynamic>{
              'items': [
                <String, dynamic>{'title': 'Coupon 2'},
              ],
              'hasMore': false,
            },
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          screenJson: _pagedBuilderScreen,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Coupon 1'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Coupon 1'), findsOneWidget);
      expect(find.text('Coupon 2'), findsOneWidget);
      expect(find.text('No more coupons'), findsOneWidget);
      expect(connector.calls, hasLength(2));
      expect(
        connector.calls.last.endpoint,
        'coupons/page?limit=1&cursor=coupon-1',
      );

      backendStore.dispose();
    });

    testWidgets('pagedBackendBuilder keeps items on load-more failure', (
      tester,
    ) async {
      final secondPage = Completer<MiniProgramBackendResult>();
      final connector = _FutureBackendConnector(
        responses: <FutureOr<MiniProgramBackendResult>>[
          MiniProgramBackendResult.success(
            endpoint: 'coupons/page?limit=1',
            method: 'GET',
            data: const <String, dynamic>{
              'items': [
                <String, dynamic>{'title': 'Coupon 1'},
              ],
              'nextCursor': 'coupon-1',
              'hasMore': true,
            },
          ),
          secondPage.future,
        ],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          screenJson: _pagedBuilderScreen,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more'));
      await tester.pump();

      expect(find.text('Coupon 1'), findsOneWidget);
      expect(find.text('Loading more coupons'), findsOneWidget);

      secondPage.complete(
        MiniProgramBackendResult.failed(
          endpoint: 'coupons/page?limit=1&cursor=coupon-1',
          method: 'GET',
          message: 'Load failed',
          errorCode: 'load_failed',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coupon 1'), findsOneWidget);
      expect(find.text('Load failed'), findsOneWidget);

      backendStore.dispose();
    });

    testWidgets('navigation actions call existing mini-program handlers', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      String? openedScreenId;

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          screenJson: _navigationScreen,
          openMiniProgramScreen: (payload, _) async {
            openedScreenId = payload.screenId;
            return _ok(ActionNames.openMiniProgramScreen);
          },
        ),
      );

      await tester.tap(find.text('Open details'));
      await tester.pump();

      expect(openedScreenId, 'coupon_details');

      backendStore.dispose();
    });

    testWidgets('stateBuilder rebuilds from state actions and sequence', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.stateBuilder(
                  keys: const <String>['count'],
                  child: Mp.text('Count: {{state.count}}'),
                ),
                Mp.primaryButton(
                  label: 'Add one',
                  action: Mp.state.increment('count'),
                ),
                Mp.secondaryButton(
                  label: 'Set two',
                  action: Mp.action.sequence(<MpAction>[
                    Mp.state.set('count', 1),
                    Mp.state.increment('count'),
                  ]),
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );

      expect(find.text('Count: '), findsOneWidget);

      await tester.tap(find.text('Add one'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);

      stateManager.set('unrelated', 99);
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);

      await tester.tap(find.text('Set two'));
      await tester.pump();

      expect(find.text('Count: 2'), findsOneWidget);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('state text and list actions transform bound values safely', (
      tester,
    ) async {
      final state = MpStateManager();

      await _runMpAction(
        tester,
        _jsonAction(Mp.state.appendText('editor.value', 'A')),
        stateManager: state,
      );
      await _runMpAction(
        tester,
        _jsonAction(Mp.state.appendText('editor.value', '🙂')),
        stateManager: state,
      );
      await _runMpAction(
        tester,
        _jsonAction(Mp.state.backspace('editor.value')),
        stateManager: state,
      );
      expect(state.get<String>('editor.value'), 'A');

      for (final value in <int>[1, 2, 3]) {
        await _runMpAction(
          tester,
          _jsonAction(Mp.state.listAppend('items', value, maxItems: 2)),
          stateManager: state,
        );
      }
      expect(state.get<List<Object?>>('items'), <Object?>[2, 3]);

      await _runMpAction(
        tester,
        _jsonAction(Mp.state.listPrepend('items', 1, maxItems: 3)),
        stateManager: state,
      );
      await _runMpAction(
        tester,
        _jsonAction(
          Mp.state.listInsert('items', 1, <String, Object?>{'id': 7}),
        ),
        stateManager: state,
      );
      await _runMpAction(
        tester,
        _jsonAction(
          Mp.state.listRemoveValue('items', <String, Object?>{'id': 7}),
        ),
        stateManager: state,
      );
      await _runMpAction(
        tester,
        _jsonAction(Mp.state.listRemoveAt('items', 2)),
        stateManager: state,
      );
      expect(state.get<List<Object?>>('items'), <Object?>[1, 2]);

      state.set('items', 'wrong type');
      final failure =
          await _runMpAction(
                tester,
                _jsonAction(Mp.state.listAppend('items', 4)),
                stateManager: state,
              )
              as HostActionResult;
      expect(failure.errorCode, MiniProgramErrorCodes.stateInvalidValue);
      expect(state.get<String>('items'), 'wrong type');

      state.dispose();
    });

    testWidgets('state defaults numeric mutations copy and toggle are safe', (
      tester,
    ) async {
      final state = MpStateManager()..set('cart.step', 3);

      final firstDefault =
          await _runMpAction(
                tester,
                _jsonAction(Mp.state.setDefault('cart.quantity', 2)),
                stateManager: state,
              )
              as HostActionResult;
      final secondDefault =
          await _runMpAction(
                tester,
                _jsonAction(Mp.state.setDefault('cart.quantity', 50)),
                stateManager: state,
              )
              as HostActionResult;
      expect(firstDefault.data['changed'], isTrue);
      expect(secondDefault.data['changed'], isFalse);
      expect(state.get<num>('cart.quantity'), 2);

      final increment =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.state.increment(
                    'cart.quantity',
                    by: '{{state.cart.step}}',
                    max: 4,
                  ),
                ),
                stateManager: state,
              )
              as HostActionResult;
      expect(increment.data['previousValue'], 2);
      expect(increment.data['value'], 4);
      expect(increment.data['clamped'], isTrue);
      expect(state.get<num>('cart.quantity'), 4);

      await _runMpAction(
        tester,
        _jsonAction(Mp.state.decrement('cart.quantity', by: 10, min: 0)),
        stateManager: state,
      );
      expect(state.get<num>('cart.quantity'), 0);

      await _runMpAction(
        tester,
        _jsonAction(Mp.state.increment('new.counter', by: 2, defaultValue: 5)),
        stateManager: state,
      );
      expect(state.get<num>('new.counter'), 7);

      state.set('source.value', <String, Object?>{
        'items': <Object?>[1, 2],
      });
      await _runMpAction(
        tester,
        _jsonAction(Mp.state.copy(from: 'source.value', to: 'target.value')),
        stateManager: state,
      );
      state.set('source.value', <String, Object?>{
        'items': <Object?>[9],
      });
      expect(state.get<Map<String, dynamic>>('target.value'), {
        'items': <Object?>[1, 2],
      });

      state.set('source.number', 12.5);
      await _runMpAction(
        tester,
        _jsonAction(
          Mp.state.copy(
            from: 'source.number',
            to: 'target.text',
            convertTo: 'text',
          ),
        ),
        stateManager: state,
      );
      expect(state.get<String>('target.text'), '12.5');

      state.set('source.text', '42');
      await _runMpAction(
        tester,
        _jsonAction(
          Mp.state.copy(
            from: 'source.text',
            to: 'target.number',
            convertTo: 'number',
          ),
        ),
        stateManager: state,
      );
      expect(state.get<num>('target.number'), 42);

      state.set('target.preserved', 8);
      state.set('source.invalid', 'not-a-number');
      final copyFailure =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.state.copy(
                    from: 'source.invalid',
                    to: 'target.preserved',
                    convertTo: 'number',
                  ),
                ),
                stateManager: state,
              )
              as HostActionResult;
      expect(copyFailure.errorCode, MiniProgramErrorCodes.stateInvalidValue);
      expect(state.get<num>('target.preserved'), 8);

      await _runMpAction(
        tester,
        _jsonAction(Mp.state.toggle('settings.enabled')),
        stateManager: state,
      );
      expect(state.get<bool>('settings.enabled'), isTrue);
      await _runMpAction(
        tester,
        _jsonAction(Mp.state.toggle('settings.enabled')),
        stateManager: state,
      );
      expect(state.get<bool>('settings.enabled'), isFalse);

      state.set('settings.invalid', 'yes');
      final toggleFailure =
          await _runMpAction(
                tester,
                _jsonAction(Mp.state.toggle('settings.invalid')),
                stateManager: state,
              )
              as HostActionResult;
      expect(toggleFailure.errorCode, MiniProgramErrorCodes.stateInvalidValue);
      expect(state.get<String>('settings.invalid'), 'yes');

      state.dispose();
    });

    testWidgets('state.patch applies bindings atomically and reports changes', (
      tester,
    ) async {
      final state = MpStateManager()
        ..set('source.total', 120)
        ..set('checkout.error', 'stale');

      final result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.state.patch(
                    const <String, Object?>{
                      'checkout.total': '{{state.source.total}}',
                      'checkout.ready': true,
                    },
                    remove: const <String>['checkout.error'],
                  ),
                ),
                stateManager: state,
              )
              as HostActionResult;

      expect(result.isSuccess, isTrue);
      expect(result.data['changedKeys'], <String>[
        'checkout.ready',
        'checkout.total',
      ]);
      expect(result.data['removedKeys'], <String>['checkout.error']);
      expect(state.get<num>('checkout.total'), 120);
      expect(state.get<bool>('checkout.ready'), isTrue);
      expect(state.contains('checkout.error'), isFalse);
      state.dispose();
    });

    testWidgets('state quota failures return a stable code and roll back', (
      tester,
    ) async {
      final state = MpStateManager(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 100,
          maxEntries: 20,
          maxValueBytes: 5,
          maxDepth: 10,
        ),
      )..set('value', 'ok');

      final result =
          await _runMpAction(
                tester,
                _jsonAction(Mp.state.set('value', 'too-long')),
                stateManager: state,
              )
              as HostActionResult;

      expect(result.errorCode, MiniProgramErrorCodes.stateLimitExceeded);
      expect(result.data['metric'], 'maxValueBytes');
      expect(state.get<String>('value'), 'ok');
      state.dispose();
    });

    testWidgets('initialize runs once per mount and clears stale errors', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager()..set('screen.error', 'stale');
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.initialize(
              actions: <MpAction>[Mp.state.increment('screen.count')],
              statusState: 'screen.status',
              errorState: 'screen.error',
              loading: Mp.text('Initializing'),
              error: Mp.text('Initialization error'),
              child: Mp.text('Ready {{state.screen.count}}'),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ready 1'), findsOneWidget);
      expect(state.get<String>('screen.status'), 'success');
      expect(state.contains('screen.error'), isFalse);

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pumpAndSettle();
      expect(state.get<num>('screen.count'), 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pumpAndSettle();
      expect(state.get<num>('screen.count'), 2);

      state.dispose();
      backendStore.dispose();
    });

    testWidgets('initialize writes structured failure after retries', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager()..set('screen.count', 'invalid');
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.initialize(
              actions: <MpAction>[Mp.state.increment('screen.count')],
              statusState: 'screen.status',
              errorState: 'screen.error',
              retry: 1,
              retryDelay: Duration.zero,
              error: Mp.text('Initialization error'),
              child: Mp.text('Ready'),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Initialization error'), findsOneWidget);
      expect(state.get<String>('screen.status'), 'error');
      expect(state.get<Map<String, dynamic>>('screen.error'), <String, dynamic>{
        'action': 'state.increment',
        'code': MiniProgramErrorCodes.stateInvalidValue,
        'message': 'Mp state.increment requires finite numeric values.',
      });
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('stateScope removes its owned prefix on disposal', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final state = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () =>
                Mp.stateScope(prefix: 'checkout', child: Mp.text('Checkout')),
          },
        ).buildScreensJson()['coupon_home']!,
      );
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: state,
          screenJson: screenJson,
        ),
      );
      state.set('checkout.total', 50);
      state.set('global.keep', true);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(state.contains('checkout'), isFalse);
      expect(state.get<bool>('global.keep'), isTrue);
      state.dispose();
      backendStore.dispose();
    });

    testWidgets('cache.info writes only app-visible policy and usage', (
      tester,
    ) async {
      final cacheManager = MiniProgramCacheManager.inMemory();
      const policy = MiniProgramCachePolicy(
        maxBytes: 100,
        maxStateBytes: 40,
        stateInactiveTtl: Duration(days: 7),
        allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{
          MiniProgramCacheBucket.state,
        },
      );
      await cacheManager.set(
        appId: 'coupon',
        key: 'history',
        value: 1,
        bucket: MiniProgramCacheBucket.state,
        sizeBytes: 8,
        policy: policy,
      );
      await cacheManager.set(
        appId: 'coupon',
        key: 'session',
        value: 'private',
        bucket: MiniProgramCacheBucket.session,
        sizeBytes: 12,
        policy: policy,
      );
      final state = MpStateManager();

      final result =
          await _runMpAction(
                tester,
                _jsonAction(Mp.cache.info(targetState: 'cache.info')),
                cacheManager: cacheManager,
                cachePolicy: policy,
                stateManager: state,
              )
              as HostActionResult;
      final info = state.get<Map<String, dynamic>>('cache.info')!;
      expect(result.data, info);
      expect(info['usedBytes'], 8);
      expect(info['entryCount'], 1);
      final buckets = info['buckets']! as Map<String, dynamic>;
      expect(buckets, isNot(contains('session')));
      expect(
        (buckets['state'] as Map<String, dynamic>)['ttlMs'],
        const Duration(days: 7).inMilliseconds,
      );
      expect((buckets['data'] as Map<String, dynamic>)['enabled'], isFalse);
      state.dispose();
    });

    testWidgets(
      'math evaluate covers parser precedence functions and bindings',
      (tester) async {
        final state = MpStateManager()..set('input.x', 9);
        final cases = <(String, num)>[
          ('2 + 3 * 4', 14),
          ('2^3^2', 512),
          ('-2^2', -4),
          ('50%', 0.5),
          ('sqrt(81) + mod(10, 4)', 11),
          ('0.1 + 0.2', 0.3),
        ];

        for (final (expression, expected) in cases) {
          final result =
              await _runMpAction(
                    tester,
                    _jsonAction(
                      Mp.math.evaluate(
                        expression: expression,
                        targetState: 'math.result',
                      ),
                    ),
                    stateManager: state,
                  )
                  as HostActionResult;
          expect(result.isSuccess, isTrue, reason: expression);
          expect(state.get<num>('math.result'), expected, reason: expression);
        }

        await _runMpAction(
          tester,
          _jsonAction(
            Mp.math.evaluate(
              expression: 'sin(30) + x',
              variables: const <String, Object?>{'x': '{{state.input.x}}'},
              targetState: 'math.result',
              angleMode: 'degrees',
            ),
          ),
          stateManager: state,
        );
        expect(state.get<num>('math.result'), 9.5);

        state.dispose();
      },
    );

    testWidgets(
      'math failures preserve targets and successful runs clear errors',
      (tester) async {
        final state = MpStateManager()
          ..set('math.result', 99)
          ..set('math.error', <String, Object?>{'code': 'stale'});

        final failure =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.math.evaluate(
                      expression: '1 / 0',
                      targetState: 'math.result',
                      errorState: 'math.error',
                    ),
                  ),
                  stateManager: state,
                )
                as HostActionResult;
        expect(failure.errorCode, MiniProgramErrorCodes.mathDivisionByZero);
        expect(state.get<num>('math.result'), 99);
        expect(
          state.get<Map<String, dynamic>>('math.error')?['code'],
          MiniProgramErrorCodes.mathDivisionByZero,
        );

        final success =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.math.evaluate(
                      expression: 'sqrt(16)',
                      targetState: 'math.result',
                      errorState: 'math.error',
                    ),
                  ),
                  stateManager: state,
                )
                as HostActionResult;
        expect(success.isSuccess, isTrue);
        expect(state.get<num>('math.result'), 4);
        expect(state.get<Object?>('math.error'), isNull);

        final failures = <(String, String)>[
          ('sqrt(-1)', MiniProgramErrorCodes.mathDomainError),
          ('exp(10000)', MiniProgramErrorCodes.mathResultNotFinite),
          ('2pi', MiniProgramErrorCodes.mathInvalidExpression),
        ];
        for (final (expression, errorCode) in failures) {
          final result =
              await _runMpAction(
                    tester,
                    _jsonAction(
                      Mp.math.evaluate(
                        expression: expression,
                        targetState: 'math.result',
                        errorState: 'math.error',
                      ),
                    ),
                    stateManager: state,
                  )
                  as HostActionResult;
          expect(result.errorCode, errorCode, reason: expression);
          expect(state.get<num>('math.result'), 4, reason: expression);
        }

        final complexity = List<String>.filled(130, '1').join('+');
        final complexityFailure =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.math.evaluate(
                      expression: complexity,
                      targetState: 'math.result',
                      errorState: 'math.error',
                    ),
                  ),
                  stateManager: state,
                )
                as HostActionResult;
        expect(
          complexityFailure.errorCode,
          MiniProgramErrorCodes.mathComplexityExceeded,
        );

        state.dispose();
      },
    );

    testWidgets('math compare random and aggregate actions update state', (
      tester,
    ) async {
      final state = MpStateManager()..set('scores', <num>[1, 2, 8, 9]);

      await _runMpAction(
        tester,
        _jsonAction(
          Mp.math.compare(
            left: '0.1 + 0.2',
            right: 0.3,
            targetState: 'math.equal',
          ),
        ),
        stateManager: state,
      );
      expect(state.get<bool>('math.equal'), isTrue);

      await _runMpAction(
        tester,
        _jsonAction(
          Mp.math.randomInt(
            min: 5,
            max: 10,
            seed: 44,
            targetState: 'random.first',
          ),
        ),
        stateManager: state,
      );
      await _runMpAction(
        tester,
        _jsonAction(
          Mp.math.randomInt(
            min: 5,
            max: 10,
            seed: 44,
            targetState: 'random.second',
          ),
        ),
        stateManager: state,
      );
      expect(state.get<int>('random.first'), state.get<int>('random.second'));
      expect(state.get<int>('random.first'), inInclusiveRange(5, 10));

      await _runMpAction(
        tester,
        _jsonAction(
          Mp.math.randomDouble(
            min: 1,
            max: 2,
            seed: 9,
            decimalPlaces: 3,
            targetState: 'random.double',
          ),
        ),
        stateManager: state,
      );
      expect(state.get<num>('random.double'), inInclusiveRange(1, 2));

      await _runMpAction(
        tester,
        _jsonAction(
          Mp.math.aggregate(
            values: '{{state.scores}}',
            operation: 'median',
            targetState: 'scores.median',
          ),
        ),
        stateManager: state,
      );
      expect(state.get<num>('scores.median'), 5);

      await _runMpAction(
        tester,
        _jsonAction(
          Mp.math.aggregate(
            values: const <Object?>[],
            operation: 'sum',
            targetState: 'scores.sum',
          ),
        ),
        stateManager: state,
      );
      expect(state.get<num>('scores.sum'), 0);

      state.dispose();
    });

    testWidgets(
      'sequence resolves math output before history and cache steps',
      (tester) async {
        final state = MpStateManager()..set('calc.expression', '7 + 5');
        final cache = MiniProgramCacheManager.inMemory();
        final result =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.action.sequence(<MpAction>[
                      Mp.math.evaluate(
                        expression: '{{state.calc.expression}}',
                        targetState: 'calc.result',
                      ),
                      Mp.state.listPrepend('calc.history', <String, Object?>{
                        'expression': '{{state.calc.expression}}',
                        'result': '{{state.calc.result}}',
                      }, maxItems: 50),
                      Mp.cache.state.set(
                        'calculator_history',
                        '{{state.calc.history}}',
                      ),
                    ]),
                  ),
                  miniProgramId: 'calculator',
                  cacheManager: cache,
                  cachePolicy: const MiniProgramCachePolicy(
                    allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{
                      MiniProgramCacheBucket.state,
                    },
                  ),
                  stateManager: state,
                )
                as HostActionResult;
        expect(result.isSuccess, isTrue);
        expect(state.get<num>('calc.result'), 12);
        expect(state.get<List<Object?>>('calc.history'), <Object?>[
          <String, Object?>{'expression': '7 + 5', 'result': 12},
        ]);
        final appCache = cache.forApp('calculator');
        expect(
          await appCache.get<Object?>(
            'calculator_history',
            bucket: MiniProgramCacheBucket.state,
          ),
          <Object?>[
            <String, Object?>{'expression': '7 + 5', 'result': 12},
          ],
        );

        state.dispose();
      },
    );

    testWidgets('repeat renders state lists maps scalars index and nesting', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.stateBuilder(
                  keys: const <String>['area.results'],
                  child: Mp.repeat(
                    source: '{{state.area.results.items}}',
                    itemTemplate: Mp.listTile(
                      title: '{{index}}. {{item.name}}',
                      subtitle: '{{item.lat}}, {{item.lon}}',
                    ),
                    empty: Mp.emptyState(title: 'No area found'),
                    separator: Mp.divider(spacing: 0),
                    limit: 2,
                  ),
                ),
                Mp.stateBuilder(
                  keys: const <String>['tags'],
                  child: Mp.repeat(
                    source: '{{state.tags}}',
                    itemTemplate: Mp.chip(label: '{{item.value}}'),
                    spacing: 6,
                  ),
                ),
                Mp.stateBuilder(
                  keys: const <String>['groups'],
                  child: Mp.repeat(
                    source: '{{state.groups}}',
                    itemTemplate: Mp.column(
                      children: <MpNode>[
                        Mp.text('{{item.name}}'),
                        Mp.repeat(
                          source: '{{item.children}}',
                          itemTemplate: Mp.text('{{item.name}}'),
                        ),
                      ],
                    ),
                    empty: Mp.text('No groups'),
                  ),
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );

      expect(find.text('No area found'), findsOneWidget);
      expect(find.text('No groups'), findsOneWidget);

      stateManager.set('area.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Dhaka', 'lat': 23.81, 'lon': 90.41},
          <String, Object?>{'name': 'Khulna', 'lat': 22.82, 'lon': 89.55},
          <String, Object?>{'name': 'Sylhet', 'lat': 24.89, 'lon': 91.87},
        ],
      });
      stateManager.set('tags', <Object?>['Popular', 'Nearby']);
      stateManager.set('groups', <Object?>[
        <String, Object?>{
          'name': 'Dhaka group',
          'children': <Object?>[
            <String, Object?>{'name': 'Dhanmondi'},
          ],
        },
      ]);
      await tester.pump();

      expect(find.text('0. Dhaka'), findsOneWidget);
      expect(find.text('23.81, 90.41'), findsOneWidget);
      expect(find.text('1. Khulna'), findsOneWidget);
      expect(find.text('Sylhet'), findsNothing);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Dhaka group'), findsOneWidget);
      expect(find.text('Dhanmondi'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 1,
        ),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 6,
        ),
        findsOneWidget,
      );

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets(
      'searchInput debounces backend search and repeat renders results',
      (tester) async {
        final backendStore = MiniProgramBackendStore();
        final stateManager = MpStateManager();
        final connector = _RecordingBackendConnector(
          responses: <MiniProgramBackendResult>[
            MiniProgramBackendResult.success(
              endpoint: '/areas/search',
              method: 'GET',
              data: const <String, dynamic>{
                'items': <Object?>[
                  <String, Object?>{
                    'name': 'Dhaka',
                    'lat': 23.81,
                    'lon': 90.41,
                    'code': 'BD-13',
                  },
                ],
              },
            ),
          ],
        );
        final screenJson = _jsonMap(
          MpProgram(
            screens: <String, MpScreenBuilder>{
              'coupon_home': () => Mp.column(
                children: <MpNode>[
                  Mp.searchInput(
                    stateKey: 'area.query',
                    targetState: 'area.results',
                    statusState: 'area.search_status',
                    endpoint: '/areas/search?country=bd',
                    hint: 'Search area',
                    debounce: const Duration(milliseconds: 100),
                    minLength: 2,
                    limit: 10,
                  ),
                  Mp.stateBuilder(
                    keys: const <String>['area.results', 'area.search_status'],
                    child: Mp.column(
                      children: <MpNode>[
                        Mp.text('Status: {{state.area.search_status}}'),
                        Mp.repeat(
                          source: '{{state.area.results.items}}',
                          itemTemplate: Mp.listTile(
                            title: '{{item.name}}',
                            subtitle:
                                '{{item.lat}}, {{item.lon}} - {{item.code}}',
                          ),
                          empty: Mp.emptyState(title: 'No area found'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            },
          ).buildScreensJson()['coupon_home']!,
        );

        await tester.pumpWidget(
          _scopedApp(
            backendStore: backendStore,
            backendConnector: connector,
            stateManager: stateManager,
            screenJson: screenJson,
          ),
        );
        await tester.pump();

        expect(connector.calls, isEmpty);
        expect(find.text('Status: idle'), findsOneWidget);

        await tester.enterText(find.byType(EditableText), 'd');
        await tester.pump(const Duration(milliseconds: 150));

        expect(connector.calls, isEmpty);
        expect(find.text('No area found'), findsOneWidget);

        await tester.enterText(find.byType(EditableText), 'dh');
        await tester.pump(const Duration(milliseconds: 50));

        expect(connector.calls, isEmpty);

        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump();

        expect(connector.calls, hasLength(1));
        expect(
          connector.calls.single.endpoint,
          '/areas/search?country=bd&q=dh&limit=10',
        );
        expect(stateManager.get<String>('area.query'), 'dh');
        expect(find.text('Status: success'), findsOneWidget);
        expect(find.text('Dhaka'), findsOneWidget);
        expect(find.text('23.81, 90.41 - BD-13'), findsOneWidget);

        stateManager.dispose();
        backendStore.dispose();
      },
    );

    testWidgets('searchInput POST merges query limit and cache policy', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/products/search',
            method: 'POST',
            data: const <String, dynamic>{'items': <Object?>[]},
          ),
        ],
      );
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.searchInput(
              stateKey: 'product.query',
              targetState: 'product.results',
              endpoint: '/products/search',
              queryParam: 'term',
              limitParam: 'take',
              method: 'POST',
              body: const <String, Object?>{'category': 'books'},
              minLength: 1,
              limit: 5,
              debounce: Duration.zero,
              cacheTtlSeconds: 30,
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'dart');
      await tester.pump();
      await tester.pump();

      expect(connector.calls, hasLength(1));
      expect(connector.calls.single.endpoint, '/products/search');
      expect(connector.calls.single.method, 'POST');
      expect(connector.calls.single.body, <String, dynamic>{
        'category': 'books',
        'term': 'dart',
        'take': 5,
      });
      expect(
        connector.calls.single.cachePolicy.ttl,
        const Duration(seconds: 30),
      );

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('searchInput ignores stale slower responses', (tester) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final first = Completer<MiniProgramBackendResult>();
      final second = Completer<MiniProgramBackendResult>();
      final connector = _FutureBackendConnector(
        responses: <FutureOr<MiniProgramBackendResult>>[
          first.future,
          second.future,
        ],
      );
      final screenJson = _searchScreenJson(debounce: Duration.zero);

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'dh');
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'dhaka');
      await tester.pump();

      expect(connector.calls, hasLength(2));

      second.complete(
        MiniProgramBackendResult.success(
          endpoint: '/areas/search',
          method: 'GET',
          data: const <String, dynamic>{
            'items': <Object?>[
              <String, Object?>{'name': 'Dhaka'},
            ],
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Dhaka'), findsOneWidget);

      first.complete(
        MiniProgramBackendResult.success(
          endpoint: '/areas/search',
          method: 'GET',
          data: const <String, dynamic>{
            'items': <Object?>[
              <String, Object?>{'name': 'Old Dhaka'},
            ],
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Old Dhaka'), findsNothing);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('searchInput failure keeps previous results and writes error', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/areas/search',
            method: 'GET',
            data: const <String, dynamic>{
              'items': <Object?>[
                <String, Object?>{'name': 'Dhaka'},
              ],
            },
          ),
          MiniProgramBackendResult.failed(
            endpoint: '/areas/search',
            method: 'GET',
            message: 'Backend down',
            errorCode: 'backend_down',
          ),
        ],
      );
      final screenJson = _searchScreenJson(
        debounce: Duration.zero,
        includeError: true,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'dh');
      await tester.pump();
      await tester.pump();

      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Status: success'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'zz');
      await tester.pump();
      await tester.pump();

      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Status: error'), findsOneWidget);
      expect(find.text('Error: Backend down'), findsOneWidget);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('searchInput writes a graceful no-API error state', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final screenJson = _searchScreenJson(
        debounce: Duration.zero,
        includeError: true,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'dh');
      await tester.pump();
      await tester.pump();

      expect(find.text('Status: error'), findsOneWidget);
      expect(
        find.text(
          'Error: Publisher API is not configured for mini-program "coupon".',
        ),
        findsOneWidget,
      );
      expect(stateManager.get<Map<String, dynamic>>('area.results'), {
        'items': <Object?>[],
      });

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('search.loadMore appends GET results into target state', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      stateManager.set('area.query', 'dhaka');
      stateManager.set('area.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Dhaka'},
        ],
        'nextCursor': 'cursor-1',
        'hasMore': true,
        'pageCount': 1,
      });
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/areas/search',
            method: 'GET',
            data: const <String, dynamic>{
              'items': <Object?>[
                <String, Object?>{'name': 'Dhanmondi'},
              ],
              'nextCursor': 'cursor-2',
              'hasMore': true,
            },
          ),
        ],
      );
      final screenJson = _searchLoadMoreScreenJson();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();

      expect(find.text('Dhaka'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();

      expect(connector.calls, hasLength(1));
      expect(
        connector.calls.single.endpoint,
        '/areas/search?country=bd&q=dhaka&limit=2&cursor=cursor-1',
      );
      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Dhanmondi'), findsOneWidget);
      expect(find.text('Status: success'), findsOneWidget);
      final results = stateManager.get<Map<String, dynamic>>('area.results')!;
      expect(results['itemCount'], 2);
      expect(results['pageCount'], 2);
      expect(results['nextCursor'], 'cursor-2');
      expect(results['hasMore'], true);
      expect(results['loadingMore'], false);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('search.loadMore POST merges body query limit and cursor', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      stateManager.set('product.query', 'dart');
      stateManager.set('product.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Dart book'},
        ],
        'nextCursor': 10,
        'hasMore': true,
      });
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/products/search',
            method: 'POST',
            data: const <String, dynamic>{
              'data': <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{'name': 'Flutter book'},
                ],
                'cursor': 20,
                'hasMore': false,
              },
            },
          ),
        ],
      );
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.secondaryButton(
              label: 'Load products',
              action: Mp.search.loadMore(
                queryState: 'product.query',
                targetState: 'product.results',
                endpoint: '/products/search',
                queryParam: 'term',
                cursorParam: 'after',
                limitParam: 'take',
                method: 'POST',
                body: const <String, Object?>{'category': 'books'},
                limit: 5,
                itemsPath: 'data.items',
                nextCursorPath: 'data.cursor',
                hasMorePath: 'data.hasMore',
              ),
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Load products'));
      await tester.pump();
      await tester.pump();

      expect(connector.calls, hasLength(1));
      expect(connector.calls.single.endpoint, '/products/search');
      expect(connector.calls.single.method, 'POST');
      expect(connector.calls.single.body, <String, dynamic>{
        'category': 'books',
        'term': 'dart',
        'take': 5,
        'after': '10',
      });
      final results = stateManager.get<Map<String, dynamic>>(
        'product.results',
      )!;
      expect(results['itemCount'], 2);
      expect(results['nextCursor'], 20);
      expect(results['hasMore'], false);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('search.loadMore skips empty query and no-more states', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final connector = _RecordingBackendConnector(
        responses: const <MiniProgramBackendResult>[],
      );
      var result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.search.loadMore(
                    queryState: 'area.query',
                    targetState: 'area.results',
                    endpoint: '/areas/search',
                  ),
                ),
                backendConnector: connector,
                backendStore: backendStore,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.isSuccess, true);
      expect(result.data['reason'], 'no_query');
      expect(connector.calls, isEmpty);

      stateManager.set('area.query', 'dhaka');
      stateManager.set('area.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Dhaka'},
        ],
        'hasMore': false,
      });
      result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.search.loadMore(
                    queryState: 'area.query',
                    targetState: 'area.results',
                    endpoint: '/areas/search',
                  ),
                ),
                backendConnector: connector,
                backendStore: backendStore,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.isSuccess, true);
      expect(result.data['reason'], 'no_more');
      expect(connector.calls, isEmpty);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets(
      'search.loadMore failure keeps previous items and writes error',
      (tester) async {
        final backendStore = MiniProgramBackendStore();
        final stateManager = MpStateManager();
        stateManager.set('area.query', 'dhaka');
        stateManager.set('area.results', <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'name': 'Dhaka'},
          ],
          'nextCursor': 'cursor-1',
          'hasMore': true,
        });
        final connector = _RecordingBackendConnector(
          responses: <MiniProgramBackendResult>[
            _runtimeApiError(
              endpoint: '/areas/search',
              method: 'GET',
              message: 'Backend down',
              errorCode: 'backend_down',
            ),
          ],
        );
        final screenJson = _searchLoadMoreScreenJson();

        await tester.pumpWidget(
          _scopedApp(
            backendStore: backendStore,
            backendConnector: connector,
            stateManager: stateManager,
            screenJson: screenJson,
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Load more'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Dhaka'), findsOneWidget);
        expect(find.text('Status: error'), findsOneWidget);
        expect(find.text('Error: Backend down'), findsOneWidget);
        final results = stateManager.get<Map<String, dynamic>>('area.results')!;
        expect(results['items'], hasLength(1));
        expect(results['loadingMore'], false);

        stateManager.dispose();
        backendStore.dispose();
      },
    );

    testWidgets('search.loadMore keeps items and writes no-API error', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      stateManager.set('area.query', 'dhaka');
      stateManager.set('area.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Dhaka'},
        ],
        'nextCursor': 'cursor-1',
        'hasMore': true,
      });
      final screenJson = _searchLoadMoreScreenJson();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Load more'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Status: error'), findsOneWidget);
      expect(
        find.text(
          'Error: Publisher API is not configured for search.loadMore.',
        ),
        findsOneWidget,
      );
      final results = stateManager.get<Map<String, dynamic>>('area.results')!;
      expect(results['items'], hasLength(1));
      expect(results['loadingMore'], false);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('search.clear clears query results status and error', (
      tester,
    ) async {
      final stateManager = MpStateManager();
      stateManager.set('area.query', 'dhaka');
      stateManager.set('area.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Dhaka'},
        ],
        'nextCursor': 'cursor-1',
        'hasMore': true,
        'pageCount': 2,
        'loadingMore': true,
        'status': 'error',
      });
      stateManager.set('area.search_status', 'error');
      stateManager.set('area.search_error', <String, Object?>{
        'message': 'Backend down',
      });

      final result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.search.clear(
                    queryState: 'area.query',
                    targetState: 'area.results',
                    statusState: 'area.search_status',
                    errorState: 'area.search_error',
                  ),
                ),
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.isSuccess, isTrue);
      expect(stateManager.get<String>('area.query'), '');
      expect(stateManager.get<String>('area.search_status'), 'idle');
      expect(stateManager.get<Object?>('area.search_error'), isNull);
      expect(
        stateManager.get<Map<String, dynamic>>('area.results'),
        <String, dynamic>{
          'items': <Object?>[],
          'itemCount': 0,
          'pageCount': 0,
          'hasMore': false,
          'nextCursor': null,
          'loadingMore': false,
          'status': 'idle',
        },
      );

      stateManager.dispose();
    });

    testWidgets('search.refresh replaces GET results with first page', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      stateManager.set('area.query', 'dhaka');
      stateManager.set('area.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Old Dhaka'},
        ],
        'nextCursor': 'old-cursor',
        'hasMore': true,
        'pageCount': 3,
      });
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/areas/search',
            method: 'GET',
            data: const <String, dynamic>{
              'items': <Object?>[
                <String, Object?>{'name': 'Dhaka'},
              ],
              'nextCursor': 'cursor-1',
              'hasMore': true,
            },
          ),
        ],
      );

      final result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.search.refresh(
                    queryState: 'area.query',
                    targetState: 'area.results',
                    statusState: 'area.search_status',
                    errorState: 'area.search_error',
                    endpoint: '/areas/search?country=bd',
                    limit: 2,
                  ),
                ),
                backendConnector: connector,
                backendStore: backendStore,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.isSuccess, isTrue);
      expect(connector.calls, hasLength(1));
      expect(
        connector.calls.single.endpoint,
        '/areas/search?country=bd&q=dhaka&limit=2',
      );
      final results = stateManager.get<Map<String, dynamic>>('area.results')!;
      expect(results['items'], <Object?>[
        <String, Object?>{'name': 'Dhaka'},
      ]);
      expect(results['itemCount'], 1);
      expect(results['pageCount'], 1);
      expect(results['nextCursor'], 'cursor-1');
      expect(results['hasMore'], true);
      expect(results['loadingMore'], false);
      expect(results['status'], 'success');
      expect(stateManager.get<String>('area.search_status'), 'success');
      expect(stateManager.get<Object?>('area.search_error'), isNull);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('search.refresh POST merges body query and limit', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      stateManager.set('product.query', 'dart');
      stateManager.set('product.results', <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'name': 'Old book'},
        ],
      });
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/products/search',
            method: 'POST',
            data: const <String, dynamic>{
              'data': <String, Object?>{
                'items': <Object?>[],
                'cursor': null,
                'hasMore': false,
              },
            },
          ),
        ],
      );

      final result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.search.refresh(
                    queryState: 'product.query',
                    targetState: 'product.results',
                    endpoint: '/products/search',
                    queryParam: 'term',
                    limitParam: 'take',
                    method: 'POST',
                    body: const <String, Object?>{'category': 'books'},
                    limit: 5,
                    itemsPath: 'data.items',
                    nextCursorPath: 'data.cursor',
                    hasMorePath: 'data.hasMore',
                  ),
                ),
                backendConnector: connector,
                backendStore: backendStore,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.isSuccess, isTrue);
      expect(connector.calls, hasLength(1));
      expect(connector.calls.single.endpoint, '/products/search');
      expect(connector.calls.single.method, 'POST');
      expect(connector.calls.single.body, <String, dynamic>{
        'category': 'books',
        'term': 'dart',
        'take': 5,
      });
      final results = stateManager.get<Map<String, dynamic>>(
        'product.results',
      )!;
      expect(results['items'], isEmpty);
      expect(results['itemCount'], 0);
      expect(results['pageCount'], 1);
      expect(results['hasMore'], false);
      expect(results['status'], 'empty');

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('search.refresh skips empty query without backend call', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final connector = _RecordingBackendConnector(
        responses: const <MiniProgramBackendResult>[],
      );

      final result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.search.refresh(
                    queryState: 'area.query',
                    targetState: 'area.results',
                    endpoint: '/areas/search',
                  ),
                ),
                backendConnector: connector,
                backendStore: backendStore,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.isSuccess, isTrue);
      expect(result.data['reason'], 'no_query');
      expect(connector.calls, isEmpty);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets(
      'search.refresh failure keeps previous results and writes error',
      (tester) async {
        final backendStore = MiniProgramBackendStore();
        final stateManager = MpStateManager();
        stateManager.set('area.query', 'dhaka');
        stateManager.set('area.results', <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'name': 'Dhaka'},
          ],
          'nextCursor': 'cursor-1',
          'hasMore': true,
          'pageCount': 1,
        });
        final connector = _RecordingBackendConnector(
          responses: <MiniProgramBackendResult>[
            MiniProgramBackendResult.failed(
              endpoint: '/areas/search',
              method: 'GET',
              message: 'Backend down',
              errorCode: 'backend_down',
            ),
          ],
        );

        final result =
            await _runMpAction(
                  tester,
                  _jsonAction(
                    Mp.search.refresh(
                      queryState: 'area.query',
                      targetState: 'area.results',
                      statusState: 'area.search_status',
                      errorState: 'area.search_error',
                      endpoint: '/areas/search',
                    ),
                  ),
                  backendConnector: connector,
                  backendStore: backendStore,
                  stateManager: stateManager,
                )
                as HostActionResult;

        expect(result.isSuccess, isFalse);
        final results = stateManager.get<Map<String, dynamic>>('area.results')!;
        expect(results['items'], <Object?>[
          <String, Object?>{'name': 'Dhaka'},
        ]);
        expect(results['itemCount'], 1);
        expect(results['loadingMore'], false);
        expect(results['status'], 'error');
        expect(stateManager.get<String>('area.search_status'), 'error');
        expect(
          stateManager.get<Map<String, dynamic>>('area.search_error'),
          <String, dynamic>{'message': 'Backend down', 'code': 'backend_down'},
        );

        stateManager.dispose();
        backendStore.dispose();
      },
    );

    testWidgets('cache actions store read update state remove and clear', (
      tester,
    ) async {
      final cacheManager = MiniProgramCacheManager.inMemory();
      final stateManager = MpStateManager();

      final result =
          await _runMpAction(
                tester,
                <String, dynamic>{
                  'type': 'sequence',
                  'props': <String, dynamic>{
                    'steps': <Object?>[
                      <String, dynamic>{
                        'type': 'state.set',
                        'props': <String, dynamic>{
                          'key': 'source.products',
                          'value': <String, Object?>{
                            'items': <Object?>['one', 'two'],
                          },
                        },
                      },
                      <String, dynamic>{
                        'type': 'cache.set',
                        'props': <String, dynamic>{
                          'requestId': 'set-products',
                          'key': 'products_page_1',
                          'value': '{{state.source.products}}',
                          'ttlMs': 86400000,
                          'priority': 'normal',
                        },
                      },
                      <String, dynamic>{
                        'type': 'cache.has',
                        'props': <String, dynamic>{
                          'key': 'products_page_1',
                          'targetState': 'cache.has_products',
                        },
                      },
                      <String, dynamic>{
                        'type': 'cache.get',
                        'props': <String, dynamic>{
                          'key': 'products_page_1',
                          'targetState': 'cache.products',
                        },
                      },
                      <String, dynamic>{
                        'type': 'cache.remove',
                        'props': <String, dynamic>{'key': 'products_page_1'},
                      },
                      <String, dynamic>{
                        'type': 'cache.has',
                        'props': <String, dynamic>{
                          'key': 'products_page_1',
                          'targetState': 'cache.has_after_remove',
                        },
                      },
                    ],
                  },
                },
                cacheManager: cacheManager,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.isSuccess, isTrue);
      expect(stateManager.get<bool>('cache.has_products'), isTrue);
      expect(
        stateManager.get<Map<String, dynamic>>('cache.products'),
        <String, dynamic>{
          'items': <Object?>['one', 'two'],
        },
      );
      expect(stateManager.get<bool>('cache.has_after_remove'), isFalse);

      await cacheManager.set(
        appId: 'coupon',
        key: 'session',
        value: 'keep',
        bucket: MiniProgramCacheBucket.session,
      );
      await cacheManager
          .forApp('coupon')
          .set('state', 'drop', bucket: MiniProgramCacheBucket.state);
      await cacheManager
          .forApp('coupon')
          .set('image', 'drop', bucket: MiniProgramCacheBucket.image);
      await cacheManager
          .forApp('coupon')
          .set('memory', 'drop', bucket: MiniProgramCacheBucket.memory);

      final clearResult =
          await _runMpAction(
                tester,
                <String, dynamic>{
                  'type': 'cache.clear',
                  'props': <String, dynamic>{'requestId': 'clear-all'},
                },
                cacheManager: cacheManager,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(clearResult.isSuccess, isTrue);
      expect(clearResult.requestId, 'clear-all');
      expect(clearResult.data['clearedBuckets'], <String>[
        'memory',
        'data',
        'image',
        'state',
      ]);
      expect(
        await cacheManager.has(
          appId: 'coupon',
          key: 'session',
          bucket: MiniProgramCacheBucket.session,
        ),
        isTrue,
      );
      expect(
        await cacheManager
            .forApp('coupon')
            .has('state', bucket: MiniProgramCacheBucket.state),
        isFalse,
      );
      expect(
        await cacheManager
            .forApp('coupon')
            .has('image', bucket: MiniProgramCacheBucket.image),
        isFalse,
      );
      expect(
        await cacheManager
            .forApp('coupon')
            .has('memory', bucket: MiniProgramCacheBucket.memory),
        isFalse,
      );

      stateManager.dispose();
    });

    testWidgets('cache get handles missing and cached null values', (
      tester,
    ) async {
      final stateManager = MpStateManager();
      final cacheManager = MiniProgramCacheManager.inMemory();
      stateManager.set('cache.missing', 'keep');

      await _runMpAction(
        tester,
        <String, dynamic>{
          'type': 'cache.get',
          'props': <String, dynamic>{
            'key': 'missing',
            'targetState': 'cache.missing',
            'skipMissing': true,
          },
        },
        cacheManager: cacheManager,
        stateManager: stateManager,
      );
      expect(stateManager.get<String>('cache.missing'), 'keep');

      await _runMpAction(
        tester,
        <String, dynamic>{
          'type': 'cache.get',
          'props': <String, dynamic>{
            'key': 'missing',
            'targetState': 'cache.missing',
          },
        },
        cacheManager: cacheManager,
        stateManager: stateManager,
      );
      final stateDataAfterMissing = stateManager.toBindingData();
      expect(
        (stateDataAfterMissing['cache'] as Map<String, dynamic>).containsKey(
          'missing',
        ),
        isTrue,
      );
      expect(stateManager.get<Object?>('cache.missing'), isNull);

      await _runMpAction(
        tester,
        <String, dynamic>{
          'type': 'cache.set',
          'props': <String, dynamic>{'key': 'nullable', 'value': null},
        },
        cacheManager: cacheManager,
        stateManager: stateManager,
      );
      final result =
          await _runMpAction(
                tester,
                <String, dynamic>{
                  'type': 'cache.get',
                  'props': <String, dynamic>{
                    'key': 'nullable',
                    'targetState': 'cache.nullable',
                    'skipMissing': true,
                  },
                },
                cacheManager: cacheManager,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.data['found'], isTrue);
      expect(result.data['value'], isNull);
      final stateDataAfterNull = stateManager.toBindingData();
      expect(
        (stateDataAfterNull['cache'] as Map<String, dynamic>).containsKey(
          'nullable',
        ),
        isTrue,
      );
      expect(stateManager.get<Object?>('cache.nullable'), isNull);

      stateManager.dispose();
    });

    testWidgets('cache action TTL is clamped by host policy', (tester) async {
      final clock = _TestClock(DateTime.utc(2026, 6, 7, 8));
      final stateManager = MpStateManager();
      final cacheManager = MiniProgramCacheManager.inMemory(clock: clock.now);
      const policy = MiniProgramCachePolicy(dataTtl: Duration(milliseconds: 1));

      await _runMpAction(
        tester,
        <String, dynamic>{
          'type': 'cache.set',
          'props': <String, dynamic>{
            'key': 'short_lived',
            'value': 'live',
            'ttlMs': 60000,
          },
        },
        cacheManager: cacheManager,
        cachePolicy: policy,
        stateManager: stateManager,
      );

      clock.advance(const Duration(milliseconds: 2));

      final result =
          await _runMpAction(
                tester,
                <String, dynamic>{
                  'type': 'cache.get',
                  'props': <String, dynamic>{
                    'key': 'short_lived',
                    'targetState': 'cache.expired',
                  },
                },
                cacheManager: cacheManager,
                cachePolicy: policy,
                stateManager: stateManager,
              )
              as HostActionResult;

      expect(result.data['found'], isFalse);
      expect(stateManager.get<Object?>('cache.expired'), isNull);

      stateManager.dispose();
    });

    testWidgets('cache actions fail when host disables a bucket', (
      tester,
    ) async {
      const policy = MiniProgramCachePolicy(
        allowedMiniProgramCacheBuckets: <MiniProgramCacheBucket>{
          MiniProgramCacheBucket.data,
        },
      );

      final setResult =
          await _runMpAction(tester, <String, dynamic>{
                'type': 'cache.set',
                'props': <String, dynamic>{
                  'requestId': 'set-state',
                  'bucket': 'state',
                  'key': 'history',
                  'value': '1 + 1 = 2',
                },
              }, cachePolicy: policy)
              as HostActionResult;
      expect(setResult.isSuccess, isFalse);
      expect(setResult.requestId, 'set-state');
      expect(setResult.errorCode, 'cache_bucket_disabled');

      final getResult =
          await _runMpAction(tester, <String, dynamic>{
                'type': 'cache.get',
                'props': <String, dynamic>{
                  'requestId': 'get-state',
                  'bucket': 'state',
                  'key': 'history',
                },
              }, cachePolicy: policy)
              as HostActionResult;
      expect(getResult.isSuccess, isFalse);
      expect(getResult.requestId, 'get-state');
      expect(getResult.errorCode, 'cache_bucket_disabled');

      final clearResult =
          await _runMpAction(tester, <String, dynamic>{
                'type': 'cache.clear',
                'props': <String, dynamic>{
                  'requestId': 'clear-state',
                  'bucket': 'state',
                },
              }, cachePolicy: policy)
              as HostActionResult;
      expect(clearResult.isSuccess, isFalse);
      expect(clearResult.requestId, 'clear-state');
      expect(clearResult.errorCode, 'cache_bucket_disabled');
    });

    testWidgets('cache actions are scoped by mini-program id', (tester) async {
      final cacheManager = MiniProgramCacheManager.inMemory();

      await _runMpAction(
        tester,
        <String, dynamic>{
          'type': 'cache.set',
          'props': <String, dynamic>{'key': 'shared', 'value': 'coupon'},
        },
        cacheManager: cacheManager,
        miniProgramId: 'coupon',
      );
      await _runMpAction(
        tester,
        <String, dynamic>{
          'type': 'cache.set',
          'props': <String, dynamic>{'key': 'shared', 'value': 'shop'},
        },
        cacheManager: cacheManager,
        miniProgramId: 'shop',
      );

      expect(
        await cacheManager.forApp('coupon').get<String>('shared'),
        'coupon',
      );
      expect(await cacheManager.forApp('shop').get<String>('shared'), 'shop');
    });

    testWidgets('cache actions work with file-backed persistent cache', (
      tester,
    ) async {
      final directory = (await tester.runAsync<Directory>(
        () =>
            Directory.systemTemp.createTemp('mini_program_cache_action_test_'),
      ))!;
      try {
        await _runMpAction(tester, <String, dynamic>{
          'type': 'sequence',
          'props': <String, dynamic>{
            'steps': <Object?>[
              <String, dynamic>{
                'type': 'cache.set',
                'props': <String, dynamic>{
                  'key': 'products',
                  'value': 'persisted_data',
                },
              },
              <String, dynamic>{
                'type': 'cache.set',
                'props': <String, dynamic>{
                  'key': 'selected_tab',
                  'bucket': 'state',
                  'value': 'saved_state',
                },
              },
              <String, dynamic>{
                'type': 'cache.set',
                'props': <String, dynamic>{
                  'key': 'runtime',
                  'bucket': 'memory',
                  'value': 'memory_only',
                },
              },
            ],
          },
        }, cacheManager: _fileCacheManager(directory));

        final coldState = MpStateManager();
        await _runMpAction(
          tester,
          <String, dynamic>{
            'type': 'sequence',
            'props': <String, dynamic>{
              'steps': <Object?>[
                <String, dynamic>{
                  'type': 'cache.get',
                  'props': <String, dynamic>{
                    'key': 'products',
                    'targetState': 'cache.products',
                  },
                },
                <String, dynamic>{
                  'type': 'cache.get',
                  'props': <String, dynamic>{
                    'key': 'selected_tab',
                    'bucket': 'state',
                    'targetState': 'cache.tab',
                  },
                },
                <String, dynamic>{
                  'type': 'cache.get',
                  'props': <String, dynamic>{
                    'key': 'runtime',
                    'bucket': 'memory',
                    'targetState': 'cache.runtime',
                  },
                },
                <String, dynamic>{
                  'type': 'cache.clear',
                  'props': <String, dynamic>{'bucket': 'data'},
                },
              ],
            },
          },
          cacheManager: _fileCacheManager(directory),
          stateManager: coldState,
        );

        expect(coldState.get<String>('cache.products'), 'persisted_data');
        expect(coldState.get<String>('cache.tab'), 'saved_state');
        expect(coldState.get<Object?>('cache.runtime'), isNull);
        final productsAfterClear = await tester.runAsync(
          () => _fileCacheManager(
            directory,
          ).forApp('coupon').get<String>('products'),
        );
        final stateAfterClear = await tester.runAsync(
          () => _fileCacheManager(directory)
              .forApp('coupon')
              .get<String>(
                'selected_tab',
                bucket: MiniProgramCacheBucket.state,
              ),
        );
        expect(productsAfterClear, isNull);
        expect(stateAfterClear, 'saved_state');

        coldState.dispose();
      } finally {
        await tester.runAsync(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
      }
    });

    testWidgets(
      'lazy section shows placeholder then writes backend query data',
      (tester) async {
        final completer = Completer<MiniProgramBackendResult>();
        final connector = _FutureBackendConnector(
          responses: <FutureOr<MiniProgramBackendResult>>[completer.future],
        );
        final backendStore = MiniProgramBackendStore();
        final stateManager = MpStateManager();

        await tester.pumpWidget(
          _scopedApp(
            backendStore: backendStore,
            backendConnector: connector,
            stateManager: stateManager,
            screenJson: _lazySectionScreen(
              id: 'lazy_backend_query',
              placeholder: Mp.text('Loading products'),
              targetState: 'products',
              statusState: 'products_status',
              actions: <MpAction>[
                Mp.backend.query(
                  requestId: 'products_query',
                  endpoint: '/products',
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Loading products'), findsOneWidget);
        expect(connector.calls.single.requestId, 'products_query');
        expect(connector.calls.single.endpoint, '/products');
        expect(stateManager.get<String>('products_status'), 'loading');

        completer.complete(
          MiniProgramBackendResult.success(
            requestId: 'products_query',
            endpoint: '/products',
            data: const <String, dynamic>{'title': 'Loaded products'},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Loaded products'), findsOneWidget);
        expect(
          stateManager.get<Map<String, dynamic>>('products'),
          <String, dynamic>{'title': 'Loaded products'},
        );
        expect(stateManager.get<String>('products_status'), 'success');

        stateManager.dispose();
        backendStore.dispose();
      },
    );

    testWidgets('lazy section renders child immediately for empty actions', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          screenJson: _lazySectionScreen(
            id: 'lazy_empty_actions',
            child: Mp.text('Static lazy content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Static lazy content'), findsOneWidget);

      backendStore.dispose();
    });

    testWidgets('lazy section renders error fallback after action failure', (
      tester,
    ) async {
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.failed(
            requestId: 'products_query',
            endpoint: '/products',
            message: 'Nope',
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          screenJson: _lazySectionScreen(
            id: 'lazy_error_fallback',
            error: Mp.text('Could not load products'),
            actions: <MpAction>[
              Mp.backend.query(
                requestId: 'products_query',
                endpoint: '/products',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load products'), findsOneWidget);
      expect(find.text('Loaded products'), findsNothing);

      backendStore.dispose();
    });

    testWidgets('lazy section hydrates from cache and supports cached null', (
      tester,
    ) async {
      final cacheManager = MiniProgramCacheManager.inMemory();
      final stateManager = MpStateManager();
      await cacheManager.forApp('coupon').set(
        'lazy_cached_products',
        <String, dynamic>{'title': 'Cached products'},
      );
      await cacheManager.forApp('coupon').set('lazy_cached_null', null);
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          cacheManager: cacheManager,
          stateManager: stateManager,
          screenJson: _lazySectionScreen(
            id: 'lazy_cache_hit',
            cacheKey: 'lazy_cached_products',
            targetState: 'products',
            placeholder: Mp.text('Loading from cache'),
            actions: <MpAction>[
              Mp.backend.query(
                requestId: 'products_query',
                endpoint: '/products',
              ),
            ],
          ),
        ),
      );
      expect(find.text('Loading from cache'), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('Cached products'), findsOneWidget);
      expect(connector.calls, isEmpty);

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          cacheManager: cacheManager,
          stateManager: stateManager,
          screenJson: _lazySectionScreen(
            id: 'lazy_cache_null_hit',
            cacheKey: 'lazy_cached_null',
            targetState: 'nullable',
            child: Mp.text('Cached null ready'),
            actions: <MpAction>[
              Mp.backend.query(
                requestId: 'nullable_query',
                endpoint: '/nullable',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cached null ready'), findsOneWidget);
      expect(connector.calls, isEmpty);
      expect(stateManager.toBindingData().containsKey('nullable'), isTrue);
      expect(stateManager.get<Object?>('nullable'), isNull);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('lazy section refreshes cached content in background safely', (
      tester,
    ) async {
      final cacheManager = MiniProgramCacheManager.inMemory();
      final stateManager = MpStateManager();
      await cacheManager.forApp('coupon').set(
        'lazy_refresh_products',
        <String, dynamic>{'title': 'Cached products'},
      );
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.failed(
            requestId: 'products_refresh',
            endpoint: '/products',
            message: 'Refresh failed',
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          cacheManager: cacheManager,
          stateManager: stateManager,
          screenJson: _lazySectionScreen(
            id: 'lazy_refresh_cached',
            cacheKey: 'lazy_refresh_products',
            targetState: 'products',
            refreshIfCached: true,
            actions: <MpAction>[
              Mp.backend.query(
                requestId: 'products_refresh',
                endpoint: '/products',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cached products'), findsOneWidget);
      expect(connector.calls, hasLength(1));
      expect(
        stateManager.get<Map<String, dynamic>>('products'),
        <String, dynamic>{'title': 'Cached products'},
      );

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('lazy section saves success data to cache with policy TTL', (
      tester,
    ) async {
      final clock = _TestClock(DateTime.utc(2026, 6, 7, 12));
      final cacheManager = MiniProgramCacheManager.inMemory(clock: clock.now);
      const policy = MiniProgramCachePolicy(dataTtl: Duration(milliseconds: 1));
      final stateManager = MpStateManager();
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/products',
            data: const <String, dynamic>{'title': 'Fresh products'},
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          cacheManager: cacheManager,
          cachePolicy: policy,
          stateManager: stateManager,
          screenJson: _lazySectionScreen(
            id: 'lazy_cache_save',
            cacheKey: 'lazy_cache_save_products',
            targetState: 'products',
            ttl: const Duration(days: 1),
            actions: <MpAction>[Mp.backend.call(endpoint: '/products')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fresh products'), findsOneWidget);
      final appCache = cacheManager.forApp('coupon', policy: policy);
      expect(await appCache.has('lazy_cache_save_products'), isTrue);
      clock.advance(const Duration(milliseconds: 2));
      expect(await appCache.has('lazy_cache_save_products'), isFalse);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('lazy section retries failed actions before success', (
      tester,
    ) async {
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.failed(endpoint: '/products'),
          MiniProgramBackendResult.success(
            endpoint: '/products',
            data: const <String, dynamic>{'title': 'Retried products'},
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: _lazySectionScreen(
            id: 'lazy_retry_success',
            targetState: 'products',
            retry: 1,
            retryDelay: Duration.zero,
            actions: <MpAction>[Mp.backend.call(endpoint: '/products')],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(connector.calls, hasLength(2));
      expect(find.text('Retried products'), findsOneWidget);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets(
      'lazy section once skips duplicate action runs for same screen',
      (tester) async {
        final connector = _RecordingBackendConnector(
          responses: <MiniProgramBackendResult>[
            MiniProgramBackendResult.success(
              endpoint: '/products',
              data: const <String, dynamic>{'title': 'Once products'},
            ),
            MiniProgramBackendResult.success(
              endpoint: '/products',
              data: const <String, dynamic>{'title': 'Unexpected products'},
            ),
          ],
        );
        final backendStore = MiniProgramBackendStore();
        final stateManager = MpStateManager();
        final screenJson = _lazySectionScreen(
          id: 'lazy_once_products',
          targetState: 'products',
          actions: <MpAction>[Mp.backend.call(endpoint: '/products')],
        );

        await tester.pumpWidget(
          _scopedApp(
            backendStore: backendStore,
            backendConnector: connector,
            stateManager: stateManager,
            screenJson: screenJson,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Once products'), findsOneWidget);
        expect(connector.calls, hasLength(1));

        await tester.pumpWidget(
          _scopedApp(
            backendStore: backendStore,
            backendConnector: connector,
            stateManager: stateManager,
            screenJson: screenJson,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Once products'), findsOneWidget);
        expect(connector.calls, hasLength(1));

        stateManager.dispose();
        backendStore.dispose();
      },
    );

    testWidgets(
      'lazy chunk initial load accepts runtime API pagination envelope',
      (tester) async {
        final connector = _RecordingBackendConnector(
          responses: <MiniProgramBackendResult>[
            _runtimeApiPage(
              requestId: 'rewards',
              endpoint: '/rewards',
              items: const <Object?>[
                <String, dynamic>{'title': 'Reward A'},
              ],
              nextCursor: 'cursor-2',
              hasMore: true,
              traceId: 'trace_rewards_page_1',
            ),
          ],
        );
        final backendStore = MiniProgramBackendStore();
        final stateManager = MpStateManager();

        await tester.pumpWidget(
          _scopedApp(
            backendStore: backendStore,
            backendConnector: connector,
            stateManager: stateManager,
            screenJson: _lazyChunkScreen(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reward A'), findsOneWidget);
        expect(find.text('Load more rewards'), findsOneWidget);
        expect(connector.calls.single.requestId, 'rewards');
        expect(connector.calls.single.endpoint, '/rewards?limit=1');
        expect(stateManager.get<Object?>('rewards.items'), <Object?>[
          <String, dynamic>{'title': 'Reward A'},
        ]);
        expect(stateManager.get<String>('rewards.next_cursor'), 'cursor-2');
        expect(stateManager.get<bool>('rewards.has_more'), isTrue);
        expect(stateManager.get<String>('rewards.status'), 'success');

        stateManager.dispose();
        backendStore.dispose();
      },
    );

    testWidgets('lazy chunk load more appends and guards duplicate taps', (
      tester,
    ) async {
      final loadMoreCompleter = Completer<MiniProgramBackendResult>();
      final connector = _FutureBackendConnector(
        responses: <FutureOr<MiniProgramBackendResult>>[
          MiniProgramBackendResult.success(
            endpoint: '/rewards',
            data: const <String, dynamic>{
              'items': <Object?>[
                <String, dynamic>{'title': 'Reward A'},
              ],
              'nextCursor': 'cursor-2',
              'hasMore': true,
            },
          ),
          loadMoreCompleter.future,
        ],
      );
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: _lazyChunkScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load more rewards'));
      await tester.tap(find.text('Load more rewards'));
      await tester.pump();

      expect(connector.calls, hasLength(2));
      expect(connector.calls.last.endpoint, '/rewards?limit=1&cursor=cursor-2');
      expect(find.text('Loading more rewards'), findsOneWidget);

      loadMoreCompleter.complete(
        MiniProgramBackendResult.success(
          endpoint: '/rewards',
          data: const <String, dynamic>{
            'items': <Object?>[
              <String, dynamic>{'title': 'Reward B'},
            ],
            'nextCursor': null,
            'hasMore': false,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reward A'), findsOneWidget);
      expect(find.text('Reward B'), findsOneWidget);
      expect(find.text('No more rewards'), findsOneWidget);
      expect(stateManager.get<Object?>('rewards.items'), <Object?>[
        <String, dynamic>{'title': 'Reward A'},
        <String, dynamic>{'title': 'Reward B'},
      ]);
      expect(stateManager.get<bool>('rewards.has_more'), isFalse);

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('lazy chunk hydrates first page from cache', (tester) async {
      final cacheManager = MiniProgramCacheManager.inMemory();
      await cacheManager.forApp('coupon').set(
        'rewards_chunk__initial',
        <String, dynamic>{
          'items': <Object?>[
            <String, dynamic>{'title': 'Cached Reward'},
          ],
          'nextCursor': 'cached-cursor',
          'hasMore': true,
          'pageCount': 1,
        },
      );
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[],
      );
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          cacheManager: cacheManager,
          stateManager: stateManager,
          screenJson: _lazyChunkScreen(cacheKeyPrefix: 'rewards_chunk'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cached Reward'), findsOneWidget);
      expect(find.text('Load more rewards'), findsOneWidget);
      expect(connector.calls, isEmpty);
      expect(stateManager.get<String>('rewards.next_cursor'), 'cached-cursor');

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('lazy chunk load more failure keeps previous items', (
      tester,
    ) async {
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/rewards',
            data: const <String, dynamic>{
              'items': <Object?>[
                <String, dynamic>{'title': 'Reward A'},
              ],
              'nextCursor': 'cursor-2',
              'hasMore': true,
            },
          ),
          MiniProgramBackendResult.failed(
            endpoint: '/rewards',
            message: 'Backend failed',
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          stateManager: stateManager,
          screenJson: _lazyChunkScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load more rewards'));
      await tester.pumpAndSettle();

      expect(find.text('Reward A'), findsOneWidget);
      expect(find.text('Rewards failed'), findsOneWidget);
      expect(stateManager.get<Object?>('rewards.items'), <Object?>[
        <String, dynamic>{'title': 'Reward A'},
      ]);
      expect(stateManager.get<String>('rewards.status'), 'error');

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('lazy chunk renders empty and end states', (tester) async {
      final emptyStore = MiniProgramBackendStore();
      final emptyState = MpStateManager();
      final emptyConnector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/rewards',
            data: const <String, dynamic>{
              'items': <Object?>[],
              'nextCursor': null,
              'hasMore': false,
            },
          ),
        ],
      );
      await tester.pumpWidget(
        _scopedApp(
          backendStore: emptyStore,
          backendConnector: emptyConnector,
          stateManager: emptyState,
          screenJson: _lazyChunkScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No rewards'), findsOneWidget);
      expect(emptyState.get<String>('rewards.status'), 'empty');
      emptyState.dispose();
      emptyStore.dispose();

      final endStore = MiniProgramBackendStore();
      final endState = MpStateManager();
      final endConnector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: '/rewards',
            data: const <String, dynamic>{
              'items': <Object?>[
                <String, dynamic>{'title': 'Final Reward'},
              ],
              'nextCursor': null,
              'hasMore': false,
            },
          ),
        ],
      );
      await tester.pumpWidget(
        _scopedApp(
          backendStore: endStore,
          backendConnector: endConnector,
          stateManager: endState,
          screenJson: _lazyChunkScreen(id: 'rewards_chunk_end'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Final Reward'), findsOneWidget);
      expect(find.text('No more rewards'), findsOneWidget);
      endState.dispose();
      endStore.dispose();
    });

    testWidgets('lazy chunk shows error when backend is not configured', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: _lazyChunkScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rewards failed'), findsOneWidget);
      expect(stateManager.get<String>('rewards.status'), 'error');

      stateManager.dispose();
      backendStore.dispose();
    });

    testWidgets('form controls validate and submit through backend connector', (
      tester,
    ) async {
      final connector = _RecordingBackendConnector(
        responses: <MiniProgramBackendResult>[
          MiniProgramBackendResult.success(
            endpoint: 'applications/submit',
            method: 'POST',
            data: const <String, dynamic>{'ok': true},
          ),
        ],
      );
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          backendConnector: connector,
          screenJson: _formScreen,
        ),
      );

      await tester.tap(find.text('Submit application'));
      await tester.pump();

      expect(connector.calls, isEmpty);
      expect(find.text('Check the highlighted fields.'), findsOneWidget);
      expect(find.text('This field is required.'), findsWidgets);

      await tester.enterText(find.byType(EditableText).at(0), 'Mehedi Hasan');
      await tester.enterText(
        find.byType(EditableText).at(1),
        'Scholarship essay',
      );
      await tester.tap(find.text('Choose a program').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('STEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undergraduate'));
      await tester.tap(find.text('I confirm this application is accurate'));
      await tester.pump();
      await tester.tap(find.text('Submit application'));
      await tester.pump();
      await tester.pump();

      expect(connector.calls, hasLength(1));
      expect(connector.calls.single.endpoint, 'applications/submit');
      expect(connector.calls.single.method, 'POST');
      expect(connector.calls.single.body, <String, dynamic>{
        'full_name': 'Mehedi Hasan',
        'essay': 'Scholarship essay',
        'program': 'stem',
        'level': 'undergraduate',
        'terms': true,
      });
      expect(find.text('Submitted'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      backendStore.dispose();
    });

    testWidgets('form submit shows no-API failure state', (tester) async {
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: _formScreen),
      );

      await tester.enterText(find.byType(EditableText).at(0), 'Mehedi Hasan');
      await tester.enterText(
        find.byType(EditableText).at(1),
        'Scholarship essay',
      );
      await tester.tap(find.text('Choose a program').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('STEM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undergraduate'));
      await tester.tap(find.text('I confirm this application is accurate'));
      await tester.pump();
      await tester.tap(find.text('Submit application'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Publisher API is not configured for mini-program "coupon".'),
        findsOneWidget,
      );

      backendStore.dispose();
    });

    testWidgets('toast and dialog actions render SDK-owned feedback', (
      tester,
    ) async {
      final backendStore = MiniProgramBackendStore();

      await tester.pumpWidget(
        _scopedApp(backendStore: backendStore, screenJson: _feedbackScreen),
      );

      await tester.tap(find.text('Show toast'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      await tester.tap(find.text('Show dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Continue?'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Continue?'), findsNothing);

      backendStore.dispose();
    });

    testWidgets('styled buttons render and dispatch actions', (tester) async {
      final backendStore = MiniProgramBackendStore();
      final stateManager = MpStateManager();
      final screenJson = _jsonMap(
        MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon_home': () => Mp.column(
              children: <MpNode>[
                Mp.button(
                  label: 'Memory add',
                  action: Mp.state.set('controls.memory', true),
                  height: 68,
                  backgroundColor: '#FF252525',
                  foregroundColor: '#FFF5F5F5',
                  borderColor: '#FF252525',
                  borderRadius: 999,
                ),
                Mp.iconButton(
                  'history',
                  semanticLabel: 'Open history',
                  action: Mp.state.set('controls.history', true),
                  color: '#FF9A9A9A',
                ),
              ],
            ),
          },
        ).buildScreensJson()['coupon_home']!,
      );

      await tester.pumpWidget(
        _scopedApp(
          backendStore: backendStore,
          stateManager: stateManager,
          screenJson: screenJson,
        ),
      );

      await tester.tap(find.text('Memory add'));
      await tester.pump();
      expect(stateManager.get<bool>('controls.memory'), isTrue);

      await tester.tap(find.bySemanticsLabel('Open history'));
      await tester.pump();
      expect(stateManager.get<bool>('controls.history'), isTrue);

      backendStore.dispose();
    });
  });
}
