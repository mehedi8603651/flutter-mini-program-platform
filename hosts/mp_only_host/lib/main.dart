import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

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

MiniProgramConfig _buildMiniProgramConfig() {
  return MiniProgramConfig(
    sdkVersion: '1.0.0',
    source: const _BundledMpSource(),
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
  final title = uri?.queryParameters['title'] ?? 'Mp Profile Center';
  return _MiniProgramRequest(appId: appId, title: title);
}

class MpOnlyHostApp extends StatelessWidget {
  const MpOnlyHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MiniProgramScope(
      config: _buildMiniProgramConfig(),
      child: MaterialApp(
        title: 'Mp-only Host',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5E)),
        ),
        home: const _HomePage(),
      ),
    );
  }
}

const _miniProgramTitles = <String, String>{
  'mp_profile_center': 'Mp Profile Center',
  'mp_orders': 'Mp Orders',
  'mp_wallet': 'Mp Wallet',
};

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mp-only Host')),
      body: SafeArea(
        top: false,
        child: _MiniProgramCatalog(
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
  const _MiniProgramCatalog({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _MiniProgramButton(
              title: 'Mp Profile Center',
              onPressed: () => onOpen('mp_profile_center'),
            ),
            const SizedBox(height: 12),
            _MiniProgramButton(
              title: 'Mp Orders',
              onPressed: () => onOpen('mp_orders'),
            ),
            const SizedBox(height: 12),
            _MiniProgramButton(
              title: 'Mp Wallet',
              onPressed: () => onOpen('mp_wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniProgramButton extends StatelessWidget {
  const _MiniProgramButton({required this.title, required this.onPressed});

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

class _MiniProgramWindowApp extends StatelessWidget {
  const _MiniProgramWindowApp({required this.request});

  final _MiniProgramRequest request;

  @override
  Widget build(BuildContext context) {
    return MiniProgramScope(
      config: _buildMiniProgramConfig(),
      child: MaterialApp(
        title: request.title,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5E)),
        ),
        home: Builder(
          builder: (context) {
            final runtime = MiniProgramScope.of(context).controller.runtime;
            return Scaffold(
              appBar: AppBar(
                title: Text(request.title),
                leading: IconButton(
                  tooltip: 'Return to host',
                  onPressed: () =>
                      _miniProgramWindowChannel.invokeMethod<void>('showHost'),
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Close mini-program',
                    onPressed: () => _miniProgramWindowChannel
                        .invokeMethod<void>('showHost'),
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
        ),
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
  };
  static const String _root = 'assets/mini_programs/mp_profile_center';

  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async {
    if (!_supportedAppIds.contains(miniProgramId)) {
      throw StateError('Unknown bundled mini-program "$miniProgramId".');
    }
    final manifest = MiniProgramManifest.fromJson(
      await _loadJson('$_root/manifest.json'),
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
    return _loadJson('$_root/screens/$screenId.json');
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
