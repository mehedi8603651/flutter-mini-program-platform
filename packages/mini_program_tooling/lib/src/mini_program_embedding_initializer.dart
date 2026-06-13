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

  static const String _miniProgramSdkConstraint = '^0.4.3';
  static const String _miniProgramContractsConstraint = '^0.2.2';

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
    final updatedPubspecSource = _ensureDependencies(
      pubspecSource,
      projectRootPath: projectRootPath,
      repoRootPath: repoRootPath,
    );

    final integrationRootPath = p.join(projectRootPath, 'lib', 'mini_program');
    final integrationRootDir = Directory(integrationRootPath);

    final managedFiles = <String, String>{
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
      p.join(integrationRootPath, 'mini_program_launcher.dart'):
          _buildLauncher(),
      p.join(integrationRootPath, 'mini_program.dart'): _buildBarrel(),
      p.join(integrationRootPath, 'README.md'): _buildReadme(
        packageName: packageName,
        repoRootPath: repoRootPath,
        hostAppId: resolvedHostAppId,
        hostVersion: resolvedHostVersion,
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

  String _ensureDependencies(
    String source, {
    required String projectRootPath,
    required String? repoRootPath,
  }) {
    final managedDependencies = <String, List<String>>{
      'mini_program_sdk': <String>[
        '  mini_program_sdk: $_miniProgramSdkConstraint',
      ],
      'mini_program_contracts': <String>[
        '  mini_program_contracts: $_miniProgramContractsConstraint',
      ],
    };
    var updated = _upsertPackageSection(
      source,
      sectionName: 'dependencies',
      managedPackages: managedDependencies,
      removePackages: const <String>{'mini_program_legacy_stac'},
    );
    if (repoRootPath == null) {
      return updated;
    }

    String relativePackagePath(String packageName) {
      return p
          .relative(
            p.join(repoRootPath, 'packages', packageName),
            from: projectRootPath,
          )
          .replaceAll('\\', '/');
    }

    updated = _upsertPackageSection(
      updated,
      sectionName: 'dependency_overrides',
      managedPackages: <String, List<String>>{
        'mini_program_sdk': <String>[
          '  mini_program_sdk:',
          '    path: ${relativePackagePath('mini_program_sdk')}',
        ],
        'mini_program_contracts': <String>[
          '  mini_program_contracts:',
          '    path: ${relativePackagePath('mini_program_contracts')}',
        ],
      },
      removePackages: const <String>{'mini_program_legacy_stac'},
    );
    return updated;
  }

  String _upsertPackageSection(
    String source, {
    required String sectionName,
    required Map<String, List<String>> managedPackages,
    Set<String> removePackages = const <String>{},
  }) {
    final normalizedSource = source.replaceAll('\r\n', '\n');
    final lines = normalizedSource.split('\n');
    final dependenciesHeaderIndex = lines.indexWhere(
      (line) => line.trim() == '$sectionName:',
    );

    if (dependenciesHeaderIndex == -1) {
      final suffix = normalizedSource.endsWith('\n') || normalizedSource.isEmpty
          ? ''
          : '\n';
      return <String>[
        '$normalizedSource$suffix$sectionName:',
        ...managedPackages.values.expand((lines) => lines),
        '',
      ].join('\n');
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
    final writtenPackages = <String>{};

    for (var index = 0; index < sectionLines.length; index++) {
      final line = sectionLines[index];
      final packageMatch = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
      if (packageMatch == null) {
        rebuiltSectionLines.add(line);
        continue;
      }

      final packageName = packageMatch.group(1)!;
      final blockLines = <String>[line];
      while (index + 1 < sectionLines.length &&
          !RegExp(r'^  [A-Za-z0-9_]+:').hasMatch(sectionLines[index + 1])) {
        index += 1;
        blockLines.add(sectionLines[index]);
      }

      if (!managedPackages.containsKey(packageName) &&
          !removePackages.contains(packageName)) {
        rebuiltSectionLines.addAll(blockLines);
        continue;
      }
      final replacement = managedPackages[packageName];
      if (replacement != null) {
        writtenPackages.add(packageName);
        rebuiltSectionLines.addAll(replacement);
      }
    }

    for (final entry in managedPackages.entries) {
      if (writtenPackages.add(entry.key)) {
        rebuiltSectionLines.addAll(entry.value);
      }
    }

    final rebuiltLines = <String>[
      ...lines.sublist(0, dependenciesHeaderIndex + 1),
      ...rebuiltSectionLines,
      ...lines.sublist(dependenciesEndIndex),
    ];
    return rebuiltLines.join('\n');
  }

  String _buildHostBridge({required String logPrefix}) {
    return '''
import 'package:flutter/foundation.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

typedef AppNativeRouteOpener =
    Future<Object?> Function(String routeName, Map<String, dynamic> arguments);

class AppHostBridge implements HostBridge {
  const AppHostBridge({this.openNativeRoute});

  final AppNativeRouteOpener? openNativeRoute;

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
    final routeOpener = openNativeRoute;
    if (routeOpener == null) {
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Host native navigation is not configured.',
      );
    }

    try {
      final routeName = payload.route;
      final result = await routeOpener(routeName, payload.args);

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
  required String appId,
  String? title,
  Map<String, dynamic>? initialData,
  String? version,
  Uri? source,
  MiniProgramLaunchOptions options = const MiniProgramLaunchOptions(),
}) {
  return MiniProgramScope.of(context).openMiniProgram<T>(
    appId: appId,
    title: title,
    initialData: initialData,
    version: version,
    source: source,
    options: options,
  );
}

class AppMiniProgramLauncher extends StatelessWidget {
  const AppMiniProgramLauncher({
    super.key,
    required this.appId,
    required this.child,
    this.title,
    this.initialData,
    this.version,
    this.source,
    this.options = const MiniProgramLaunchOptions(),
  });

  final String appId;
  final Widget child;
  final String? title;
  final Map<String, dynamic>? initialData;
  final String? version;
  final Uri? source;
  final MiniProgramLaunchOptions options;

  @override
  Widget build(BuildContext context) {
    return MiniProgramLauncher(
      appId: appId,
      title: title,
      initialData: initialData,
      version: version,
      source: source,
      options: options,
      child: child,
    );
  }
}
''';
  }

  String _buildBarrel() {
    return '''
export 'package:mini_program_sdk/mini_program_sdk.dart';

export 'app_host_bridge.dart';
export 'mini_program_launcher.dart';
export 'mini_program_runtime_setup.dart';
''';
  }

  String _buildRuntimeSetup({
    required String hostAppId,
    required String hostVersion,
  }) {
    return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'app_host_bridge.dart';

const String _hostAppId = '$hostAppId';
const String _sdkVersion = '1.0.0';
const String _hostVersion = '$hostVersion';
const String _configuredBackendBaseUrl = String.fromEnvironment(
  'MINI_PROGRAM_BACKEND_BASE_URL',
  defaultValue: '',
);
const String _configuredBackendHost = String.fromEnvironment(
  'MINI_PROGRAM_BACKEND_HOST',
  defaultValue: '',
);
const int _configuredBackendPort = int.fromEnvironment(
  'MINI_PROGRAM_BACKEND_PORT',
  defaultValue: LocalMiniProgramBackendDefaults.defaultPort,
);

MiniProgramConfig buildMiniProgramConfig({
  AppNativeRouteOpener? openNativeRoute,
  Map<String, MiniProgramEndpoint> endpoints =
      const <String, MiniProgramEndpoint>{},
}) {
  final locale = WidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .locale;
  final supportedCapabilities = <CapabilityId>{
    CapabilityIds.analytics,
    if (openNativeRoute != null) CapabilityIds.nativeNavigation,
  };
  final deliveryContext = MiniProgramDeliveryContext(
    hostApp: _hostAppId,
    sdkVersion: _sdkVersion,
    hostVersion: _hostVersion,
    capabilities: supportedCapabilities,
    platform: _platformName(),
    locale: locale.toLanguageTag(),
  );
  final source = endpoints.isEmpty
      ? _buildDefaultHttpSource(deliveryContext)
      : _buildEndpointRoutingSource(endpoints, deliveryContext);

  return MiniProgramConfig(
    sdkVersion: _sdkVersion,
    source: source,
    hostBridge: AppHostBridge(openNativeRoute: openNativeRoute),
    capabilityRegistry: CapabilityRegistry(supportedCapabilities),
    backendConnector: endpoints.isEmpty
        ? null
        : buildEndpointRoutingBackendConnector(
            endpoints: endpoints,
            deliveryContext: deliveryContext,
          ),
    authController: MiniProgramAuthController.secure(),
    disposeAuthController: true,
    cacheBundle: MiniProgramCacheBundle.inMemory(),
  );
}

MiniProgramSource _buildDefaultHttpSource(
  MiniProgramDeliveryContext deliveryContext,
) {
  final backendApiBaseUri = LocalMiniProgramBackendDefaults.resolveBaseUri(
    configuredBaseUrl: _configuredBackendBaseUrl,
    configuredHost: _configuredBackendHost,
    configuredPort: _configuredBackendPort,
  );
  _logResolvedBackendBaseUri(backendApiBaseUri);
  return HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: backendApiBaseUri,
    deliveryContext: deliveryContext,
  );
}

MiniProgramSource _buildEndpointRoutingSource(
  Map<String, MiniProgramEndpoint> endpoints,
  MiniProgramDeliveryContext deliveryContext,
) {
  _logEndpointRouting(endpoints);
  return EndpointRoutingMiniProgramSource(
    endpoints: endpoints,
    deliveryContext: deliveryContext,
  );
}

void _logResolvedBackendBaseUri(Uri backendApiBaseUri) {
  debugPrint(
    '[mini_program][runtime] Backend base URL: \$backendApiBaseUri '
    '(source: \${_backendResolutionSource()})',
  );
}

void _logEndpointRouting(Map<String, MiniProgramEndpoint> endpoints) {
  final appIds = endpoints.keys.toList()..sort();
  debugPrint(
    '[mini_program][runtime] Endpoint routing enabled for '
    '\${appIds.length} mini-program endpoint(s): \${appIds.join(', ')}',
  );
}

String _backendResolutionSource() {
  if (_configuredBackendBaseUrl.isNotEmpty) {
    return 'MINI_PROGRAM_BACKEND_BASE_URL';
  }
  if (_configuredBackendHost.isNotEmpty ||
      _configuredBackendPort != LocalMiniProgramBackendDefaults.defaultPort) {
    return 'MINI_PROGRAM_BACKEND_HOST/PORT';
  }
  if (kIsWeb) {
    return 'target_default:web';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'target_default:android',
    TargetPlatform.iOS => 'target_default:ios',
    TargetPlatform.macOS => 'target_default:macos',
    TargetPlatform.windows => 'target_default:windows',
    TargetPlatform.linux => 'target_default:linux',
    TargetPlatform.fuchsia => 'target_default:fuchsia',
  };
}

String _platformName() {
  if (kIsWeb) {
    return 'web';
  }

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

  String _buildReadme({
    required String packageName,
    required String? repoRootPath,
    required String hostAppId,
    required String hostVersion,
  }) {
    return '''
# Embedded Mini-Program Adapter

This folder was generated by `miniprogram embed init`.

Generated files:

- `mini_program.dart`
- `app_host_bridge.dart`
- `mini_program_runtime_setup.dart`
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
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program/mini_program_runtime_setup.dart';

void main() {
  runApp(
    MiniProgramScope(
      config: buildMiniProgramConfig(),
      child: const MyApp(),
    ),
  );
}
```

## 3. Open any mini-program from an ordinary app button

```dart
import 'mini_program/mini_program_launcher.dart';

openAppMiniProgram(
  context,
  appId: 'my_data',
  title: 'My Data',
);
```

Or use the generated launcher widget:

```dart
const AppMiniProgramLauncher(
  appId: 'my_data',
  title: 'My Data',
  child: Text('Open Mini Program'),
)
```

## 4. Optional endpoint registry

For one or two buttons, inline strings are easiest to read. When one host app
opens many mini-programs, keep each `appId`, title, delivery URL, backend URL,
and access mode in generated endpoint files from partner handoff import:

```bash
miniprogram host endpoint import ../my_program.partner.json
```

Then wire the generated endpoint map into runtime setup:

```dart
MiniProgramScope(
  config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
  child: const MyApp(),
);
```

Rule: host UI knows `appId`; host config owns static artifact URLs, Publisher API
URLs, and MiniProgram access keys. Provider credentials and backend secrets stay
on the Publisher API server, never in Mp JSON, APK, IPA, web JavaScript, logs, or handoff
docs.

## Generated defaults

- package name: `$packageName`
- host app id: `$hostAppId`
- host version: `$hostVersion`
- lean capabilities: `analytics`; `native_navigation` is added when you pass an
  `openNativeRoute` callback to `buildMiniProgramConfig`

## Host app structure

- `mini_program.dart` is an optional generated barrel export.
- `mini_program_launcher.dart` exposes `openAppMiniProgram(...)` and
  `AppMiniProgramLauncher`.
- `mini_program_runtime_setup.dart` resolves `MINI_PROGRAM_BACKEND_BASE_URL`
  and builds `MiniProgramConfig`.
- `app_host_bridge.dart` is app-owned. Edit it for real analytics,
  host-native routes, and secure API behavior.
- your app `lib/main.dart` stays app-owned.

## Runtime ownership

- Recommended: `MiniProgramScope(config: buildMiniProgramConfig(), child: MyApp())`.
- Advanced: `MiniProgramController` and `MiniProgramNavigationDelegate`.
- Manual embedding: `MiniProgramRuntimeScope`, `MiniProgramPage`, and
  `MiniProgramHost`.
- `MiniProgramConfig` is immutable for a `MiniProgramScope` state. Recreate the
  scope with a new key when switching environments.
- `MiniProgramConfig.sdkVersion` is the runtime compatibility version checked
  against manifest `sdkVersionRange`, not the `mini_program_sdk` pub package
  version.
- `MiniProgramScope` does not load a manifest, start a network request, insert
  an overlay, or push a route until you open a mini-program.

## Local backend defaults

- Android local default: `http://10.0.2.2:8080/api/`
- desktop, Chrome on the same machine, and iOS simulators:
  `http://127.0.0.1:8080/api/`
- override the backend with a full URL when needed:

```text
--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=http://host:8080/api/
```

- or override only the host/port for physical-device Wi-Fi testing:

```text
--dart-define=MINI_PROGRAM_BACKEND_HOST=192.168.1.25
--dart-define=MINI_PROGRAM_BACKEND_PORT=8080
```

State management still stays app-owned. `MiniProgramScope` can compose with
Riverpod, Provider, Bloc, GetX, GoRouter, custom architecture, or plain Flutter.
''';
  }

  Map<String, String> _buildPlatformIntegrationFiles({
    required String projectRootPath,
  }) {
    final files = <String, String>{};
    final androidMainManifest = File(
      p.join(
        projectRootPath,
        'android',
        'app',
        'src',
        'main',
        'AndroidManifest.xml',
      ),
    );
    if (androidMainManifest.existsSync()) {
      files[androidMainManifest.path] = _ensureAndroidInternetPermission(
        androidMainManifest.readAsStringSync(),
      );
    }

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

  String _ensureAndroidInternetPermission(String source) {
    if (source.contains('android.permission.INTERNET')) {
      return source;
    }

    final normalizedSource = source.replaceAll('\r\n', '\n');
    final manifestMatch = RegExp(
      r'<manifest\b[^>]*>',
      multiLine: true,
    ).firstMatch(normalizedSource);
    if (manifestMatch == null) {
      return source;
    }

    return normalizedSource.replaceRange(
      manifestMatch.end,
      manifestMatch.end,
      '\n    <uses-permission android:name="android.permission.INTERNET"/>',
    );
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
