# Static Artifact And Runtime API E2E Guide

This guide shows the current MVP flow from global CLI setup to host testing.

The boundary is:

- mini-program UI opens from public static artifacts using `appId` and `artifactBaseUrl`
- runtime business data is optional and goes through a publisher-owned middle-server API
- host opening does not require auth config, database config, payment config, secrets, provider SDKs, or runtime API config

## 1. Install And Check The CLI

Install the published global tooling:

```powershell
dart pub global activate mini_program_tooling
```

Make sure the Dart pub global bin folder is on `PATH`. On Windows this is usually:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

Check the CLI:

```powershell
miniprogram doctor
miniprogram capabilities
miniprogram --help
```

If you use VS Code, install the Marketplace extension and set `miniProgram.cliPath` only when the `miniprogram` command is not available on `PATH`.

## 2. Create, Build, Validate, Preview

```powershell
miniprogram create bd_area_search --output-root D:\bd_area_search --screen-format mp
miniprogram build --mini-program-root D:\bd_area_search
miniprogram validate --mini-program-root D:\bd_area_search
miniprogram preview -d chrome --mini-program-root D:\bd_area_search
```

Preview opens the static mini-program UI. A runtime API is only needed when the screen uses actions such as `Mp.backend.call`, `Mp.backend.query`, `Mp.lazy.chunk`, search/load-more, or form submit.

## 3. Publish Static Artifacts

```powershell
miniprogram publish `
  --target static `
  --mini-program-root D:\bd_area_search `
  --output D:\bd_area_search\public_mini_program `
  --clean
```

Serve `D:\bd_area_search\public_mini_program` from any public static file host or simple HTTP static server. The middle-server API does not need to serve these files. If you want one domain, keep separate paths, for example:

- `https://example.com/mini-programs/bd_area_search/` for static artifacts
- `https://example.com/api/bd-area-search/` for runtime data

## 4. Create A Partner Package

Use the final public static artifact URL:

```powershell
miniprogram partner package bd_area_search `
  --artifact-base-url https://static.example.com/bd_area_search/ `
  --output D:\bd_area_search\bd_area_search.partner.json
```

The package should contain only the operational opening fields: `appId`, `title`, and `artifactBaseUrl`, plus metadata.

## 5. Import Into A Flutter Host

```powershell
flutter create D:\bd_area_host
miniprogram embed init --project-root D:\bd_area_host
miniprogram host endpoint import D:\bd_area_search\bd_area_search.partner.json --project-root D:\bd_area_host
miniprogram host run -d chrome --project-root D:\bd_area_host
```

At this point the host can open the mini-program without any middle-server API URL.

Manual endpoint add is also supported:

```powershell
miniprogram host endpoint add bd_area_search `
  --artifact-base-url https://static.example.com/bd_area_search/ `
  --project-root D:\bd_area_host
```

## 6. Add Optional Runtime Middle-Server API

Use this only when the mini-program needs dynamic data.

For local mock testing:

```powershell
miniprogram publisher-api scaffold --template mock --mini-program-root D:\bd_area_search
miniprogram publisher-api run --mini-program-root D:\bd_area_search --port 9090
miniprogram publisher-api contract init `
  --mini-program-root D:\bd_area_search `
  --backend-base-url http://127.0.0.1:9090 `
  --allow-local-http
miniprogram publisher-api contract validate --mini-program-root D:\bd_area_search --allow-local-http
miniprogram publisher-api contract smoke --mini-program-root D:\bd_area_search --allow-local-http
```

To attach the runtime API to a host endpoint:

```powershell
miniprogram host endpoint add bd_area_search `
  --artifact-base-url https://static.example.com/bd_area_search/ `
  --backend-base-url https://publisher.example.com/api/bd-area-search/ `
  --project-root D:\bd_area_host
```

`--backend-base-url` is the current compatibility flag name for the optional runtime middle-server URL. In docs and architecture, prefer the term `middleServerApiUrl`.

## 7. Middle-Server API Shape

The middle-server can be implemented with any stack. The mini-program runtime only needs HTTPS JSON endpoints.

Success envelope:

```json
{
  "data": {
    "title": "Bangladesh Area Search"
  },
  "traceId": "trace-001"
}
```

Paginated list envelope for `Mp.lazy.chunk`, search/load-more, and paged lists:

```json
{
  "items": [
    {
      "name": "Dhaka",
      "type": "division",
      "latitude": 23.8103,
      "longitude": 90.4125
    }
  ],
  "nextCursor": "page-2",
  "hasMore": true,
  "traceId": "trace-002"
}
```

Error envelope:

```json
{
  "errorCode": "validation_failed",
  "message": "Query must contain at least two characters.",
  "traceId": "trace-003"
}
```

Recommended HTTP status handling:

- `200`: success
- `400`: invalid request or validation failure
- `401`: user session expired or missing authentication
- `403`: authenticated user is not allowed
- `404`: route or resource not found
- `409`: conflict, duplicate, or stale update
- `429`: rate limited
- `500`: server error
- `503`: temporary upstream or database outage

Runtime actions should display an error, empty, or retry state instead of crashing. For repeated data, prefer `Mp.lazy.chunk` so existing items remain visible when load-more fails.

## 8. Status Checks

```powershell
miniprogram workflow status --workspace D:\bd_area_search --json
miniprogram workflow status --workspace D:\bd_area_host --json
```

The host status should show static artifact endpoints. Runtime API config should appear only when you explicitly added it.
