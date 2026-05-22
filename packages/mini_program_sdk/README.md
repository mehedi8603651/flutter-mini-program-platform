# mini_program_sdk

Portable runtime SDK for the Flutter mini-program platform.

This package gives Flutter host apps the runtime pieces needed to load,
validate, render, and launch server-delivered mini-programs built with the
shared platform contracts.

## What it includes

- `MiniProgramScope`, `MiniProgramController`, and `MiniProgramConfig`
- `MiniProgramPage` and lower-level runtime scope APIs
- `MiniProgramHost` for lower-level embedding
- manifest loading and version validation
- capability registry and feature-flag evaluation
- host bridge dispatch for native actions
- Stac-based rendering setup
- in-memory cache helpers for manifests, screens, and assets

## Install

```yaml
dependencies:
  mini_program_sdk: ^0.3.5
  mini_program_contracts: ^0.1.1
```

For monorepo contributor work, keep `pubspec_overrides.yaml` so the package
uses the local `mini_program_contracts` checkout.

## VS Code extension

For host-app setup, endpoint import, diagnostics, and guided mini-program
workflows, install **MiniProgram Tools** from the VS Code Marketplace:

- Marketplace: https://marketplace.visualstudio.com/items?itemName=MiniProgramTools.mini-program-tools
- Install command:

```bash
dart pub global activate mini_program_tooling
code --install-extension MiniProgramTools.mini-program-tools
```

The extension does not replace the SDK or CLI. It calls the installed
`miniprogram` CLI and helps developers wire `MiniProgramScope`, endpoints,
partner packages, public static delivery, and cloud delivery from VS Code.

## Minimal usage

For most host apps, prefer generating the adapter with
`miniprogram embed init`. That creates `lib/mini_program/`, adds the SDK
dependencies to `pubspec.yaml`, and gives you `buildMiniProgramConfig(...)`
plus `openAppMiniProgram(...)`.

For first-run testing without AWS or access keys, use:

```bash
miniprogram embed init --with-demo
```

That adds a public jsDelivr demo endpoint and registry entry using:

```text
https://cdn.jsdelivr.net/gh/mehedi8603651/miniprogram-public@main/
```

This package does not own your Flutter app. It only provides mini-program
capability through `MiniProgramScope`. Your `MaterialApp`, `GetMaterialApp`,
`MaterialApp.router`, GoRouter, theme, localization, state management, routes,
and navigator setup remain fully yours.

```dart
import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  final config = MiniProgramConfig(
    sdkVersion: '1.0.0',
    source: HttpMiniProgramSource.fromDeliveryContext(
      apiBaseUri: LocalMiniProgramBackendDefaults.resolveBaseUri(
        configuredBaseUrl: const String.fromEnvironment(
          'MINI_PROGRAM_BACKEND_BASE_URL',
          defaultValue: '',
        ),
      ),
      deliveryContext: const MiniProgramDeliveryContext(
        hostApp: 'sample_host',
        sdkVersion: '1.0.0',
        hostVersion: '1.0.0',
        capabilities: <Capability>{
          Capability.analytics,
          Capability.nativeNavigation,
        },
        platform: 'android',
        locale: 'en-US',
      ),
    ),
    hostBridge: const NoopHostBridge(),
    capabilityRegistry: CapabilityRegistry(
      const <Capability>[
        Capability.analytics,
        Capability.nativeNavigation,
      ],
    ),
    cacheBundle: MiniProgramCacheBundle.inMemory(),
  );

  runApp(
    MiniProgramScope(
      config: config,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            MiniProgramScope.of(context).openMiniProgram(
              appId: 'my_coupon_app',
              title: 'My Coupon App',
            );
          },
          child: const Text('Open My Coupon App'),
        ),
      ),
    );
  }
}

class NoopHostBridge implements HostBridge {
  const NoopHostBridge();

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    return HostActionResult.success(actionName: ActionNames.trackEvent);
  }

  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async {
    return HostActionResult.failed(
      actionName: ActionNames.openNativeScreen,
      message: 'Native navigation is not configured in this sample host.',
    );
  }

  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async {
    return HostActionResult.failed(
      actionName: ActionNames.callSecureApi,
      message: 'secure_api is not configured in this sample host.',
    );
  }
}
```

`MiniProgramConfig.sdkVersion` is the runtime compatibility version sent to
mini-program delivery backends and compared with manifest `sdkVersionRange`
values. It is not the pub package version of `mini_program_sdk`; for example,
the package can be `0.3.5` while the runtime compatibility version remains
`1.0.0`.

## Multi-publisher endpoints

For one host app with mini-programs from multiple publishers or cloud
providers, keep UI calls appId-only and register server details once in
configuration:

