# Embed Mini-Programs In An Existing Flutter App

This guide is for teams that already have a Flutter app and want to open one or
more portable mini-programs inside it.

The intended v1 flow is:

1. run `init_mini_program_embedding`
2. add `mini_program_sdk` and `mini_program_contracts`
3. review the generated app-owned `HostBridge`
4. create one shared `MiniProgramRuntime`
5. wrap your app or feature root with `MiniProgramRuntimeScope`
6. call `openAppMiniProgram(...)` or use `AppMiniProgramLauncherButton`

## Quick start with the initializer

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\init_mini_program_embedding.ps1 `
  -ProjectRoot D:\myflutterproject
```

This generates:

- `lib/mini_program/mini_program_routes.dart`
- `lib/mini_program/app_host_bridge.dart`
- `lib/mini_program/mini_program_runtime_setup.dart`
- `lib/mini_program/native_profile_editor_page.dart`
- `lib/mini_program/mini_program_launcher.dart`
- `lib/mini_program/README.md`

The tool intentionally does **not** rewrite `main.dart` or your app shell. It
generates the adapter layer and leaves final integration with your existing app
routes and widget tree under developer control.

## Recommended v1 capability set

Start lean:

- `analytics`
- `native_navigation`

Keep `secure_api` and richer auth/session wiring for a later step unless the
old app already has a clear host-owned secure flow ready to integrate.

## 1. Add dependencies

```yaml
dependencies:
  mini_program_sdk:
    path: D:/flutter-mini-program-platform/packages/mini_program_sdk
  mini_program_contracts:
    path: D:/flutter-mini-program-platform/packages/mini_program_contracts
```

## 2. Review the generated HostBridge

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

## 3. Build one shared runtime

```dart
final navigatorKey = GlobalKey<NavigatorState>();

final runtime = MiniProgramRuntime(
  sdkVersion: '1.0.0',
  source: HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: Uri.parse('http://10.0.2.2:8080/api/'),
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

## 4. Scope the runtime once

Put the runtime above the part of your app that needs mini-program access.

```dart
MiniProgramRuntimeScope(
  runtime: runtime,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    home: const MyHomePage(),
  ),
)
```

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
- `init_mini_program_embedding` is the quickest way to generate the adapter
  layer for an old Flutter app.
- Internal mini-program page-to-page routing now happens inside the shared SDK
  by `screenId`. Existing apps still open a mini-program the same way:
  `MiniProgramPage(miniProgramId: '...')`.
- Keep `openNativeScreen` for true host-owned pages only. Portable next-page
  flow should stay inside the mini-program whenever possible.
