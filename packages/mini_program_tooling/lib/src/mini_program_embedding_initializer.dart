import 'dart:io';

import 'package:path/path.dart' as p;

class MiniProgramEmbeddingInitRequest {
  const MiniProgramEmbeddingInitRequest({
    required this.projectRootPath,
    this.repoRootPath,
    this.hostAppId,
    this.hostVersion,
    this.nativeRoutePath = '/native/profile-editor',
    this.force = false,
  });

  final String projectRootPath;
  final String? repoRootPath;
  final String? hostAppId;
  final String? hostVersion;
  final String nativeRoutePath;
  final bool force;
}

class MiniProgramEmbeddingInitResult {
  const MiniProgramEmbeddingInitResult({
    required this.projectRootPath,
    required this.repoRootPath,
    required this.packageName,
    required this.hostAppId,
    required this.hostVersion,
    required this.nativeRoutePath,
    required this.createdPaths,
  });

  final String projectRootPath;
  final String? repoRootPath;
  final String packageName;
  final String hostAppId;
  final String hostVersion;
  final String nativeRoutePath;
  final List<String> createdPaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'projectRootPath': projectRootPath,
    'repoRootPath': repoRootPath,
    'packageName': packageName,
    'hostAppId': hostAppId,
    'hostVersion': hostVersion,
    'nativeRoutePath': nativeRoutePath,
    'createdPaths': createdPaths,
  };
}