```dart
final config = MiniProgramConfig(
  sdkVersion: '1.0.0',
  source: EndpointRoutingMiniProgramSource(
    deliveryContext: const MiniProgramDeliveryContext(
      hostApp: 'sample_host',
      sdkVersion: '1.0.0',
      hostVersion: '1.0.0',
      capabilities: <Capability>{Capability.analytics},
      platform: 'android',
      locale: 'en-US',
    ),
    endpoints: <String, MiniProgramEndpoint>{
      'aws_coupon_demo': MiniProgramEndpoint(
        apiBaseUri: Uri.parse('https://aws.example.com/prod/api/'),
        accessKey: 'mpk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      ),
      'public_coupon_demo': MiniProgramEndpoint.public(
        apiBaseUri: Uri.parse(
          'https://user.github.io/repo/public_mini_program/',
        ),
      ),
    },
  ),
  hostBridge: const NoopHostBridge(),
  capabilityRegistry: CapabilityRegistry(
    const <Capability>[Capability.analytics],
  ),
);
```

Screens still open mini-programs by app id:

```dart
MiniProgramScope.of(context).openMiniProgram(
  appId: 'aws_coupon_demo',
  title: 'AWS Coupon Demo',
);
```

Rule: UI knows `appId`; config knows API base URL and delivery access mode.
For protected cloud delivery, the backend should validate the
`X-Mini-Program-Access-Key` header against its per-mini-program key policy, so
revoking one partner key does not affect other partners using the same
mini-program.

For public/static demos, open-source samples, GitHub Pages, CDN, S3 public
hosting, Cloudflare Pages, Netlify, or Vercel static hosting, use
`MiniProgramEndpoint.public(...)`. Public mode sends no MiniProgram access-key
header and has no delivery access control, so do not use it for private or
business-only mini-programs. Prefer GitHub Pages or a CDN over
`raw.githubusercontent.com` for real usage.

## Publisher-Owned Backend

Delivery and business APIs are separate. `MiniProgramEndpoint.apiBaseUri` loads
manifest/screen JSON. A publisher-owned backend is optional and is used only
when the mini-program sends a `miniProgramBackend` action.

```dart
final deliveryContext = MiniProgramDeliveryContext(
  hostApp: 'sample_host',
  sdkVersion: '1.0.0',
  hostVersion: '1.0.0',
  capabilities: <Capability>{Capability.analytics},
);

final endpoints = <String, MiniProgramEndpoint>{
  'aws_coupon_demo': MiniProgramEndpoint(
    apiBaseUri: Uri.parse('https://publisher.example.com/delivery/'),
    accessKey: 'mpk_live_partner_delivery_key',
    backend: MiniProgramBackendEndpoint(
      baseUri: Uri.parse('https://publisher.example.com/api/'),
      requestTimeout: Duration(seconds: 8),
    ),
  ),
};

final config = MiniProgramConfig(
  sdkVersion: '1.0.0',
  source: EndpointRoutingMiniProgramSource(
    endpoints: endpoints,
    deliveryContext: deliveryContext,
  ),
  backendConnector: buildEndpointRoutingBackendConnector(
    endpoints: endpoints,
    deliveryContext: deliveryContext,
  ),
  hostBridge: const NoopHostBridge(),
  capabilityRegistry: CapabilityRegistry(
    const <Capability>[Capability.analytics],
  ),
);
```

Generated host adapters from `miniprogram embed init` wire this connector for
you. Backend calls are lazy: no HTTP client or request is created until a
mini-program action calls the publisher backend.

Mini-programs can also load backend JSON into local mini-program state and bind
simple UI text to that state. Generated mini-program scaffolds include helper
functions for this:

```bash
miniprogram create coupon_app --title "Coupon App" --with-backend mock
cd coupon_app
miniprogram publisher-backend run --port 9090
```

The mock publisher backend is a local HTTP JSON server for development. It is
not a production backend and it does not add Firebase, AWS, or other backend SDK
dependencies to this Flutter SDK.

```dart
miniProgramBackendBuilder(
  requestId: 'home',
  endpoint: 'home/bootstrap',
  cacheTtl: const Duration(seconds: 60),
  loading: StacText(data: 'Loading...'),
  error: StacText(data: '{{backend.home.message}}'),
  child: StacColumn(
    children: [
      StacText(data: '{{backend.home.data.title}}'),
      StacText(data: '{{backend.home.data.user.name}}'),
    ],
  ),
)
```

The builder starts the query only when it renders, stores the result under the
`requestId`, and does not refetch on normal rebuilds. A button or refresh action
can update the same state:

```dart
StacFilledButton(
  onPressed: miniProgramBackendQueryAction(
    requestId: 'home',
    endpoint: 'home/bootstrap',
    forceRefresh: true,
  ),
  child: StacText(data: 'Refresh'),
)
```

For simple lists, provide `itemsPath` and an `itemTemplate`:

```dart
miniProgramBackendBuilder(
  requestId: 'coupons',
  endpoint: 'coupons/list',
  itemsPath: 'data.coupons',
  empty: StacText(data: 'No coupons yet'),
  itemTemplate: StacText(data: '{{item.title}}'),
)
```

