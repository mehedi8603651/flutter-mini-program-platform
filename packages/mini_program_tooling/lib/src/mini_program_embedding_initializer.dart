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
    this.withDemo = false,
  });

  final String projectRootPath;
  final String? repoRootPath;
  final String? hostAppId;
  final String? hostVersion;
  final String nativeRoutePath;
  final bool force;
  final bool withDemo;
}

class MiniProgramEmbeddingInitResult {
  const MiniProgramEmbeddingInitResult({
    required this.projectRootPath,
    required this.repoRootPath,
    required this.packageName,
    required this.hostAppId,
    required this.hostVersion,
    required this.nativeRoutePath,
    required this.withDemo,
    required this.createdPaths,
  });

  final String projectRootPath;
  final String? repoRootPath;
  final String packageName;
  final String hostAppId;
  final String hostVersion;
  final String nativeRoutePath;
  final bool withDemo;
  final List<String> createdPaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'projectRootPath': projectRootPath,
    'repoRootPath': repoRootPath,
    'packageName': packageName,
    'hostAppId': hostAppId,
    'hostVersion': hostVersion,
    'nativeRoutePath': nativeRoutePath,
    'withDemo': withDemo,
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

  static const String _miniProgramSdkConstraint = '^0.3.4';
  static const String _miniProgramContractsConstraint = '^0.1.1';
  static const String _publicDemoAppId = 'profile';
  static const String _publicDemoTitle = 'Public Demo';
  static const String _publicDemoApiBaseUri =
      'https://cdn.jsdelivr.net/gh/mehedi8603651/miniprogram-public@main/';

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
      p.join(integrationRootPath, 'mini_program.dart'): _buildBarrel(
        withDemo: request.withDemo,
      ),
      p.join(integrationRootPath, 'README.md'): _buildReadme(
        packageName: packageName,
        repoRootPath: repoRootPath,
        hostAppId: resolvedHostAppId,
        hostVersion: resolvedHostVersion,
        withDemo: request.withDemo,
      ),
    };
    if (request.withDemo) {
      managedFiles[p.join(integrationRootPath, 'mini_program_endpoints.dart')] =
          _buildDemoEndpointFile();
      managedFiles[p.join(integrationRootPath, 'mini_program_registry.dart')] =
          _buildDemoRegistryFile();
    }
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
      withDemo: request.withDemo,
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

  String _buildBarrel({required bool withDemo}) {
    final demoExports = withDemo
        ? '''
export 'mini_program_endpoints.dart';
export 'mini_program_registry.dart';
'''
        : '';
    return '''
export 'package:mini_program_sdk/mini_program_sdk.dart';

export 'app_host_bridge.dart';
export 'mini_program_launcher.dart';
export 'mini_program_runtime_setup.dart';
$demoExports''';
  }

  String _buildDemoEndpointFile() {
    return '''
// Generated by `miniprogram embed init --with-demo`.
// Keep endpoint ownership in host config, not button code.
// BEGIN MINI_PROGRAM_ENDPOINTS_JSON
// {"$_publicDemoAppId":{"apiBaseUri":"$_publicDemoApiBaseUri","accessMode":"public"}}
// END MINI_PROGRAM_ENDPOINTS_JSON

import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program_registry.dart';

Map<String, MiniProgramEndpoint> buildMiniProgramEndpoints() {
  return <String, MiniProgramEndpoint>{
    MiniPrograms.publicDemo.appId: MiniProgramEndpoint.public(
      apiBaseUri: Uri.parse('$_publicDemoApiBaseUri'),
    ),
  };
}
''';
  }

  String _buildDemoRegistryFile() {
    return '''
// Generated by `miniprogram embed init --with-demo`.
// Keep mini-program appId/title pairs in one place when a host app opens
// multiple mini-programs.

class MiniProgramInfo {
  const MiniProgramInfo({
    required this.appId,
    required this.title,
  });

  final String appId;
  final String title;
}

class MiniPrograms {
  const MiniPrograms._();

  static const publicDemo = MiniProgramInfo(
    appId: '$_publicDemoAppId',
    title: '$_publicDemoTitle',
  );

  static const values = <MiniProgramInfo>[
    publicDemo,
  ];

  static const byAppId = <String, MiniProgramInfo>{
    publicDemo.appId: publicDemo,
  };
}
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
  final supportedCapabilities = <Capability>{
    Capability.analytics,
    if (openNativeRoute != null) Capability.nativeNavigation,
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
    required bool withDemo,
  }) {
    final demoSection = withDemo
        ? '''
## Public demo endpoint

This adapter was generated with `--with-demo`, so it includes a public
GitHub/jsDelivr mini-program endpoint for first-run testing:

- appId: `$_publicDemoAppId`
- title: `$_publicDemoTitle`
- endpoint: `$_publicDemoApiBaseUri`

Use this in `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program/mini_program_endpoints.dart';
import 'mini_program/mini_program_launcher.dart';
import 'mini_program/mini_program_registry.dart';
import 'mini_program/mini_program_runtime_setup.dart';

void main() {
  runApp(
    MiniProgramScope(
      config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
      child: const MyApp(),
    ),
  );
}
```

Then add a normal host-owned button anywhere in your UI:

```dart
FilledButton(
  onPressed: () {
    openAppMiniProgram(
      context,
      appId: MiniPrograms.publicDemo.appId,
      title: MiniPrograms.publicDemo.title,
    );
  },
  child: const Text('Open Public Demo'),
)
```

Public demo delivery has no MiniProgram access key and no backend setup. For
your own public mini-program, publish static output to GitHub Pages/CDN and use
a jsDelivr base URL like:

```text
https://cdn.jsdelivr.net/gh/mehedi8603651/<repo>@main/
```

Replace the generated endpoint URL after publishing your own repo.

'''
        : '''
## Optional first-run public demo

If you want this host app to open a public demo mini-program immediately,
rerun the scaffold with:

```bash
miniprogram embed init --with-demo --force
```

That adds `mini_program_endpoints.dart`, `mini_program_registry.dart`, and a
button snippet using a public GitHub/jsDelivr endpoint. No AWS setup or
MiniProgram access key is required for the public demo.

''';
    return '''
# Embedded Mini-Program Adapter

This folder was generated by `miniprogram embed init`.

Generated files:

- `mini_program.dart`
- `app_host_bridge.dart`
- `mini_program_runtime_setup.dart`
- `mini_program_launcher.dart`
- `mini_program_endpoints.dart` and `mini_program_registry.dart` when
  `--with-demo` is used
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
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

## 4. Optional registry for many mini-programs

For one or two buttons, inline strings are easiest to read. When one host app
opens many mini-programs, keep each `appId` and display title together in a
small registry so buttons, menus, analytics, and tests do not repeat strings:

```dart
// Optional: use this only when the host opens many mini-programs.
// It keeps appId and title together, which avoids typo bugs across buttons,
// menus, analytics events, and tests.
class MiniProgramInfo {
  const MiniProgramInfo({
    required this.appId,
    required this.title,
  });

  final String appId;
  final String title;
}

// Constants-only namespace. The private constructor prevents MiniPrograms()
// from being created accidentally.
class MiniPrograms {
  const MiniPrograms._();

  static const coupon = MiniProgramInfo(
    appId: 'coupon',
    title: 'Coupon',
  );

  static const profile = MiniProgramInfo(
    appId: 'profile',
    title: 'Profile',
  );
}
```

Then use the registry from ordinary host UI code:

```dart
openAppMiniProgram(
  context,
  appId: MiniPrograms.coupon.appId,
  title: MiniPrograms.coupon.title,
);
```

$demoSection
## 5. Optional multi-publisher endpoints

If different partners publish mini-programs to different backends, keep app UI
appId-only and register each endpoint once in runtime config:

Publisher handoff file:

```bash
miniprogram partner package aws_coupon_demo --title "AWS Coupon Demo" --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx --env my-aws-prod --output aws_coupon_demo.partner.json
```

Public/static handoff files are also supported for GitHub Pages, CDN, and other
public hosting:

```bash
miniprogram partner package public_coupon_demo --title "Public Coupon Demo" --public --api-base-url https://user.github.io/repo/public_mini_program/ --output public_coupon_demo.partner.json
```

Host import:

```bash
miniprogram host endpoint import ../aws_coupon_demo.partner.json
```

Manual host entry is also available:

```bash
miniprogram host endpoint add aws_coupon_demo --api-base-url https://aws.example.com/prod/api/ --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
miniprogram host endpoint add public_coupon_demo --api-base-url https://user.github.io/repo/public_mini_program/ --public
miniprogram host endpoint add rewards --api-base-url https://aws.example.com/prod/api/ --access-key mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx --backend-base-url https://publisher.example.com/api/
```

```dart
import 'mini_program/mini_program_endpoints.dart';

MiniProgramScope(
  config: buildMiniProgramConfig(
    endpoints: buildMiniProgramEndpoints(),
  ),
  child: const MyApp(),
);
```

Then open each mini-program normally:

```dart
openAppMiniProgram(
  context,
  appId: 'aws_coupon_demo',
  title: 'AWS Coupon Demo',
);
```

Rule: UI knows `appId`; config knows API base URL and MiniProgram access key.
For protected cloud delivery, the backend should validate the
`X-Mini-Program-Access-Key` header against its per-mini-program key policy, so
revoking one partner key does not affect other partners using the same
mini-program.

If a mini-program needs its publisher-owned Firebase/AWS/custom backend, pass
`--backend-base-url` in the partner package or host endpoint command. Generated
runtime setup wires that backend lazily, and generated mini-program helpers can
call it with `miniProgramBackendAction(...)`, `miniProgramBackendQueryAction(...)`,
or `miniProgramBackendBuilder(...)`.

Use `miniProgramBackendBuilder(...)` when UI should load JSON and bind values
like `{{backend.home.data.title}}` or repeat simple list item templates with
`{{item.title}}`. Use batch endpoints such as `home/bootstrap`, CDN image URLs,
short timeouts, and explicit cache TTLs only for safe `GET` responses. Backend
secrets must stay on the publisher server; never put them in JSON, source, APK,
IPA, or web JavaScript.

This package does not own your Flutter app. It only provides mini-program
capability through `MiniProgramScope`. Your `MaterialApp`, `GetMaterialApp`,
`MaterialApp.router`, GoRouter, theme, localization, state management, routes,
and navigator setup remain fully yours.

## Generated defaults

- package name: `$packageName`
- host app id: `$hostAppId`
- host version: `$hostVersion`
- lean capabilities: `analytics`; `native_navigation` is added when you pass an
  `openNativeRoute` callback to `buildMiniProgramConfig`

## Host app structure

- `mini_program.dart` is an optional generated barrel export if you prefer one
  app-local import.
- `mini_program_launcher.dart` exposes `openAppMiniProgram(...)` and
  `AppMiniProgramLauncher`.
- `mini_program_runtime_setup.dart` resolves `MINI_PROGRAM_BACKEND_BASE_URL`
  and builds `MiniProgramConfig`.
- `app_host_bridge.dart` is app-owned. Edit it for real analytics,
  host-native routes, and secure API behavior.
- your app `lib/main.dart` stays app-owned. Add buttons, tabs, or menu items
  that call `openAppMiniProgram(...)`.

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
- `MiniProgramScope` does not load a manifest, start a network request,
  initialize Stac, insert an overlay, or push a route until you open a
  mini-program.

Full demo `lib/main.dart` after importing partner endpoints:

```dart
import 'package:flutter/material.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program/mini_program_endpoints.dart';
import 'mini_program/mini_program_launcher.dart';
import 'mini_program/mini_program_runtime_setup.dart';

void main() {
  runApp(
    MiniProgramScope(
      config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniProgram Host',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MiniProgram Host')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            openAppMiniProgram(
              context,
              appId: 'aws_coupon_demo',
              title: 'AWS Coupon Demo',
            );
          },
          child: const Text('Open Coupon MiniProgram'),
        ),
      ),
    );
  }
}
```

State management still stays app-owned. `MiniProgramScope` can compose with
your normal root wrappers.

Riverpod:

```dart
void main() {
  runApp(
    ProviderScope(
      child: MiniProgramScope(
        config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
        child: const MyApp(),
      ),
    ),
  );
}
```

Provider:

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MiniProgramScope(
        config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
        child: const MyApp(),
      ),
    ),
  );
}
```

Bloc:

```dart
void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
      ],
      child: MiniProgramScope(
        config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
        child: const MyApp(),
      ),
    ),
  );
}
```

These snippets do not mean the SDK depends on Riverpod, Provider, Bloc, GetX,
or GoRouter. They only show that host apps can keep their own architecture.

## Cloud host run and APK build

After `miniprogram cloud deploy`, bind this host app to the environment:

```text
miniprogram embed cloud configure --env my-aws-prod
miniprogram host run -d chrome --env my-aws-prod
```

For release Android APK builds, use the deployed backend API URL:

```text
miniprogram cloud outputs --format dart-define
flutter build apk --release --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://<api-id>.execute-api.<aws-region>.amazonaws.com/prod/api/
```

Use the `BackendApiBaseUrl` printed by `miniprogram cloud outputs`; do not use
the S3 bucket URL directly.

## Notes

- `app_host_bridge.dart` is app-owned. Replace analytics, secure API behavior,
  and optional native-route handling with your real implementation.
- This package does not own your Flutter app. It only provides mini-program
  capability through `MiniProgramScope`. Your `MaterialApp`,
  `GetMaterialApp`, `MaterialApp.router`, GoRouter, theme, localization, state
  management, routes, and navigator setup remain fully yours.
- Multiple scopes are technically allowed for isolated runtimes, but normal
  apps should keep one `MiniProgramScope` near the app root.
- `mini_program_launcher.dart` is the developer-friendly entrypoint for feature
  pages. It keeps widget code from repeating Navigator glue.
- `mini_program_runtime_setup.dart` defaults to:
  - Android local default: `http://10.0.2.2:8080/api/`
  - desktop, Chrome on the same machine, and iOS simulators:
    `http://127.0.0.1:8080/api/`
