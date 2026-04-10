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
3. use the generated `MiniProgramAppShell`
4. review the generated app-owned `HostBridge`
5. adjust backend/runtime config only if needed
6. call `openAppMiniProgram(...)` or use `AppMiniProgramLauncherButton`

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
- `lib/mini_program/mini_program_app_shell.dart`
- `lib/mini_program/mini_program_routes.dart`
- `lib/mini_program/app_host_bridge.dart`
- `lib/mini_program/mini_program_runtime_setup.dart`
- `lib/mini_program/native_profile_editor_page.dart`
- `lib/mini_program/mini_program_launcher.dart`
- `lib/mini_program/README.md`

The tool intentionally does **not** rewrite `main.dart` for you, but it now
generates a local `MiniProgramAppShell` so your own app entry can stay very
small.

## Recommended v1 capability set

Start lean:

- `analytics`
- `native_navigation`

Keep `secure_api` and richer auth/session wiring for a later step unless the
old app already has a clear host-owned secure flow ready to integrate.

## 1. Hosted dependencies

```yaml
dependencies:
  mini_program_sdk: ^0.1.0
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MiniProgramAppShell(
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}
```

`MiniProgramAppShell` creates the runtime, wraps the app with
`MiniProgramRuntimeScope`, and wires the generated sample native route.

## 3. Review the generated HostBridge

Keep this app-specific. The shared SDK should not know your route names,
analytics stack, or native flows. The generated file is a starting point, not a
final production bridge.

```dart
class AppHostBridge implements HostBridge {
  AppHostBridge({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

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
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return HostActionResult.failed(
        actionName: ActionNames.openNativeScreen,
        message: 'Navigator not available.',
      );
    }

    await navigator.pushNamed('/profile-editor', arguments: payload.args);
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
final navigatorKey = GlobalKey<NavigatorState>();

final runtime = MiniProgramRuntime(
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
  hostBridge: AppHostBridge(navigatorKey: navigatorKey),
  capabilityRegistry: CapabilityRegistry(
    const <Capability>[
      Capability.analytics,
      Capability.nativeNavigation,
    ],
  ),
  cacheBundle: MiniProgramCacheBundle.inMemory(),
);
```

Most apps do not need to touch this immediately. The generated
`MiniProgramAppShell` already calls it for you.

When the local backend is already running on port `8080`, Android emulator
development should normally work with:

```powershell
flutter run -d emulator-5554
```

Use `--dart-define=MINI_PROGRAM_BACKEND_BASE_URL=...` only when you need to
override the generated local default.

## 5. Open mini-programs from ordinary app buttons

Recommended helper-based example:

```dart
openAppMiniProgram(
  context,
  miniProgramId: 'coupon_center',
  title: 'Coupon Center',
);
```

The same app can open many mini-programs:

- `openAppMiniProgram(context, miniProgramId: 'coupon_center')`
- `openAppMiniProgram(context, miniProgramId: 'feedback_form')`
- `openAppMiniProgram(context, miniProgramId: 'profile_center')`

Or use the generated launcher widget:

```dart
const AppMiniProgramLauncherButton(
  miniProgramId: 'coupon_center',
  title: 'Coupon Center',
  child: Text('Open Mini Program'),
)
```

If you prefer to keep control over route construction, the shared SDK still
supports pushing `MiniProgramPage(miniProgramId: '...')` directly.

## 6. Apps using go_router or custom routing

`MiniProgramPage` is just a widget. You do not need to use `MaterialPageRoute`.

If your app already uses `go_router`, a custom route delegate, or another
navigation layer, register `MiniProgramPage` there the same way you would any
other Flutter page widget.

## Notes

- `MiniProgramPage` is the ergonomic embedded API for existing apps.
- `MiniProgramHost` remains the low-level primitive for advanced integrations.
- `miniprogram embed init` is the quickest way to generate the adapter layer
  for an old Flutter app.
- `MiniProgramAppShell` is the lowest-friction app entrypoint. It keeps
  `main.dart` small and hides the runtime-scope boilerplate.
- Internal mini-program page-to-page routing now happens inside the shared SDK
  by `screenId`. Existing apps still open a mini-program the same way:
  `MiniProgramPage(miniProgramId: '...')`.
- Keep `openNativeScreen` for true host-owned pages only. Portable next-page
  flow should stay inside the mini-program whenever possible.
