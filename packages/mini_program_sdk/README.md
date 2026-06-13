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
- Mp JSON parsing, validation, and SDK-owned rendering
- renderer registration for optional feature adapters
- in-memory cache helpers for manifests, screens, and assets
- publisher-owned email/password auth runtime with per-mini-program cached
  sessions
- lazy chunk and paged Publisher API list rendering with manual Load more
  support

## Install

```yaml
dependencies:
  mini_program_sdk: ^0.4.2
  mini_program_contracts: ^0.2.1
```

For monorepo contributor work, keep `pubspec_overrides.yaml` so the package
uses the local `mini_program_contracts` checkout.

Publish these versions only after the Mp engine release gates pass.

## Mp Renderer

`MiniProgramHost` chooses a renderer from manifest metadata:

```json
{
  "screenFormat": "mp",
  "screenSchemaVersion": 1
}
```

Missing `screenFormat` means `mp` with schema version `1`. Unknown formats
fail safely instead of executing unknown content.

Mp screens support:

- basic layout, text, image, card, and button nodes
- internal mini-program navigation
- publisher-owned email auth builders and actions
- Publisher API builders
- lazy chunk and paged backend builders with manual Load more
- safe bindings such as `{{auth.user.email}}`, `{{backend.home.data.title}}`,
  and `{{item.title}}`

The base SDK contains the Mp renderer and has no Stac runtime dependency.

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
partner packages, public static artifact delivery, and cloud artifact hosting
from VS Code.

For protected Mp JSON Firebase/AWS handoff and cross-platform host verification,
see the repo's
[Mp engine cloud end-to-end guide](../../docs/mp_engine_cloud_e2e_guide.md).

## Minimal usage