class MiniProgramEmbeddingInitException implements Exception {
  const MiniProgramEmbeddingInitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramEmbeddingInitializer {
  const MiniProgramEmbeddingInitializer();

  static const String _miniProgramSdkConstraint = '^0.1.0';
  static const String _miniProgramContractsConstraint = '^0.1.0';

  Future<MiniProgramEmbeddingInitResult> initialize(
    MiniProgramEmbeddingInitRequest request,
  ) async {
    final projectRootPath = p.normalize(p.absolute(request.projectRootPath));
    final repoRootPath = request.repoRootPath == null
        ? null
        : p.normalize(p.absolute(request.repoRootPath!));

    final projectRootDir = Directory(projectRootPath);
    if (!await projectRootDir.exists()) {
      throw MiniProgramEmbeddingInitException(
        'Project root does not exist: $projectRootPath',
      );
    }

    final pubspecPath = p.join(projectRootPath, 'pubspec.yaml');
    final libDirPath = p.join(projectRootPath, 'lib');
    final pubspecFile = File(pubspecPath);
    if (!await pubspecFile.exists()) {
      throw MiniProgramEmbeddingInitException(
        'Flutter project is missing pubspec.yaml: $projectRootPath',
      );
    }
    if (!await Directory(libDirPath).exists()) {
      throw MiniProgramEmbeddingInitException(
        'Flutter project is missing lib/: $projectRootPath',
      );
    }

    final pubspecSource = await pubspecFile.readAsString();
    final packageName = _extractPubspecField(
      pubspecSource,
      'name',
      fallbackValue: p.basename(projectRootPath),
    );
    final resolvedHostAppId = request.hostAppId?.trim().isNotEmpty == true
        ? request.hostAppId!.trim()
        : packageName;
    final resolvedHostVersion = request.hostVersion?.trim().isNotEmpty == true
        ? request.hostVersion!.trim()
        : _extractVersion(pubspecSource);
    final normalizedRoutePath = _normalizeRoutePath(request.nativeRoutePath);
    final updatedPubspecSource = _ensureHostedDependencies(pubspecSource);

    final integrationRootPath = p.join(projectRootPath, 'lib', 'mini_program');
    final integrationRootDir = Directory(integrationRootPath);

    final managedFiles = <String, String>{
      p.join(integrationRootPath, 'mini_program_routes.dart'): _buildRoutes(
        nativeRoutePath: normalizedRoutePath,
      ),
      p.join(integrationRootPath, 'app_host_bridge.dart'): _buildHostBridge(
        logPrefix: resolvedHostAppId,
      ),
      p.join(
        integrationRootPath,
        'mini_program_runtime_setup.dart',
      ): _buildRuntimeSetup(
        hostAppId: resolvedHostAppId,
        hostVersion: resolvedHostVersion,
      ),
      p.join(integrationRootPath, 'native_profile_editor_page.dart'):
          _buildNativeProfileEditorPage(),
      p.join(integrationRootPath, 'mini_program_launcher.dart'):
          _buildLauncher(),
      p.join(integrationRootPath, 'mini_program_app_shell.dart'):
          _buildAppShell(),
      p.join(integrationRootPath, 'mini_program.dart'): _buildBarrel(),
      p.join(integrationRootPath, 'README.md'): _buildReadme(
        packageName: packageName,
        repoRootPath: repoRootPath,
        hostAppId: resolvedHostAppId,
        hostVersion: resolvedHostVersion,
        nativeRoutePath: normalizedRoutePath,
      ),
    };
    managedFiles.addAll(
      _buildPlatformIntegrationFiles(projectRootPath: projectRootPath),
    );

    if (await integrationRootDir.exists() &&
        !request.force &&
        await _directoryHasEntries(integrationRootDir)) {
      throw MiniProgramEmbeddingInitException(
        'Embedding adapter already exists: $integrationRootPath '
        '(use --force to overwrite scaffold-managed files)',
      );
    }

    await integrationRootDir.create(recursive: true);

    final createdPaths = <String>[];
    if (updatedPubspecSource != pubspecSource) {
      await pubspecFile.writeAsString(updatedPubspecSource);
      createdPaths.add(pubspecFile.path);
    }
    for (final entry in managedFiles.entries) {
      final file = File(entry.key);
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
      createdPaths.add(file.path);
    }

    return MiniProgramEmbeddingInitResult(
      projectRootPath: projectRootPath,
      repoRootPath: repoRootPath,
      packageName: packageName,
      hostAppId: resolvedHostAppId,
      hostVersion: resolvedHostVersion,
      nativeRoutePath: normalizedRoutePath,
      createdPaths: createdPaths,
    );
  }

  Future<bool> _directoryHasEntries(Directory directory) async {
    await for (final _ in directory.list(followLinks: false)) {
      return true;
    }

    return false;
  }

  String _extractPubspecField(
    String source,
    String fieldName, {
    required String fallbackValue,
  }) {
    final match = RegExp(
      '^\\s*$fieldName\\s*:\\s*([^\\r\\n#]+)',
      multiLine: true,
    ).firstMatch(source);
    if (match == null) {
      return fallbackValue;
    }

    return match.group(1)?.trim().replaceAll("'", '') ?? fallbackValue;
  }

  String _extractVersion(String source) {
    final rawVersion = _extractPubspecField(
      source,
      'version',
      fallbackValue: '1.0.0',
    );
    return rawVersion.split('+').first.trim();
  }

  String _normalizeRoutePath(String rawRoutePath) {
    final trimmed = rawRoutePath.trim();
    if (trimmed.isEmpty) {
      throw const MiniProgramEmbeddingInitException(
        'Native route path must not be blank.',
      );
    }

    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  String _ensureHostedDependencies(String source) {
    final normalizedSource = source.replaceAll('\r\n', '\n');
    final lines = normalizedSource.split('\n');
    final dependenciesHeaderIndex = lines.indexWhere(
      (line) => line.trim() == 'dependencies:',
    );

    if (dependenciesHeaderIndex == -1) {
      final suffix = normalizedSource.endsWith('\n') || normalizedSource.isEmpty
          ? ''
          : '\n';
      return '$normalizedSource${suffix}dependencies:\n'
          '  mini_program_sdk: $_miniProgramSdkConstraint\n'
          '  mini_program_contracts: $_miniProgramContractsConstraint\n';
    }

    var dependenciesEndIndex = dependenciesHeaderIndex + 1;
    while (dependenciesEndIndex < lines.length) {
      final line = lines[dependenciesEndIndex];
      if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*:\s*$').hasMatch(line)) {
        break;
      }
      dependenciesEndIndex += 1;
    }

    final sectionLines = lines.sublist(
      dependenciesHeaderIndex + 1,
      dependenciesEndIndex,
    );
    final rebuiltSectionLines = <String>[];
    final preservedPackages = <String>{};

    for (var index = 0; index < sectionLines.length; index++) {
      final line = sectionLines[index];
      final packageMatch = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
      if (packageMatch == null) {
        rebuiltSectionLines.add(line);
        continue;
      }

      final packageName = packageMatch.group(1)!;
      final shouldReplace =
          packageName == 'mini_program_sdk' ||
          packageName == 'mini_program_contracts';

      final blockLines = <String>[line];
      while (index + 1 < sectionLines.length &&
          !RegExp(r'^  [A-Za-z0-9_]+:').hasMatch(sectionLines[index + 1])) {
        index += 1;
        blockLines.add(sectionLines[index]);
      }

      if (!shouldReplace) {
        rebuiltSectionLines.addAll(blockLines);
        continue;
      }

      preservedPackages.add(packageName);
      rebuiltSectionLines.add(
        packageName == 'mini_program_sdk'
            ? '  mini_program_sdk: $_miniProgramSdkConstraint'
            : '  mini_program_contracts: $_miniProgramContractsConstraint',
      );
    }

    if (!preservedPackages.contains('mini_program_sdk')) {
      rebuiltSectionLines.add('  mini_program_sdk: $_miniProgramSdkConstraint');
    }
    if (!preservedPackages.contains('mini_program_contracts')) {
      rebuiltSectionLines.add(
        '  mini_program_contracts: $_miniProgramContractsConstraint',
      );
    }

    final rebuiltLines = <String>[
      ...lines.sublist(0, dependenciesHeaderIndex + 1),
      ...rebuiltSectionLines,
      ...lines.sublist(dependenciesEndIndex),
    ];
    return rebuiltLines.join('\n');
  }

  String _buildRoutes({required String nativeRoutePath}) {
    return '''
abstract final class MiniProgramRoutes {
  static const String profileEditorAlias = 'profile_editor';
  static const String nativeProfileEditor = '$nativeRoutePath';
}
''';
  }

  String _buildHostBridge({required String logPrefix}) {
    return '''
import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program_routes.dart';

class AppHostBridge implements HostBridge {
  AppHostBridge({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  static const Map<String, String> _routeAliases = <String, String>{
    MiniProgramRoutes.profileEditorAlias: MiniProgramRoutes.nativeProfileEditor,
  };

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    debugPrint(
      '[$logPrefix][analytics] \${payload.name} \${payload.properties}',
    );
    return HostActionResult.success(
      actionName: ActionNames.trackEvent,
      message: 'Tracked event "\${payload.name}".',
      data: payload.properties,
    );
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Navigator not available.',
      );
    }

    try {
      final routeName = _routeAliases[payload.route] ?? payload.route;
      final result = await navigator.pushNamed<Object?>(
        routeName,
        arguments: payload.args,
      );

      if (payload.expectResult && result == null) {
        return HostActionResult.cancelled(
          actionName: ActionNames.openNativeScreen,
          message: 'Native screen closed without returning a result.',
        );
      }

      return HostActionResult.success(
        actionName: ActionNames.openNativeScreen,
        message: 'Opened native screen "\$routeName".',
        data: result is Map<String, dynamic>
            ? result
            : <String, dynamic>{'route': routeName},
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[$logPrefix][ERROR] Failed to open native route "\${payload.route}". '
        'error=\$error\\n\$stackTrace',
      );
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Failed to open native screen "\${payload.route}".',
      );
    }
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.failed(
      actionName: ActionNames.callSecureApi,
      message: 'secure_api is not enabled in this lean embedding setup.',
    );
  }
}
''';
  }

  String _buildLauncher() {
    return '''
import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

Future<T?> openAppMiniProgram<T>(
  BuildContext context, {
  required String miniProgramId,
  String? title,
  MiniProgramRuntime? runtime,
  bool useRootNavigator = false,
  MiniProgramRouteBuilder<T>? routeBuilder,
}) {
  return openMiniProgram<T>(
    context,
    miniProgramId: miniProgramId,
    title: title,
    runtime: runtime,
    useRootNavigator: useRootNavigator,
    routeBuilder: routeBuilder,
  );
}

class AppMiniProgramLauncherButton extends StatelessWidget {
  const AppMiniProgramLauncherButton({
    super.key,
    required this.miniProgramId,
    required this.child,
    this.title,
    this.runtime,
    this.icon,
    this.style,
    this.useRootNavigator = false,
    this.routeBuilder,
  });

  final String miniProgramId;
  final Widget child;
  final String? title;
  final MiniProgramRuntime? runtime;
  final Widget? icon;
  final ButtonStyle? style;
  final bool useRootNavigator;
  final MiniProgramRouteBuilder<void>? routeBuilder;

  @override
  Widget build(BuildContext context) {
    return MiniProgramLauncherButton(
      miniProgramId: miniProgramId,
      title: title,
      runtime: runtime,
      icon: icon,
      style: style,
      useRootNavigator: useRootNavigator,
      routeBuilder: routeBuilder,
      child: child,
    );
  }
}
''';
  }

  String _buildAppShell() {
    return '''
import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program_routes.dart';
import 'mini_program_runtime_setup.dart';
import 'native_profile_editor_page.dart';

class MiniProgramAppShell extends StatefulWidget {
  const MiniProgramAppShell({
    super.key,
    required this.home,
    this.title = '',
    this.initialRoute,
    this.routes = const <String, WidgetBuilder>{},
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.builder,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.locale,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
    this.debugShowCheckedModeBanner = true,
  });

  final Widget home;
  final String title;
  final String? initialRoute;
  final Map<String, WidgetBuilder> routes;
  final RouteFactory? onGenerateRoute;
  final RouteFactory? onUnknownRoute;
  final List<NavigatorObserver> navigatorObservers;
  final TransitionBuilder? builder;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode? themeMode;
  final Locale? locale;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Iterable<Locale> supportedLocales;
  final bool debugShowCheckedModeBanner;

  @override
  State<MiniProgramAppShell> createState() => _MiniProgramAppShellState();
}

class _MiniProgramAppShellState extends State<MiniProgramAppShell> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final MiniProgramRuntime _runtime;

  @override
  void initState() {
    super.initState();
    _runtime = buildMiniProgramRuntime(_navigatorKey);
  }

  Route<dynamic>? _handleGeneratedRoutes(RouteSettings settings) {
    if (settings.name == MiniProgramRoutes.nativeProfileEditor) {
      final args =
          (settings.arguments as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      return MaterialPageRoute<void>(
        builder: (_) => NativeProfileEditorPage(initialArgs: args),
        settings: settings,
      );
    }

    return widget.onGenerateRoute?.call(settings);
  }

  @override
  Widget build(BuildContext context) {
    return MiniProgramRuntimeScope(
      runtime: _runtime,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: widget.title,
        home: widget.home,
        initialRoute: widget.initialRoute,
        routes: widget.routes,
        onGenerateRoute: _handleGeneratedRoutes,
        onUnknownRoute: widget.onUnknownRoute,
        navigatorObservers: widget.navigatorObservers,
        builder: widget.builder,
        theme: widget.theme,
        darkTheme: widget.darkTheme,
        themeMode: widget.themeMode ?? ThemeMode.system,
        locale: widget.locale,
        localizationsDelegates: widget.localizationsDelegates,
        supportedLocales: widget.supportedLocales,
        debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
      ),
    );
  }
}
''';
  }

  String _buildBarrel() {
    return '''
export 'mini_program_app_shell.dart';
export 'mini_program_launcher.dart';
export 'mini_program_routes.dart';
''';
  }

  String _buildRuntimeSetup({
    required String hostAppId,
    required String hostVersion,
  }) {
    return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'app_host_bridge.dart';

const String _hostAppId = '$hostAppId';
const String _sdkVersion = '1.0.0';
const String _hostVersion = '$hostVersion';

const Set<Capability> _supportedCapabilities = <Capability>{
  Capability.analytics,
  Capability.nativeNavigation,
};

MiniProgramRuntime buildMiniProgramRuntime(
  GlobalKey<NavigatorState> navigatorKey,
) {
  final locale = WidgetsBinding.instance.platformDispatcher.locale;

  return MiniProgramRuntime(
    sdkVersion: _sdkVersion,
    source: HttpMiniProgramSource.fromDeliveryContext(
      apiBaseUri: Uri.parse(_resolveBackendBaseUrl()),
      deliveryContext: MiniProgramDeliveryContext(
        hostApp: _hostAppId,
        sdkVersion: _sdkVersion,
        hostVersion: _hostVersion,
        capabilities: _supportedCapabilities,
        platform: _platformName(),
        locale: locale.toLanguageTag(),
      ),
    ),
    hostBridge: AppHostBridge(navigatorKey: navigatorKey),
    capabilityRegistry: CapabilityRegistry(_supportedCapabilities),
    cacheBundle: MiniProgramCacheBundle.inMemory(),
  );
}

String _resolveBackendBaseUrl() {
  const configured = String.fromEnvironment(
    'MINI_PROGRAM_BACKEND_BASE_URL',
    defaultValue: '',
  );
  if (configured.isNotEmpty) {
    return configured;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8080/api/';
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return 'http://127.0.0.1:8080/api/';
  }
}

String _platformName() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}
''';
  }

  String _buildNativeProfileEditorPage() {
    return '''
import 'package:flutter/material.dart';

class NativeProfileEditorPage extends StatelessWidget {
  const NativeProfileEditorPage({super.key, required this.initialArgs});

  final Map<String, dynamic> initialArgs;

  @override
  Widget build(BuildContext context) {
    final userId = initialArgs['userId']?.toString() ?? 'starter_demo_user';
    final source = initialArgs['source']?.toString() ?? 'mini_program';

    return Scaffold(
      appBar: AppBar(title: const Text('Native Profile Editor')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This is a host-owned Flutter page opened through HostBridge.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text('User ID: \$userId'),
              Text('Requested by: \$source'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(<String, dynamic>{
                    'saved': true,
                    'userId': userId,
                    'source': source,
                  });
                },
                child: const Text('Return result'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''';
  }

  String _buildReadme({
    required String packageName,
    required String? repoRootPath,
    required String hostAppId,
    required String hostVersion,
    required String nativeRoutePath,
  }) {
    return '''
# Embedded Mini-Program Adapter

This folder was generated by `init_mini_program_embedding`.

Generated files:

- `mini_program.dart`
- `mini_program_app_shell.dart`
- `mini_program_routes.dart`
- `app_host_bridge.dart`
- `mini_program_runtime_setup.dart`
- `native_profile_editor_page.dart`
- `mini_program_launcher.dart`
- `android/app/src/debug/AndroidManifest.xml` when the Flutter app has an
  Android target
- `android/app/src/debug/res/xml/mini_program_network_security_config.xml`
  when the Flutter app has an Android target

## 1. Hosted package dependencies

```yaml
dependencies:
  mini_program_sdk: $_miniProgramSdkConstraint
  mini_program_contracts: $_miniProgramContractsConstraint
```

`embed init` updates `pubspec.yaml` to add these hosted packages if they are
missing or still using local `path:` entries. Run `flutter pub get` after the
scaffold is generated.

## 2. Keep main.dart small

```dart
import 'package:flutter/material.dart';
import 'mini_program/mini_program.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MiniProgramAppShell(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
```

## 3. Open any mini-program from an ordinary app button

```dart
import 'mini_program/mini_program.dart';

openAppMiniProgram(
  context,
  miniProgramId: 'my_data',
  title: 'My Data',
);
```

Or use the generated launcher button:

```dart
const AppMiniProgramLauncherButton(
  miniProgramId: 'my_data',
  title: 'My Data',
  child: Text('Open Mini Program'),
)
```

`MiniProgramAppShell` already wires the generated runtime and sample native
route registration. If your app needs custom named routes too, pass
`onGenerateRoute` into `MiniProgramAppShell` and unhandled routes will keep
flowing through your app-owned route factory.

## Generated defaults

- package name: `$packageName`
- host app id: `$hostAppId`
- host version: `$hostVersion`
- lean capabilities: `analytics`, `native_navigation`
- native route alias: `profile_editor -> $nativeRoutePath`

## Notes

- `app_host_bridge.dart` is app-owned. Replace route aliases, analytics, and
  secure API behavior with your real implementation.
- `mini_program_app_shell.dart` is the lowest-friction app entrypoint. It keeps
  `main.dart` and `MyApp` small while still letting you override normal
  `MaterialApp` options.
- `mini_program_launcher.dart` is the developer-friendly entrypoint for feature
  pages. It keeps widget code from repeating Navigator glue.
- `mini_program_runtime_setup.dart` defaults to:
  - Android emulator: `http://10.0.2.2:8080/api/`
  - desktop/iOS simulators: `http://127.0.0.1:8080/api/`
- `embed init` also adds Android debug-only cleartext config for the local
  backend so the generated emulator default can reach `http://10.0.2.2:8080`
  without manual manifest edits
- When your local backend is already running on port `8080`, Android emulator
  development should usually work with:

```text
flutter run -d emulator-5554
```

- Override the backend base URL with:

```text
--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=http://host:8080/api/
```
''';
  }

  Map<String, String> _buildPlatformIntegrationFiles({
    required String projectRootPath,
  }) {
    final files = <String, String>{};
    final androidDebugDirectory = Directory(
      p.join(projectRootPath, 'android', 'app', 'src', 'debug'),
    );
    if (androidDebugDirectory.existsSync()) {
      files[p.join(androidDebugDirectory.path, 'AndroidManifest.xml')] =
          _buildAndroidDebugManifest();
      files[p.join(
            androidDebugDirectory.path,
            'res',
            'xml',
            'mini_program_network_security_config.xml',
          )] =
          _buildAndroidDebugNetworkSecurityConfig();
    }
    return files;
  }

  String _buildAndroidDebugManifest() {
    return '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:usesCleartextTraffic="true"
        android:networkSecurityConfig="@xml/mini_program_network_security_config" />
</manifest>
''';
  }

  String _buildAndroidDebugNetworkSecurityConfig() {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">127.0.0.1</domain>
        <domain includeSubdomains="true">localhost</domain>
    </domain-config>
</network-security-config>
''';
  }
}
