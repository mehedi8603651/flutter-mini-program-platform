import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'phone_ai/phone_ai_test_workspace.dart';
import 'phone_ai/host_ai_catalog.dart';
import 'phone_ai/host_ai_coordinator.dart';

const MethodChannel _miniProgramWindowChannel = MethodChannel(
  'dev.miniprogram.mp_only_host/mini_program_window',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MpOnlyHostApp());
}

/// Dart entrypoint used by each Android Activity that hosts a mini-program.
/// It is intentionally separate from [main] so the host and every mini-program
/// run in separate Flutter engines and Android tasks.
@pragma('vm:entry-point')
Future<void> miniProgramMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final request = _miniProgramRequestFromRoute(
    WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );
  runApp(_MiniProgramWindowApp(request: request));
}

MiniProgramConfig _buildMiniProgramConfig({
  MiniProgramInteractionController? interactionController,
}) {
  return MiniProgramConfig(
    sdkVersion: '1.0.0',
    source: const _BundledMpSource(),
    interactionController: interactionController,
    hostBridge: const _MpOnlyHostBridge(),
    capabilityRegistry: CapabilityRegistry(const <CapabilityId>[
      CapabilityIds.analytics,
    ]),
    cacheBundle: MiniProgramCacheBundle.inMemory(),
  );
}

_MiniProgramRequest _miniProgramRequestFromRoute(String route) {
  final uri = Uri.tryParse(route);
  final segments = uri?.pathSegments ?? const <String>[];
  final appId = segments.length >= 2 && segments.first == 'mini-program'
      ? segments[1]
      : 'mp_profile_center';
  final requestedTitle = uri?.queryParameters['title']?.trim();
  final title =
      requestedTitle == null ||
          requestedTitle.isEmpty ||
          requestedTitle == appId
      ? _miniProgramTitles[appId] ?? appId
      : requestedTitle;
  return _MiniProgramRequest(appId: appId, title: title);
}

class MpOnlyHostApp extends StatefulWidget {
  const MpOnlyHostApp({super.key, this.enableAi = phoneAiTestEnabled});

  final bool enableAi;

  @override
  State<MpOnlyHostApp> createState() => _MpOnlyHostAppState();
}

class _MpOnlyHostAppState extends State<MpOnlyHostApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _interactionChannel = MiniProgramInteractionChannel();
  late final _catalog = HostAiCatalog(
    titles: _miniProgramTitles,
    openMiniProgram: (appId) => _miniProgramWindowChannel.invokeMethod<void>(
      'openMiniProgram',
      {'appId': appId, 'title': _miniProgramTitles[appId]!},
    ),
  );
  HostAiCoordinator? _ai;

  @override
  void initState() {
    super.initState();
    if (widget.enableAi) {
      _ai = HostAiCoordinator(
        catalog: _catalog,
        miniProgramDispatch: _interactionChannel.dispatch,
      );
      unawaited(_ai!.bind());
    }
  }

  @override
  void dispose() {
    _ai?.dispose();
    _catalog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MiniProgramScope(
      config: _buildMiniProgramConfig(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        builder: _ai == null
            ? null
            : (context, child) => PhoneAiTestWorkspace(
                appId: HostAiCatalog.appId,
                isHost: true,
                dispatch: _catalog.dispatch,
                session: _ai!.runner,
                navigatorKey: _navigatorKey,
                child: child ?? const SizedBox.shrink(),
              ),
        title: 'Mp-only Host',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5E)),
        ),
        home: _HomePage(catalog: _catalog),
      ),
    );
  }
}

const _miniProgramTitles = <String, String>{
  'mp_profile_center': 'Mp Profile Center',
  'mp_orders': 'Mp Orders',
  'mp_ai_food_demo': 'AI Food Demo',
  'mp_ai_controls_demo': 'AI Controls Demo',
  'mp_wallet': 'Mp Wallet',
};

class _HomePage extends StatelessWidget {
  const _HomePage({required this.catalog});

  final HostAiCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mp-only Host')),
      body: SafeArea(
        top: false,
        child: _MiniProgramCatalog(
          catalog: catalog,
          onOpen: (appId) => _openMiniProgramWindow(
            context,
            appId: appId,
            title: _miniProgramTitles[appId]!,
          ),
        ),
      ),
    );
  }
}

class _MiniProgramCatalog extends StatelessWidget {
  const _MiniProgramCatalog({required this.onOpen, required this.catalog});

  final ValueChanged<String> onOpen;
  final HostAiCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => catalog.invalidate(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          catalog.invalidate();
          return false;
        },
        child: Center(
          key: catalog.viewportKey,
          child: SingleChildScrollView(
            controller: catalog.scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final entry in _miniProgramTitles.entries) ...[
                  _MiniProgramButton(
                    key: catalog.buttonKeys[entry.key],
                    title: entry.value,
                    onPressed: () => onOpen(entry.key),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProgramButton extends StatelessWidget {
  const _MiniProgramButton({
    super.key,
    required this.title,
    required this.onPressed,
  });

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text('Open $title'));
  }
}

Future<void> _openMiniProgramWindow(
  BuildContext context, {
  required String appId,
  required String title,
}) async {
  try {
    await _miniProgramWindowChannel.invokeMethod<void>('openMiniProgram', {
      'appId': appId,
      'title': title,
    });
  } on PlatformException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open mini-program: ${error.message}')),
    );
  } on MissingPluginException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This host build does not include Android mini-program windows.',
        ),
      ),
    );
  }
}