Supported bindings include:

```text
{{backend.home.loading}}
{{backend.home.success}}
{{backend.home.errorCode}}
{{backend.home.message}}
{{backend.home.fromCache}}
{{backend.home.data.title}}
{{item.title}}
```

Security rules:

- backend secrets stay on the publisher server; never put Firebase/AWS/custom
  server secrets in mini-program JSON, host app source, APK, IPA, or web JS
- action endpoints must be relative, such as `home/bootstrap`; absolute URLs
  are rejected
- the MiniProgram delivery access key is not user auth and is not sent to the
  publisher backend unless `sendAccessKeyToBackend: true` is set explicitly
- use JWT/OAuth/session tokens through your own backend when user identity is
  required

Performance rules:

- keep backend actions lazy and action-driven
- prefer batch endpoints like `/home/bootstrap`
- use explicit cache TTL only for safe `GET` responses
- keep timeouts short and paginate large results
- serve images from a CDN

Generated host apps usually pass the backend URL at build or run time:

```bash
flutter run -d chrome --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://<api-id>.execute-api.<region>.amazonaws.com/prod/api/
flutter build apk --release --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://<api-id>.execute-api.<region>.amazonaws.com/prod/api/
```

For local backend development:

- Android local default: `http://10.0.2.2:8080/api/`
- desktop, Chrome on the same machine, and iOS simulators:
  `http://127.0.0.1:8080/api/`
- Android USB `adb reverse` flows use `127.0.0.1`, and the SDK retries local
  loopback between `10.0.2.2` and `127.0.0.1` on transport failures before
  surfacing `backend_unreachable`
- physical devices over Wi-Fi should override the host or base URL explicitly

Conditions:

- the local backend must already be running, normally on port `8080`
- Android USB or emulator loopback can still depend on an active `adb reverse`
  session when the device cannot route to `10.0.2.2`
- if the Android device or emulator connects after the backend started, rerun
  backend start or reapply `adb reverse`
- Wi-Fi devices need the computer's LAN IP, not `127.0.0.1`

Host apps can also resolve that default base URI directly:

```dart
final apiBaseUri = LocalMiniProgramBackendDefaults.resolveBaseUri(
  configuredBaseUrl: const String.fromEnvironment(
    'MINI_PROGRAM_BACKEND_BASE_URL',
    defaultValue: '',
  ),
  configuredHost: const String.fromEnvironment(
    'MINI_PROGRAM_BACKEND_HOST',
    defaultValue: '',
  ),
  configuredPort: const int.fromEnvironment(
    'MINI_PROGRAM_BACKEND_PORT',
    defaultValue: LocalMiniProgramBackendDefaults.defaultPort,
  ),
);
```

## Host responsibilities

The shared SDK stays portable by requiring the host app to provide:

- a `HostBridge` implementation for native actions
- a delivery context describing host app, version, and capabilities
- capability registration for supported native features

`MiniProgramPage` includes a scaffolded loading screen by default, so cloud
launches show an app bar and branded progress UI instead of a blank route while
the manifest and entry screen are fetched. Advanced hosts can still pass a
custom `loadingBuilder` to `MiniProgramHost`.

## API layers

- Recommended: `MiniProgramScope(config: buildMiniProgramConfig(), child: MyApp())`.
- Advanced: `MiniProgramController` and `MiniProgramNavigationDelegate` for
  custom runtime or navigation ownership.
- Manual embedding: `MiniProgramRuntimeScope`, `MiniProgramPage`, and
  `MiniProgramHost` remain available for specialized integrations.

`MiniProgramConfig` is treated as immutable after `MiniProgramScope` is
created. To switch environments, recreate the scope with a new key:

```dart
MiniProgramScope(
  key: ValueKey(environment),
  config: config,
  child: const MyApp(),
);
```

For normal apps, use `config`. Controller injection is mainly for tests or
advanced ownership:

```dart
MiniProgramScope(
  controller: customController,
  disposeController: false,
  child: const MyApp(),
);
```

Injected controllers are not disposed by default. Controllers created by the
scope are disposed with the scope. Multiple scopes are technically allowed for
isolated runtimes, but most host apps should keep one `MiniProgramScope` near
the app root.

Custom navigation stays framework-neutral:

```dart
typedef MiniProgramNavigationDelegate = Future<T?> Function<T>(
  BuildContext context,
  MiniProgramLaunchRequest request,
  Widget page,
);

typedef MiniProgramRouteBuilder<T> = Route<T> Function(
  BuildContext context,
  MiniProgramLaunchRequest request,
  Widget page,
);
```

## Notes

- This package is the runtime only. Authoring and local backend workflows live
  in `mini_program_tooling`.
- No manifest loading, network request, Stac initialization, mini-program route,
  or overlay work starts until a mini-program is opened.