- the shared SDK retries local loopback between `10.0.2.2` and `127.0.0.1`
  for transport failures, so Android USB `adb reverse` workflows can still use
  the generated local default
- `embed init` also adds Android release `INTERNET` permission for cloud/API
  delivery and debug-only cleartext config for the local backend, so generated
  host apps can load AWS mini-programs in release APKs and reach local HTTP
  backend URLs during development without manual manifest edits
- local backend conditions:
  - backend should already be running on port `8080`
  - Android USB or emulator loopback may still depend on an active
    `adb reverse` session when the device cannot route to `10.0.2.2`
  - if the Android device/emulator connects after backend start, rerun backend
    start or reapply `adb reverse`
  - physical devices over Wi-Fi should override `MINI_PROGRAM_BACKEND_HOST`
    with the computer's LAN IP
- generated runtime logs the resolved backend base URL and resolution source on
  startup, which helps diagnose host/port mistakes during local development
- When your local backend is already running on port `8080`, Android emulator
  development should usually work with:

```text
flutter run -d emulator-5554
```

- Override the backend with a full URL when needed:

```text
--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=http://host:8080/api/
```

- Or override only the host/port for cases like physical-device Wi-Fi testing:

```text
--dart-define=MINI_PROGRAM_BACKEND_HOST=192.168.1.25
--dart-define=MINI_PROGRAM_BACKEND_PORT=8080
```
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
