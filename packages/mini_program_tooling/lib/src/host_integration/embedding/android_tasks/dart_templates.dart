import 'native_templates.dart';

String buildAndroidTasksDart() =>
    '$androidTasksGeneratedMarker\n'
    r'''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

const _androidTasks = MethodChannel('mini_program/android_tasks');

/// Pass to MiniProgramScope.navigationDelegate to opt into Android tasks.
/// Other platforms retain ordinary Flutter route navigation.
/// Android completes with null when the task opens/resumes, without a route result.
Future<T?> openMiniProgramInAndroidTask<T>(
  BuildContext context,
  MiniProgramLaunchRequest request,
  Widget page,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    final options = request.options;
    final route = options.routeBuilder?.call(context, request, page) as Route<T>? ??
        MaterialPageRoute<T>(
          builder: (_) => page,
          settings: options.routeSettings,
          fullscreenDialog: options.fullscreenDialog,
        );
    return Navigator.of(context, rootNavigator: options.useRootNavigator).push<T>(route);
  }
  // Runtime objects and route closures cannot cross Flutter engine boundaries.
  // Source/version selection belongs in buildHostMiniProgramConfig for each engine.
  if (request.initialData != null || request.version != null ||
      request.source != null || request.options.routeBuilder != null) {
    throw UnsupportedError(
      'Android tasks open by appId and host configuration. Per-launch initialData, '
      'source, version, and routeBuilder are not supported.',
    );
  }
  await _androidTasks.invokeMethod<void>('openMiniProgram', <String, Object?>{
    'appId': request.appId,
    'title': request.title ?? request.appId,
    'showAppBar': request.options.showAppBar,
    'backgroundColor': request.options.backgroundColor?.toARGB32() ?? 0xFFF8FAFC,
  });
  return null;
}

/// Root widget used only by the generated secondary Dart entrypoint.
/// Customize each engine's configuration in app_android_task_setup.dart.
class AndroidMiniProgramTaskApp extends StatefulWidget {
  const AndroidMiniProgramTaskApp({super.key, required this.config, this.theme});

  final MiniProgramConfig config;
  final ThemeData? theme;

  @override
  State<AndroidMiniProgramTaskApp> createState() => _AndroidMiniProgramTaskAppState();
}

class _AndroidMiniProgramTaskAppState extends State<AndroidMiniProgramTaskApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _androidTasks.setMethodCallHandler((call) async {
      if (call.method != 'handleBack') throw MissingPluginException();
      final navigator = _navigatorKey.currentState;
      // Pop owned Flutter panels or let the SDK's inner screen stack handle
      // Back first. Android returns to the retained host only at the root.
      return navigator != null && await navigator.maybePop();
    });
  }

  @override
  void dispose() {
    _androidTasks.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = Uri.parse(WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    if (route.pathSegments.length != 2 || route.pathSegments.first != 'mini-program' ||
        route.pathSegments.last.isEmpty) {
      throw StateError('Missing Android mini-program task launch request.');
    }
    final appId = route.pathSegments.last;
    final title = route.queryParameters['title'] ?? appId;
    final backgroundColor = Color(
      int.tryParse(route.queryParameters['backgroundColor'] ?? '') ?? 0xFFF8FAFC,
    );
    final taskHome = Builder(builder: (context) => Scaffold(
      appBar: route.queryParameters['showAppBar'] == 'false' ? null : AppBar(
        title: Text(title),
        leading: IconButton(
          tooltip: 'Return to host',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _androidTasks.invokeMethod<void>('showHost'),
        ),
      ),
      body: MiniProgramPage(
        miniProgramId: appId,
        title: title,
        runtime: MiniProgramScope.of(context).controller.runtime,
        showAppBar: false,
        backgroundColor: backgroundColor,
      ),
    ));
    return MiniProgramScope(
      config: widget.config,
      navigationDelegate: openMiniProgramInAndroidTask,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: title,
        debugShowCheckedModeBanner: false,
        theme: widget.theme,
        // Android's initial route carries our launch metadata, not a Flutter
        // navigation stack. Always create exactly one root page.
        onGenerateInitialRoutes: (_) => <Route<dynamic>>[
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => taskHome,
          ),
        ],
        routes: <String, WidgetBuilder>{'/': (_) => taskHome},
      ),
    );
  }
}
''';

String buildAndroidTaskHostSetup() => r'''
import 'package:flutter/widgets.dart';

import 'mini_program_android_tasks.dart';
import 'mini_program_host_setup.dart';

/// Host-owned setup for each mini-program Flutter engine. Created once.
///
/// Recreate host dependencies here or in buildHostMiniProgramConfig. Objects
/// from the main engine (including providers and in-memory login state) are
/// not shared. Keep persistent cache access safe across engines.
Future<void> runHostMiniProgramTask() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await buildHostMiniProgramConfig();
  runApp(AndroidMiniProgramTaskApp(config: config));
}
''';
