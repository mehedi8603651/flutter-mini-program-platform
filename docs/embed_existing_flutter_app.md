# Embed Mini-Programs In An Existing Flutter App

This guide is for teams that already have a Flutter app and want to open one or
more portable mini-programs inside it.

Preferred command surface:

```powershell
dart pub global activate mini_program_tooling
cd <existing-flutter-app>
miniprogram embed init
```

Repo-local contributor install:

```powershell
dart pub global activate --source path <repo-root>\packages\mini_program_tooling
```

The intended v1 flow is:

1. run `miniprogram embed init`
2. run `flutter pub get`
3. wrap your app with `MiniProgramScope(config: buildMiniProgramConfig(), child: MyApp())`
4. review the generated app-owned `HostBridge`
5. adjust backend/runtime config only if needed
6. call `openAppMiniProgram(...)` or use `AppMiniProgramLauncher`

## Quick start with the initializer

```powershell
cd <existing-flutter-app>
miniprogram embed init
```

Or, if you are outside the app folder:

```powershell
miniprogram embed init --project-root <existing-flutter-app>
```

This generates:

- `lib/mini_program/mini_program.dart`
- `lib/mini_program/mini_program_routes.dart`
- `lib/mini_program/app_host_bridge.dart`
- `lib/mini_program/mini_program_runtime_setup.dart`
- `lib/mini_program/native_profile_editor_page.dart`
- `lib/mini_program/mini_program_launcher.dart`
- `lib/mini_program/README.md`

The tool intentionally does **not** rewrite `main.dart` for you. It generates
runtime/config helpers only; your app keeps ownership of `MaterialApp`, router,
theme, localization, state management, and navigation setup.

## Recommended v1 capability set

Start lean:

- `analytics`
- `native_navigation`

Keep `secure_api` and richer auth/session wiring for a later step unless the
old app already has a clear host-owned secure flow ready to integrate.

## 1. Hosted dependencies

```yaml
dependencies:
  mini_program_sdk: ^0.2.0
  mini_program_contracts: ^0.1.0
```

`embed init` now patches `pubspec.yaml` to add or replace these dependencies for
you. Run:

```powershell
flutter pub get
```

## 2. Keep `main.dart` small

```dart
import 'package:flutter/material.dart';
import 'mini_program/mini_program.dart';

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
      home: const MyHomePage(),
    );
  }
}
```

This package does not own your Flutter app. It only provides mini-program
capability through `MiniProgramScope`. Your `MaterialApp`, `GetMaterialApp`,
`MaterialApp.router`, GoRouter, theme, localization, state management, routes,
and navigator setup remain fully yours.

Full demo with a button that opens your cloud-published mini-program:

```dart
import 'package:flutter/material.dart';
import 'mini_program/mini_program.dart';

void main() {
  runApp(
    MiniProgramScope(
      config: buildMiniProgramConfig(),
      child: const MyHostApp(),
    ),
  );
}

class MyHostApp extends StatelessWidget {
  const MyHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Mini Host',
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
      appBar: AppBar(title: const Text('Host App Home')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            openAppMiniProgram(
              context,
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
```

## 3. Review the generated HostBridge

Keep this app-specific. The shared SDK should not know your route names,
analytics stack, or native flows. The generated file is a starting point, not a
final production bridge.

```dart
class AppHostBridge implements HostBridge {
  const AppHostBridge({this.openNativeRoute});

  final Future<Object?> Function(
    String routeName,
    Map<String, dynamic> arguments,
  )? openNativeRoute;

  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async {
    debugPrint('[my_app][analytics] ${payload.name} ${payload.properties}');
    return HostActionResult.success(
      actionName: ActionNames.trackEvent,
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

    await routeOpener('/profile-editor', payload.args);
    return HostActionResult.success(actionName: ActionNames.openNativeScreen);
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
```

## 4. Review the generated runtime setup when needed

```dart
final config = MiniProgramConfig(
  sdkVersion: '1.0.0',
  source: HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: Uri.parse(_resolveBackendBaseUrl()),
    deliveryContext: const MiniProgramDeliveryContext(
      hostApp: 'my_existing_app',
      sdkVersion: '1.0.0',
      hostVersion: '3.2.0',
      capabilities: <Capability>{
        Capability.analytics,
        Capability.nativeNavigation,
      },
      platform: 'android',
      locale: 'en-US',
    ),
  ),
  hostBridge: const AppHostBridge(),
  capabilityRegistry: CapabilityRegistry(
    const <Capability>[
      Capability.analytics,
    ],
  ),
  cacheBundle: MiniProgramCacheBundle.inMemory(),
);
```

Most apps do not need to touch this immediately. Pass the generated config into
`MiniProgramScope` near your app root.

`MiniProgramConfig.sdkVersion` is the runtime compatibility version sent to
mini-program delivery backends and compared with manifest `sdkVersionRange`
values. It is not the pub package version of `mini_program_sdk`; for example,
the package can be `0.2.0` while the runtime compatibility version remains
`1.0.0`.

`MiniProgramConfig` is treated as immutable after `MiniProgramScope` is
created. If users need to switch environment or backend config, recreate the
scope with a new key:

```dart
MiniProgramScope(
  key: ValueKey(environmentName),
  config: config,
  child: const MyApp(),
);
```

`MiniProgramScope` creates its controller once, keeps runtime work lazy, and
does not load a manifest, start a network request, initialize Stac, insert an
overlay, or push a route until you call `openMiniProgram()`.

When the local backend is already running on port `8080`, Android emulator
development should normally work with:

```powershell
flutter run -d emulator-5554
```

