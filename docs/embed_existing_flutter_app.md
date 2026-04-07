# Embed Mini-Programs In An Existing Flutter App

This guide is for teams that already have a Flutter app and want to open one or
more portable mini-programs inside it.

The intended v1 flow is:

1. add `mini_program_sdk` and `mini_program_contracts`
2. implement an app-owned `HostBridge`
3. declare supported capabilities
4. create one shared `MiniProgramRuntime`
5. wrap your app or feature root with `MiniProgramRuntimeScope`
6. push `MiniProgramPage(miniProgramId: '...')` from any normal button

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

## 2. Implement an app-owned HostBridge

Keep this app-specific. The shared SDK should not know your route names,
analytics stack, or native flows.

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

Plain `Navigator` example:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MiniProgramPage(
          miniProgramId: 'coupon_center',
          title: 'Coupon Center',
        ),
      ),
    );
  },
  child: const Text('Open Mini Program'),
)
```

The same app can open many mini-programs:

- `MiniProgramPage(miniProgramId: 'coupon_center')`
- `MiniProgramPage(miniProgramId: 'feedback_form')`
- `MiniProgramPage(miniProgramId: 'profile_center')`

## 6. Apps using go_router or custom routing

`MiniProgramPage` is just a widget. You do not need to use `MaterialPageRoute`.

If your app already uses `go_router`, a custom route delegate, or another
navigation layer, register `MiniProgramPage` there the same way you would any
other Flutter page widget.

## Notes

- `MiniProgramPage` is the ergonomic embedded API for existing apps.
- `MiniProgramHost` remains the low-level primitive for advanced integrations.
- Mini-program internal page-to-page routing is intentionally deferred for a
  later milestone; v1 embedding only standardizes how an existing app opens a
  mini-program by `miniProgramId`.
