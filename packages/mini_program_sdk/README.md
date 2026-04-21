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
  mini_program_sdk: ^0.1.3
  mini_program_contracts: ^0.1.0
```

For monorepo contributor work, keep `pubspec_overrides.yaml` so the package
uses the local `mini_program_contracts` checkout.

## Minimal usage

For most host apps, prefer generating the adapter with
`miniprogram embed init`. That creates `lib/mini_program/`, adds the SDK
dependencies to `pubspec.yaml`, and gives you `MiniProgramAppShell` plus
`openAppMiniProgram(...)`.

```dart
import 'package:flutter/material.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  final runtime = MiniProgramRuntime(
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
    MiniProgramRuntimeScope(
      runtime: runtime,
      child: const MaterialApp(
        home: MiniProgramPage(
          miniProgramId: 'my_coupon_app',
          title: 'My Coupon App',
        ),
      ),
    ),
  );
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

## Notes

- This package is the runtime only. Authoring and local backend workflows live
  in `mini_program_tooling`.
- `MiniProgramPage` is the preferred high-level entrypoint for existing Flutter
  apps.
- `MiniProgramHost` remains available for advanced host integrations.