`miniprogram embed init` also writes Android debug-only cleartext/network
configuration so the generated emulator default can reach
`http://10.0.2.2:8080/api/` without manual manifest edits.

The generated runtime now uses target-aware defaults:

- Android local default: `http://10.0.2.2:8080/api/`
- desktop, Chrome on the same machine, and iOS simulators:
  `http://127.0.0.1:8080/api/`
- Android USB `adb reverse` flows can keep using `127.0.0.1`, and the shared
  SDK retries local loopback between `10.0.2.2` and `127.0.0.1` on transport
  failures

Conditions:

- the local backend should already be running on port `8080`
- Android USB or emulator loopback may still depend on an active `adb reverse`
  session when the device cannot route to `10.0.2.2`
- if the Android device or emulator connects after backend start, rerun
  backend start or reapply `adb reverse`
- physical devices over Wi-Fi should override `MINI_PROGRAM_BACKEND_HOST` with
  the computer's LAN IP

Use a full URL override when needed:

```powershell
flutter run -d windows --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://mini.example.com/api/
```

Or override only the host/port for physical-device Wi-Fi testing:

```powershell
flutter run -d chrome --dart-define=MINI_PROGRAM_BACKEND_HOST=192.168.1.25
flutter run -d chrome --dart-define=MINI_PROGRAM_BACKEND_PORT=8080
```

For AWS cloud-backed delivery, the CLI can now keep the host-side wiring on the
same command surface:

```powershell
cd <existing-flutter-app>
miniprogram embed cloud configure --env my-aws-prod
miniprogram host run -d chrome --env my-aws-prod
```

`embed cloud configure` stores the selected cloud environment under
`.mini_program/host_cloud.json`, and `host run` wraps `flutter run` with the
resolved `MINI_PROGRAM_BACKEND_BASE_URL`.

For a release APK, build with the deployed backend API URL:

```powershell
miniprogram cloud outputs --format dart-define
flutter build apk --release --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://<api-id>.execute-api.<aws-region>.amazonaws.com/prod/api/
```

Use `BackendApiBaseUrl` from `miniprogram cloud outputs`; do not point the host
app at the S3 bucket URL directly.

## 5. Open mini-programs from ordinary app buttons

Recommended helper-based example:

```dart
openAppMiniProgram(
  context,
  appId: 'coupon_center',
  title: 'Coupon Center',
);
```

The same app can open many mini-programs:

- `openAppMiniProgram(context, appId: 'coupon_center')`
- `openAppMiniProgram(context, appId: 'feedback_form')`
- `openAppMiniProgram(context, appId: 'profile_center')`

Or use the generated launcher widget:

```dart
const AppMiniProgramLauncher(
  appId: 'coupon_center',
  title: 'Coupon Center',
  child: Text('Open Mini Program'),
)
```

If you prefer to keep control over route construction, the shared SDK still
supports pushing `MiniProgramPage(miniProgramId: '...')` directly.

## 6. Apps using go_router or custom routing

`MiniProgramScope` does not depend on go_router, GetX, Provider, Bloc, or
Riverpod. Keep those wrappers exactly where your app already owns them.

If your app already uses go_router, GetX, or a custom navigation layer, provide
a `MiniProgramNavigationDelegate` or custom `MiniProgramLaunchOptions` route
builder and connect mini-program launches to your existing navigation code.

API layers:

- Recommended: `MiniProgramScope(config: buildMiniProgramConfig(), child: MyApp())`.
- Advanced: `MiniProgramController` and `MiniProgramNavigationDelegate`.
- Manual embedding: `MiniProgramRuntimeScope`, `MiniProgramPage`, and
  `MiniProgramHost`.

Controller injection is mainly for tests or advanced runtime ownership:

```dart
MiniProgramScope(
  controller: customController,
  disposeController: false,
  child: const MyApp(),
);
```

Injected controllers are not disposed by default. Controllers created by the
scope are disposed with the scope. Multiple scopes are technically allowed for
isolated runtimes, but normal apps should keep one `MiniProgramScope` near the
app root.

Migration from the old generated shell:

```dart
// Before
MiniProgramAppShell(home: const HomePage());

// After
MiniProgramScope(
  config: buildMiniProgramConfig(),
  child: const MyApp(),
);
```

Common host-owned shapes:

```dart
MiniProgramScope(config: buildMiniProgramConfig(), child: const MyMaterialApp());

MiniProgramScope(config: buildMiniProgramConfig(), child: const MyRouterApp());
// MyRouterApp can return MaterialApp.router or your GoRouter setup.

MiniProgramScope(config: buildMiniProgramConfig(), child: const MyGetApp());
// MyGetApp can return GetMaterialApp when the host app uses GetX.

MiniProgramScope(
  config: buildMiniProgramConfig(),
  child: MultiProvider(providers: appProviders, child: const MyApp()),
);

MiniProgramScope(
  config: buildMiniProgramConfig(),
  child: ProviderScope(child: const MyApp()),
);

MiniProgramScope(
  config: buildMiniProgramConfig(),
  child: BlocProvider(create: (_) => AppBloc(), child: const MyApp()),
);
```

## Notes

- `MiniProgramScope` is the recommended app-level API for existing apps.
- `MiniProgramHost` remains the low-level primitive for advanced integrations.
- `miniprogram embed init` is the quickest way to generate the adapter layer
  for an old Flutter app.
- Internal mini-program page-to-page routing now happens inside the shared SDK
  by `screenId`. Existing apps still open a mini-program the same way:
  `MiniProgramScope.of(context).openMiniProgram(appId: '...')`.
- Keep `openNativeScreen` for true host-owned pages only. Portable next-page
  flow should stay inside the mini-program whenever possible.
