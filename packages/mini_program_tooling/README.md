# mini_program_tooling

CLI tooling for the current mini-program MVP:

- create, build, validate, and preview Mp JSON mini-programs
- publish public static artifact folders
- create/import `appId + artifactBaseUrl` partner packages
- initialize Flutter host integration
- run a local mock Publisher API for optional runtime API testing
- validate and smoke Publisher API Contract V1 runtime endpoints

Mini-program opening uses public static artifacts only. Runtime business data is optional and belongs behind a publisher-owned middle-server API.

## Install

```powershell
dart pub global activate mini_program_tooling
miniprogram doctor
miniprogram --help
```

On Windows, make sure the Dart pub global bin folder is on `PATH`:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

## Common Commands

```powershell
miniprogram create coupon_demo --screen-format mp
miniprogram build --mini-program-root .\coupon_demo
miniprogram validate --mini-program-root .\coupon_demo
miniprogram preview -d chrome --mini-program-root .\coupon_demo
miniprogram publish --target static --mini-program-root .\coupon_demo --output .\coupon_demo\public_mini_program --clean
```

Create a static artifact handoff package:

```powershell
miniprogram partner package coupon_demo `
  --artifact-base-url https://static.example.com/coupon_demo/ `
  --output .\coupon_demo\coupon_demo.partner.json
```

Import into a host:

```powershell
miniprogram embed init --project-root .\coupon_host
miniprogram host endpoint import .\coupon_demo\coupon_demo.partner.json --project-root .\coupon_host
miniprogram host run -d chrome --project-root .\coupon_host
```

Optional local runtime API:

```powershell
miniprogram publisher-api scaffold --template mock --mini-program-root .\coupon_demo
miniprogram publisher-api run --mini-program-root .\coupon_demo --port 9090
miniprogram publisher-api contract init --mini-program-root .\coupon_demo --backend-base-url http://127.0.0.1:9090 --allow-local-http
miniprogram publisher-api contract validate --mini-program-root .\coupon_demo --allow-local-http
miniprogram publisher-api contract smoke --mini-program-root .\coupon_demo --allow-local-http
```

Publisher API Contract V1 is a runtime API standard only. It is not required for opening a mini-program from static artifacts.

Attach a real runtime API URL to a host endpoint only when the mini-program uses runtime actions:

```powershell
miniprogram host endpoint add coupon_demo `
  --artifact-base-url https://static.example.com/coupon_demo/ `
  --backend-base-url https://publisher.example.com/api/coupon_demo/ `
  --project-root .\coupon_host
```

`--backend-base-url` is the current compatibility flag name for the optional runtime middle-server URL, also described as `middleServerApiUrl` in architecture docs.

Runtime API responses should be JSON:

```json
{ "data": { "ok": true }, "traceId": "trace-success" }
```

```json
{ "items": [], "nextCursor": null, "hasMore": false, "traceId": "trace-page" }
```

```json
{ "errorCode": "validation_failed", "message": "Validation failed", "traceId": "trace-error" }
```