For most host apps, prefer generating the host wiring with
`miniprogram embed init`. That creates `lib/mini_program/`, adds the SDK
dependencies to `pubspec.yaml`, and gives you `buildMiniProgramConfig(...)`
plus `openAppMiniProgram(...)`.

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
        capabilities: <CapabilityId>{
          CapabilityIds.analytics,
          CapabilityIds.nativeNavigation,
        },
        platform: 'android',
        locale: 'en-US',
      ),
    ),
    hostBridge: const NoopHostBridge(),
    capabilityRegistry: CapabilityRegistry(
      const <CapabilityId>[
        CapabilityIds.analytics,
        CapabilityIds.nativeNavigation,
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
mini-program artifact endpoints and compared with manifest `sdkVersionRange`
values. It is not the pub package version of `mini_program_sdk`; for example,
the package can be `0.3.7` while the runtime compatibility version remains
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
      capabilities: <CapabilityId>{CapabilityIds.analytics},
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
    const <CapabilityId>[CapabilityIds.analytics],
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
For protected artifact access, the artifact endpoint should validate the
`X-Mini-Program-Access-Key` header against its per-mini-program key policy, so
revoking one partner key does not affect other partners using the same
mini-program.

For public/static demos, open-source samples, GitHub Pages, CDN, S3 public
hosting, Cloudflare Pages, Netlify, or Vercel static hosting, use
`MiniProgramEndpoint.public(...)`. Public mode sends no MiniProgram access-key
header and has no delivery access control, so do not use it for private or
business-only mini-programs. Prefer GitHub Pages or a CDN over
`raw.githubusercontent.com` for real usage.

## Publisher API Backend

Static frontend artifact delivery and business APIs are separate.
`MiniProgramEndpoint.apiBaseUri` loads manifest/screen JSON. A publisher-owned
Publisher API backend is optional and is used only when the mini-program sends a
`miniProgramBackend` action.

```dart
final deliveryContext = MiniProgramDeliveryContext(
  hostApp: 'sample_host',
  sdkVersion: '1.0.0',
  hostVersion: '1.0.0',
  capabilities: <CapabilityId>{CapabilityIds.analytics},
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
    const <CapabilityId>[CapabilityIds.analytics],
  ),
);
```

Generated host adapters from `miniprogram embed init` wire this connector for
you. Publisher API calls are lazy: no HTTP client or request is created until a
mini-program action calls the Publisher API backend.

Mini-programs can also load Publisher API JSON into local mini-program state
and bind simple UI text to that state. New scaffolds generate Mp authoring helpers for
this:

```bash
miniprogram create coupon_app --title "Coupon App" --with-backend mock
cd coupon_app
miniprogram publisher-backend run --port 9090
```

The mock Publisher API is a local HTTP JSON server for development. It is
not a production backend and it does not add Firebase, AWS, or other provider
SDK dependencies to this Flutter SDK.

Mp screens use `Mp.backendBuilder(...)`, `Mp.lazy.chunk(...)`,
`Mp.pagedBackendBuilder(...)`, and backend actions from `mini_program_ui`. The
SDK executes those provider-neutral JSON nodes through
`MiniProgramBackendStore`; requests remain lazy until the corresponding runtime
node or action is used.

The default provider-neutral response shape is:

```json
{
  "items": [],
  "nextCursor": null,
  "hasMore": false
}
```

The SDK requests:

```text
GET coupons/list?limit=20
GET coupons/list?limit=20&cursor=<nextCursor>
```

Loaded pages are appended in SDK state. Useful paged bindings include:

```text
{{backend.coupons.items}}
{{backend.coupons.itemCount}}
{{backend.coupons.pageCount}}
{{backend.coupons.hasMore}}
{{backend.coupons.nextCursor}}
{{backend.coupons.loadingMore}}
```

`pagedBackendBuilder` is provider-neutral. Firebase, AWS, or custom Publisher
API backends should expose matching paged routes such as
`GET /coupons/list?limit=20&cursor=...`.

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

### Publisher auth

For publisher-owned email/password auth, configure an auth controller alongside
the Publisher API connector. The host app does not need Firebase SDK config,
Firebase project access, or Publisher API secrets.

```dart
final authController = MiniProgramAuthController.secure();

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
  authController: authController,
  disposeAuthController: true,
  hostBridge: const NoopHostBridge(),
  capabilityRegistry: CapabilityRegistry(
    const <CapabilityId>[CapabilityIds.analytics],
  ),
);
```

Mp JSON can use `auth.*` actions and the `authBuilder` node. The SDK shows the
native email/password auth sheet for `auth.showEmailAuth`, caches only
backend-issued tokens, restores cached sessions on the next launch, and sends
`Authorization: Bearer <idToken>` on Publisher API calls when the
mini-program is signed in.

```text
{{auth.authenticated}}
{{auth.loading}}
{{auth.user.uid}}
{{auth.user.email}}
{{auth.errorCode}}
{{auth.message}}
```

Auth sessions are stored per mini-program id. `SecureMiniProgramAuthStore` uses
`flutter_secure_storage`; Android/iOS are the primary targets. Web persistence
is supported by the dependency but should be treated as lower security and used
only on HTTPS or localhost. The secure storage dependency currently requires
Android min SDK 23 for its default encryption path.

Security rules:

- backend secrets stay on the publisher server; never put Firebase/AWS/custom
  server secrets in mini-program JSON, host app source, APK, IPA, or web JS
- action endpoints must be relative, such as `home/bootstrap`; absolute URLs
  are rejected
- the MiniProgram delivery access key is not user auth and is not sent to the
  Publisher API unless `sendAccessKeyToBackend: true` is set explicitly
- publisher auth tokens are never exposed through bindings or action results;
  only safe user/session state is available to mini-program UI

Performance rules:

- keep Publisher API actions lazy and action-driven
- prefer batch endpoints like `/home/bootstrap`
- use explicit cache TTL only for safe `GET` responses
- keep timeouts short and paginate large results
- serve images from a CDN

Generated host apps usually pass the artifact endpoint URL at build or run time:

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
- No manifest loading, network request, mini-program route, or overlay work
  starts until a mini-program is opened.
