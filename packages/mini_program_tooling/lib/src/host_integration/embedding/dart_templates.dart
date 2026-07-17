String buildEmbeddingHostBridge({required String logPrefix}) {
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
        'error=\$error\n\$stackTrace',
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

String buildEmbeddingLauncher() {
  return '''
import 'package:flutter/widgets.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'mini_program_registry.dart';

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

Future<T?> openRegisteredMiniProgram<T>(
  BuildContext context,
  MiniProgramInfo miniProgram, {
  Map<String, dynamic>? initialData,
  String? version,
  Uri? source,
  MiniProgramLaunchOptions options = const MiniProgramLaunchOptions(),
}) {
  return openAppMiniProgram<T>(
    context,
    appId: miniProgram.appId,
    title: miniProgram.title,
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

class RegisteredMiniProgramLauncher extends StatelessWidget {
  const RegisteredMiniProgramLauncher({
    super.key,
    required this.miniProgram,
    required this.child,
    this.initialData,
    this.version,
    this.source,
    this.options = const MiniProgramLaunchOptions(),
  });

  final MiniProgramInfo miniProgram;
  final Widget child;
  final Map<String, dynamic>? initialData;
  final String? version;
  final Uri? source;
  final MiniProgramLaunchOptions options;

  @override
  Widget build(BuildContext context) {
    return MiniProgramLauncher(
      appId: miniProgram.appId,
      title: miniProgram.title,
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

String buildEmbeddingBarrel() {
  return '''
export 'package:mini_program_sdk/mini_program_sdk.dart';

export 'app_host_bridge.dart';
export 'mini_program_endpoints.dart';
export 'mini_program_host_setup.dart';
export 'mini_program_launcher.dart';
export 'mini_program_policy_resolver.dart';
export 'mini_program_registry.dart';
export 'mini_program_runtime_setup.dart';
''';
}

String buildEmbeddingHostSetup() {
  return '''
import 'package:mini_program_sdk/mini_program_sdk.dart';

import 'app_host_bridge.dart';
import 'mini_program_endpoints.dart';
import 'mini_program_runtime_setup.dart';

/// Host-owned composition point for mini-program runtime configuration.
///
/// This file is created once and is never overwritten by tooling. Add the
/// host's persistent cache, environment selection, and native capabilities
/// here while keeping generated endpoint and policy files untouched.
Future<MiniProgramConfig> buildHostMiniProgramConfig({
  AppNativeRouteOpener? openNativeRoute,
  MiniProgramLocationProvider? locationProvider,
  Map<String, MiniProgramEndpoint>? endpoints,
  MiniProgramCacheBundle? cacheBundle,
}) async {
  return buildMiniProgramConfig(
    openNativeRoute: openNativeRoute,
    locationProvider: locationProvider,
    endpoints: endpoints ?? buildMiniProgramEndpoints(),
    cacheBundle: cacheBundle,
  );
}
''';
}

String buildEmptyEmbeddingEndpoints() {
  return '''
// Generated by `miniprogram host endpoint import`.
// Static artifact URLs and accepted policies are wired here.
// BEGIN MINI_PROGRAM_ENDPOINTS_JSON
// {}
// END MINI_PROGRAM_ENDPOINTS_JSON

import 'package:mini_program_sdk/mini_program_sdk.dart';

Map<String, MiniProgramEndpoint> buildMiniProgramEndpoints() {
  return <String, MiniProgramEndpoint>{};
}
''';
}

String buildEmptyEmbeddingRegistry() {
  return '''
// Generated by miniprogram tooling.
// Updated by `miniprogram host endpoint import`.

class MiniProgramInfo {
  const MiniProgramInfo({required this.appId, required this.title});

  final String appId;
  final String title;
}

class MiniPrograms {
  const MiniPrograms._();

  static const values = <MiniProgramInfo>[];
  static const byAppId = <String, MiniProgramInfo>{};
}
''';
}

String buildEmptyEmbeddingPolicyResolver() {
  return '''
// Generated by `miniprogram host endpoint import`.

import 'package:mini_program_sdk/mini_program_sdk.dart';

MiniProgramCachePolicy cachePolicyForMiniProgram(String appId) {
  return const MiniProgramCachePolicy();
}

MiniProgramLiveStatePolicy liveStatePolicyForMiniProgram(String appId) {
  return const MiniProgramLiveStatePolicy();
}

MiniProgramPublisherApiPolicy publisherApiPolicyForMiniProgram(String appId) {
  return const MiniProgramPublisherApiPolicy();
}

MiniProgramLocationPolicy locationPolicyForMiniProgram(String appId) {
  return const MiniProgramLocationPolicy();
}
''';
}

String buildEmptyEmbeddingPolicies() {
  return '''
{
  "schemaVersion": 1,
  "apps": {}
}
''';
}

String buildEmbeddingRuntimeSetup({
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
  MiniProgramLocationProvider? locationProvider,
  Map<String, MiniProgramEndpoint> endpoints =
      const <String, MiniProgramEndpoint>{},
  MiniProgramCacheBundle? cacheBundle,
}) {
  final locale = WidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .locale;
  final supportedCapabilities = <CapabilityId>{
    CapabilityIds.analytics,
    if (openNativeRoute != null) CapabilityIds.nativeNavigation,
    if (locationProvider != null) CapabilityIds.locationCurrent,
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
    locationProvider: locationProvider,
    capabilityRegistry: CapabilityRegistry(supportedCapabilities),
    authController: MiniProgramAuthController.secure(),
    disposeAuthController: true,
    cacheBundle: cacheBundle ?? MiniProgramCacheBundle.inMemory(),
  );
}

MiniProgramSource _buildDefaultHttpSource(
  MiniProgramDeliveryContext deliveryContext,
) {
  final artifactBaseUri = LocalMiniProgramBackendDefaults.resolveBaseUri(
    configuredBaseUrl: _configuredBackendBaseUrl,
    configuredHost: _configuredBackendHost,
    configuredPort: _configuredBackendPort,
  );
  _logResolvedArtifactBaseUri(artifactBaseUri);
  return HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: artifactBaseUri,
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

void _logResolvedArtifactBaseUri(Uri artifactBaseUri) {
  debugPrint(
    '[mini_program][runtime] Static artifact base URL: \$artifactBaseUri '
    '(source: \${_artifactResolutionSource()})',
  );
}

void _logEndpointRouting(Map<String, MiniProgramEndpoint> endpoints) {
  final appIds = endpoints.keys.toList()..sort();
  debugPrint(
    '[mini_program][runtime] Endpoint routing enabled for '
    '\${appIds.length} mini-program endpoint(s): \${appIds.join(', ')}',
  );
}

String _artifactResolutionSource() {
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
