import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets('MiniProgramScope does not create MaterialApp internally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Plain child'),
        ),
      ),
    );

    expect(find.byType(MaterialApp), findsNothing);
    expect(find.text('Plain child'), findsOneWidget);
  });

  testWidgets('host app can use normal MaterialApp', (tester) async {
    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        child: const MaterialApp(home: Text('Host MaterialApp')),
      ),
    );

    expect(find.text('Host MaterialApp'), findsOneWidget);
  });

  testWidgets('host app can use MaterialApp.router', (tester) async {
    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        child: MaterialApp.router(
          routerDelegate: _StaticRouterDelegate(const Text('Router host')),
          routeInformationParser: _StaticRouteInformationParser(),
        ),
      ),
    );

    expect(find.text('Router host'), findsOneWidget);
  });

  testWidgets('of works from descendants and maybeOf returns null outside', (
    tester,
  ) async {
    MiniProgramScopeHandle? resolvedHandle;

    await tester.pumpWidget(
      Builder(
        builder: (outerContext) {
          expect(MiniProgramScope.maybeOf(outerContext), isNull);
          return MiniProgramScope(
            config: _buildConfig(),
            child: Builder(
              builder: (innerContext) {
                resolvedHandle = MiniProgramScope.of(innerContext);
                return const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('Scoped'),
                );
              },
            ),
          );
        },
      ),
    );

    expect(resolvedHandle, isNotNull);
  });

  testWidgets('of throws a clear error outside scope', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          MiniProgramScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    final exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      contains(
        'MiniProgramScope not found. Wrap your app with MiniProgramScope(config: buildMiniProgramConfig(), child: MyApp()).',
      ),
    );
  });

  testWidgets('does not do mini-program work before launch', (tester) async {
    StacInitializer.resetForTesting();
    final source = _CountingMiniProgramSource();
    final config = _CountingConfig(source: source);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MiniProgramScope(
        config: config,
        child: MaterialApp(
          navigatorObservers: <NavigatorObserver>[observer],
          home: const Text('Host only'),
        ),
      ),
    );

    expect(config.createRuntimeCount, 0);
    expect(source.loadManifestCount, 0);
    expect(source.loadScreenCount, 0);
    expect(observer.pushedRoutes, hasLength(1));
    expect(find.byType(MiniProgramPage), findsNothing);
    expect(find.byType(Overlay), findsOneWidget);
    expect(StacInitializer.isInitializedForTesting, isFalse);
  });

  testWidgets('runtime is lazy and reused across rebuilds', (tester) async {
    final config = _CountingConfig();
    final delegate = _RecordingNavigationDelegate();
    final navigationDelegate = delegate.handle;
    var rebuildCount = 0;

    Widget buildHost() {
      rebuildCount++;
      return MiniProgramScope(
        config: config,
        navigationDelegate: navigationDelegate,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  MiniProgramScope.of(
                    context,
                  ).openMiniProgram<void>(appId: 'profile_center');
                },
                child: Text('Open $rebuildCount'),
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildHost());
    await tester.pumpWidget(buildHost());

    expect(config.createRuntimeCount, 0);

    await tester.tap(find.text('Open 2'));
    await tester.pump();

    expect(config.createRuntimeCount, 1);
    expect(delegate.requests, hasLength(1));

    await tester.pumpWidget(buildHost());
    await tester.tap(find.text('Open 3'));
    await tester.pump();

    expect(config.createRuntimeCount, 1);
    expect(delegate.requests, hasLength(2));
  });

  testWidgets('owned config resources are disposed even without launch', (
    tester,
  ) async {
    final source = _DisposableMiniProgramSource();
    final backendConnector = _DisposableBackendConnector();
    final config = _buildConfig(
      source: source,
      backendConnector: backendConnector,
    );

    await tester.pumpWidget(
      MiniProgramScope(
        config: config,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Scoped'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    expect(source.disposeCount, 1);
    expect(backendConnector.disposeCount, 1);
  });

  testWidgets('injected controller is not disposed by MiniProgramScope', (
    tester,
  ) async {
    final controller = _CountingController(config: _buildConfig());

    await tester.pumpWidget(
      MiniProgramScope(
        controller: controller,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Scoped'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.disposeCount, 0);
    controller.dispose();
  });

  testWidgets('injected controller can be disposed when explicitly owned', (
    tester,
  ) async {
    final controller = _CountingController(config: _buildConfig());

    await tester.pumpWidget(
      MiniProgramScope(
        controller: controller,
        disposeController: true,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Scoped'),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.disposeCount, 1);
  });

  testWidgets('config is immutable after scope creation', (tester) async {
    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Scoped'),
        ),
      ),
    );

    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Scoped again'),
        ),
      ),
    );

    final exception = tester.takeException();
    expect(exception, isFlutterError);
    expect(
      exception.toString(),
      contains('MiniProgramScope configuration cannot change after creation.'),
    );
    expect(
      exception.toString(),
      contains(
        'MiniProgramScope(key: ValueKey(environment), config: config, child: MyApp()).',
      ),
    );
  });

  testWidgets('openMiniProgram pushes with normal Navigator', (tester) async {
    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(
          source: _FakeMiniProgramSource(
            screenJson: const <String, dynamic>{
              'type': 'scaffold',
              'body': <String, dynamic>{
                'type': 'center',
                'child': <String, dynamic>{
                  'type': 'text',
                  'data': 'Scoped launcher screen',
                },
              },
            },
          ),
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  MiniProgramScope.of(
                    context,
                  ).openMiniProgram<void>(appId: 'profile_center');
                },
                child: const Text('Launch'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();

    expect(find.text('Scoped launcher screen'), findsOneWidget);
  });

  testWidgets('launch options configure the default MaterialPageRoute', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        child: MaterialApp(
          navigatorObservers: <NavigatorObserver>[observer],
          home: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  MiniProgramScope.of(context).openMiniProgram<void>(
                    appId: 'profile_center',
                    options: const MiniProgramLaunchOptions(
                      fullscreenDialog: true,
                      routeSettings: RouteSettings(name: '/mini/profile'),
                    ),
                  );
                },
                child: const Text('Launch'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pump();

    final route = observer.pushedRoutes.last;
    expect(route.settings.name, '/mini/profile');
    expect((route as PageRoute<void>).fullscreenDialog, isTrue);
  });

  testWidgets('launch routeBuilder overrides default route', (tester) async {
    var routeBuilderCalled = false;

    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  MiniProgramScope.of(context).openMiniProgram<void>(
                    appId: 'profile_center',
                    options: MiniProgramLaunchOptions(
                      routeBuilder: (context, request, page) {
                        routeBuilderCalled = true;
                        expect(request.appId, 'profile_center');
                        return PageRouteBuilder<void>(
                          pageBuilder: (_, _, _) => page,
                        );
                      },
                    ),
                  );
                },
                child: const Text('Launch'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pump();

    expect(routeBuilderCalled, isTrue);
  });

  testWidgets('custom navigation delegate bypasses default push', (
    tester,
  ) async {
    final delegate = _RecordingNavigationDelegate(result: 'handled');
    String? result;

    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        navigationDelegate: delegate.handle,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await MiniProgramScope.of(context)
                      .openMiniProgram<String>(
                        appId: 'profile_center',
                        initialData: const <String, dynamic>{'source': 'test'},
                        version: '1.0.0',
                        source: Uri.parse('app://test'),
                      );
                },
                child: const Text('Launch'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pump();

    expect(result, 'handled');
    expect(delegate.requests.single.appId, 'profile_center');
    expect(delegate.requests.single.initialData, <String, dynamic>{
      'source': 'test',
    });
    expect(delegate.requests.single.version, '1.0.0');
    expect(delegate.requests.single.source, Uri.parse('app://test'));
    expect(find.byType(MiniProgramPage), findsNothing);
  });

  testWidgets('MiniProgramLauncher opens through MiniProgramScope', (
    tester,
  ) async {
    final delegate = _RecordingNavigationDelegate();

    await tester.pumpWidget(
      MiniProgramScope(
        config: _buildConfig(),
        navigationDelegate: delegate.handle,
        child: const MaterialApp(
          home: MiniProgramLauncher(
            appId: 'profile_center',
            child: Text('Open Mini Program'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Mini Program'));
    await tester.pump();

    expect(delegate.requests.single.appId, 'profile_center');
  });
}

MiniProgramConfig _buildConfig({
  MiniProgramSource? source,
  MiniProgramBackendConnector? backendConnector,
}) {
  return MiniProgramConfig(
    sdkVersion: '1.0.0',
    source:
        source ??
        _FakeMiniProgramSource(
          screenJson: const <String, dynamic>{'type': 'text', 'data': 'Loaded'},
        ),
    hostBridge: _FakeHostBridge(),
    capabilityRegistry: CapabilityRegistry(const <Capability>[
      Capability.analytics,
    ]),
    backendConnector: backendConnector,
  );
}

MiniProgramManifest _buildManifest() {
  return const MiniProgramManifest(
    id: 'profile_center',
    version: '1.0.0',
    entry: 'profile_center_home',
    contractVersion: '1.0.0',
    sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
    requiredCapabilities: <Capability>[Capability.analytics],
  );
}

class _CountingConfig extends MiniProgramConfig {
  _CountingConfig({MiniProgramSource? source})
    : super(
        sdkVersion: '1.0.0',
        source:
            source ??
            _FakeMiniProgramSource(
              screenJson: const <String, dynamic>{
                'type': 'text',
                'data': 'Loaded',
              },
            ),
        hostBridge: _FakeHostBridge(),
        capabilityRegistry: CapabilityRegistry(const <Capability>[
          Capability.analytics,
        ]),
      );

  final List<Object?> _createRuntimeCalls = <Object?>[];

  int get createRuntimeCount => _createRuntimeCalls.length;

  @override
  MiniProgramRuntime createRuntime() {
    _createRuntimeCalls.add(null);
    return super.createRuntime();
  }
}

class _CountingController extends MiniProgramController {
  _CountingController({required super.config});

  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

class _RecordingNavigationDelegate {
  _RecordingNavigationDelegate({this.result});

  final Object? result;
  final List<MiniProgramLaunchRequest> requests = <MiniProgramLaunchRequest>[];
  final List<Widget> pages = <Widget>[];

  Future<T?> handle<T>(
    BuildContext context,
    MiniProgramLaunchRequest request,
    Widget page,
  ) async {
    requests.add(request);
    pages.add(page);
    return result as T?;
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

class _FakeMiniProgramSource implements MiniProgramSource {
  const _FakeMiniProgramSource({required this.screenJson});

  final Map<String, dynamic> screenJson;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    return _buildManifest();
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    return screenJson;
  }
}

class _CountingMiniProgramSource extends _FakeMiniProgramSource {
  _CountingMiniProgramSource()
    : super(
        screenJson: const <String, dynamic>{'type': 'text', 'data': 'Loaded'},
      );

  int loadManifestCount = 0;
  int loadScreenCount = 0;

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    loadManifestCount++;
    return super.loadManifest(miniProgramId);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async {
    loadScreenCount++;
    return super.loadScreen(
      miniProgramId: miniProgramId,
      version: version,
      screenId: screenId,
    );
  }
}

class _DisposableMiniProgramSource extends _FakeMiniProgramSource
    implements DisposableMiniProgramSource {
  _DisposableMiniProgramSource()
    : super(
        screenJson: const <String, dynamic>{'type': 'text', 'data': 'Loaded'},
      );

  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
  }
}

class _DisposableBackendConnector
    implements DisposableMiniProgramBackendConnector {
  int disposeCount = 0;

  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    return MiniProgramBackendResult.success(
      requestId: request.requestId,
      endpoint: request.endpoint,
      method: request.method,
    );
  }

  @override
  void dispose() {
    disposeCount++;
  }
}

class _FakeHostBridge implements HostBridge {
  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.openNativeScreen);
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.success(actionName: ActionNames.callSecureApi);
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    return HostActionResult.success(actionName: ActionNames.trackEvent);
  }
}

class _StaticRouteInformationParser
    extends RouteInformationParser<RouteInformation> {
  @override
  Future<RouteInformation> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    return routeInformation;
  }
}

class _StaticRouterDelegate extends RouterDelegate<RouteInformation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteInformation> {
  _StaticRouterDelegate(this.child);

  final Widget child;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  RouteInformation? get currentConfiguration {
    return RouteInformation(uri: Uri.parse('/'));
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[MaterialPage<void>(child: child)],
      onDidRemovePage: (_) {},
    );
  }

  @override
  Future<void> setNewRoutePath(RouteInformation configuration) async {}
}
