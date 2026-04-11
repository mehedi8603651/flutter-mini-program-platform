# mini_program_sdk

Portable runtime SDK for the Flutter mini-program platform.

This package gives Flutter host apps the runtime pieces needed to load,
validate, render, and launch server-delivered mini-programs built with the
shared platform contracts.

## What it includes

- `MiniProgramRuntime` and `MiniProgramRuntimeScope`
- `MiniProgramPage` and `openMiniProgram(...)`
- `MiniProgramHost` for lower-level embedding
- manifest loading and version validation
- capability registry and feature-flag evaluation
- host bridge dispatch for native actions
- Stac-based rendering setup
- in-memory cache helpers for manifests, screens, and assets

## Install

```yaml
dependencies:
  mini_program_sdk: ^0.1.1
  mini_program_contracts: ^0.1.0
```

For monorepo contributor work, keep `pubspec_overrides.yaml` so the package
uses the local `mini_program_contracts` checkout.

## Minimal usage

```dart
final runtime = MiniProgramRuntime(
  sdkVersion: '1.0.0',
  source: HttpMiniProgramSource.fromDeliveryContext(
    apiBaseUri: Uri.parse('http://10.0.2.2:8080/api/'),
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
  hostBridge: hostBridge,
  capabilityRegistry: CapabilityRegistry(
    const <Capability>[
      Capability.analytics,
      Capability.nativeNavigation,
    ],
  ),
  cacheBundle: MiniProgramCacheBundle.inMemory(),
);

runApp(
  MiniProgramRuntimeScope(
    runtime: runtime,
    child: const MaterialApp(
      home: MiniProgramPage(miniProgramId: 'coupon_center'),
    ),
  ),
);
```

For local backend development:

- Android emulator default: `http://10.0.2.2:8080/api/`
- Desktop or `adb reverse`: `http://127.0.0.1:8080/api/`
- local HTTP transport failures retry between those two loopback hosts before
  surfacing `backend_unreachable`

## Host responsibilities

The shared SDK stays portable by requiring the host app to provide:

- a `HostBridge` implementation for native actions
- a delivery context describing host app, version, and capabilities
- capability registration for supported native features

## Notes

- This package is the runtime only. Authoring and local backend workflows live
  in `mini_program_tooling`.
- `MiniProgramPage` is the preferred high-level entrypoint for existing Flutter
  apps.
- `MiniProgramHost` remains available for advanced host integrations.
