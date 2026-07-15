# Embed Mini-Programs In An Existing Flutter App

This guide wires an existing Flutter app to open public static mini-program artifacts.

## 1. Initialize Host Integration

```powershell
miniprogram embed init --project-root D:\my_host_app
```

This creates the complete integration under `lib/mini_program/`. Ordinary host
UI imports only `mini_program.dart`; host-owned setup, bridge, and accepted
policy are preserved by later tooling refreshes.

## 2. Import A Static Artifact Partner Package

```powershell
miniprogram host endpoint import D:\coupon_demo\coupon_demo.partner.json --project-root D:\my_host_app
```

The partner package should contain the mini-program `appId` and `artifactBaseUrl`.

Manual endpoint add is also supported:

```powershell
miniprogram host endpoint add coupon_demo `
  --artifact-base-url https://static.example.com/coupon_demo/ `
  --project-root D:\my_host_app
```

## 3. Optional Runtime API

When a mini-program uses runtime actions, it declares its Publisher API in
root `publisher_backend.json`. Build the artifact and package the partner
handoff from that mini-program root, then import and accept the request:

```powershell
miniprogram partner package coupon_demo `
  --artifact-base-url https://static.example.com/coupon_demo/ `
  --mini-program-root D:\coupon_demo `
  --output D:\coupon_demo\coupon_demo.partner.json
miniprogram host endpoint import D:\coupon_demo\coupon_demo.partner.json `
  --project-root D:\my_host_app `
  --accept-requested-policy
```

The host owns only `accepted.publisherApi.enabled`; the artifact owns the
Publisher API URL.

The runtime API is a publisher-owned middle-server. It handles auth, database access, payments, files, secrets, external APIs, admin logic, and business rules. It should return JSON success, pagination, and error envelopes:

```json
{ "data": { "ok": true }, "traceId": "trace-success" }
```

```json
{ "items": [], "nextCursor": null, "hasMore": false, "traceId": "trace-page" }
```

```json
{ "errorCode": "validation_failed", "message": "Validation failed", "traceId": "trace-error" }
```

## Optional Android Current Location

A handoff may request `requestedPermissions.location` with `approximate` and
`whenInUse`. Importing normally creates a denied accepted policy; review it and
enable it manually or use `--accept-requested-policy`. Install the reusable
Android provider once in the host:

```powershell
miniprogram host capability init location `
  --platform android `
  --project-root D:\my_host_app
```

This installs `ACCESS_COARSE_LOCATION`, a host-owned Kotlin MethodChannel, and
the provider registration in `mini_program_host_setup.dart`. It does not accept
location for any mini-program. The same provider supports any accepted app
that needs explicit, one-time approximate foreground location; it contains no
Weather-specific behavior.

## 4. Launch From UI

Import the public barrel and use the generated registry launcher:

```dart
import 'mini_program/mini_program.dart';

FilledButton(
  onPressed: () {
    openRegisteredMiniProgram(
      context,
      MiniPrograms.couponDemo,
    );
  },
  child: const Text('Open Coupon Demo'),
)
```

At application startup, await `buildHostMiniProgramConfig()` and pass the
result to the root `MiniProgramScope`. It automatically uses every imported
endpoint.

## 5. Run

```powershell
miniprogram host run -d chrome --project-root D:\my_host_app
```

Opening the mini-program does not require runtime API config. The host fetches the manifest and screen/static artifacts from `artifactBaseUrl`.
