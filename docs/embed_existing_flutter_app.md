# Embed Mini-Programs In An Existing Flutter App

This guide wires an existing Flutter app to open public static mini-program artifacts.

## 1. Initialize Host Integration

```powershell
miniprogram embed init --project-root D:\my_host_app
```

This adds the generated host adapter files under `lib/mini_program/`.

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

Only add a runtime Publisher API URL when the mini-program uses runtime actions that need server data:

```powershell
miniprogram host endpoint add coupon_demo `
  --artifact-base-url https://static.example.com/coupon_demo/ `
  --backend-base-url https://publisher.example.com/api/ `
  --project-root D:\my_host_app
```

`--backend-base-url` is the current compatibility flag name for the optional runtime middle-server URL. In architecture docs, this is `middleServerApiUrl`.

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

## 4. Launch From UI

Use the generated launcher helper:

```dart
FilledButton(
  onPressed: () {
    openAppMiniProgram(
      context,
      appId: 'coupon_demo',
      title: 'Coupon Demo',
    );
  },
  child: const Text('Open Coupon Demo'),
)
```

## 5. Run

```powershell
miniprogram host run -d chrome --project-root D:\my_host_app
```

Opening the mini-program does not require runtime API config. The host fetches the manifest and screen/static artifacts from `artifactBaseUrl`.