class _MiniProgramWindowApp extends StatefulWidget {
  const _MiniProgramWindowApp({required this.request});

  final _MiniProgramRequest request;

  @override
  State<_MiniProgramWindowApp> createState() => _MiniProgramWindowAppState();
}

class _MiniProgramWindowAppState extends State<_MiniProgramWindowApp> {
  final _interactions = MiniProgramInteractionController(
    onExit: () => _miniProgramWindowChannel.invokeMethod<void>('showHost'),
  );
  final _interactionChannel = MiniProgramInteractionChannel();
  final _navigatorKey = GlobalKey<NavigatorState>();
  HostAiSessionClient? _ai;

  Future<void> _back() async {
    // Use the same SDK screen/popup Back chain as Android Back before exiting.
    final handled = await _navigatorKey.currentState?.maybePop() ?? false;
    if (mounted && !handled) {
      await _miniProgramWindowChannel.invokeMethod<void>('showHost');
    }
  }

  @override
  void initState() {
    super.initState();
    if (phoneAiTestEnabled) {
      _ai = HostAiSessionClient(appId: widget.request.appId);
      unawaited(_ai!.bind());
    }
    unawaited(_interactionChannel.bind(_interactions));
    _miniProgramWindowChannel.setMethodCallHandler((call) async {
      if (call.method != 'handleBack') throw MissingPluginException();
      final navigator = _navigatorKey.currentState;
      return navigator != null && await navigator.maybePop();
    });
  }

  @override
  void dispose() {
    _ai?.dispose();
    unawaited(_interactionChannel.dispose());
    _interactions.dispose();
    _miniProgramWindowChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final taskHome = Builder(
      builder: (context) {
        final runtime = MiniProgramScope.of(context).controller.runtime;
        return Scaffold(
          appBar: AppBar(
            title: Text(request.title),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: _back,
              icon: const Icon(Icons.arrow_back),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Return to host',
                onPressed: () =>
                    _miniProgramWindowChannel.invokeMethod<void>('showHost'),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: MiniProgramPage(
            miniProgramId: request.appId,
            title: request.title,
            runtime: runtime,
            showAppBar: false,
          ),
        );
      },
    );
    return MiniProgramScope(
      config: _buildMiniProgramConfig(interactionController: _interactions),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        builder: phoneAiTestEnabled
            ? (context, child) => PhoneAiTestWorkspace(
                appId: request.appId,
                dispatch: _interactionChannel.dispatch,
                session: _ai,
                navigatorKey: _navigatorKey,
                child: child ?? const SizedBox.shrink(),
              )
            : null,
        title: request.title,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5E)),
        ),
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

class _MiniProgramRequest {
  const _MiniProgramRequest({required this.appId, required this.title});

  final String appId;
  final String title;
}

class _BundledMpSource implements MiniProgramSource {
  const _BundledMpSource();

  static const Set<String> _supportedAppIds = <String>{
    'mp_profile_center',
    'mp_orders',
    'mp_wallet',
    'mp_ai_food_demo',
    'mp_ai_controls_demo',
  };
  static const String _root = 'assets/mini_programs/mp_profile_center';
  String _assetRoot(String appId) => switch (appId) {
    'mp_ai_food_demo' || 'mp_ai_controls_demo' => 'assets/mini_programs/$appId',
    _ => _root,
  };

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    if (!_supportedAppIds.contains(miniProgramId)) {
      throw StateError('Unknown bundled mini-program "$miniProgramId".');
    }
    final manifest = MiniProgramManifest.fromJson(
      await _loadJson('${_assetRoot(miniProgramId)}/manifest.json'),
    );
    return manifest.copyWith(id: miniProgramId);
  }

  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) {
    if (!_supportedAppIds.contains(miniProgramId)) {
      throw StateError('Unknown bundled mini-program "$miniProgramId".');
    }
    return _loadJson('${_assetRoot(miniProgramId)}/screens/$screenId.json');
  }

  Future<Map<String, dynamic>> _loadJson(String assetPath) async {
    final decoded = jsonDecode(await rootBundle.loadString(assetPath));
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Asset "$assetPath" is not a JSON object.');
    }
    return decoded;
  }
}

class _MpOnlyHostBridge implements HostBridge {
  const _MpOnlyHostBridge();

  @override
  Future<HostActionResult> callSecureApi(CallSecureApiActionPayload payload) {
    return Future<HostActionResult>.value(
      HostActionResult.failed(
        actionName: ActionNames.callSecureApi,
        message: 'Secure API is not enabled in the Mp-only reference host.',
      ),
    );
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) {
    return Future<HostActionResult>.value(
      HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Native navigation is not enabled in the Mp-only host.',
      ),
    );
  }

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) {
    return Future<HostActionResult>.value(
      HostActionResult.success(
        actionName: ActionNames.trackEvent,
        message: 'Tracked Mp-only host event.',
        data: payload.properties,
      ),
    );
  }
}
