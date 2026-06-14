# Publisher API Runtime Contract Roadmap

Publisher API Contract V1 is a runtime API standard only. It is not part of the host opening contract.

## Current Boundary

- Host opening uses `appId + artifactBaseUrl`.
- Static artifacts are public mini-program UI bundles.
- Runtime API config is optional.
- Runtime API calls go to a publisher-owned HTTPS middle-server.
- The middle-server owns auth, database access, payments, files, secrets, external APIs, admin logic, and business rules.

## Current Runtime Actions

The runtime API supports existing provider-neutral actions:

- `Mp.backend.call`
- `Mp.backend.query`
- `Mp.lazy.chunk`
- backend load-more/search actions
- form submit and other custom runtime actions where configured

## CLI Setup

Install the global CLI:

```powershell
dart pub global activate mini_program_tooling
miniprogram doctor
```

Create a local mock middle-server for development:

```powershell
miniprogram publisher-api scaffold --template mock --mini-program-root D:\coupon_demo
miniprogram publisher-api run --mini-program-root D:\coupon_demo --port 9090
```

Create and smoke the runtime API contract:

```powershell
miniprogram publisher-api contract init `
  --mini-program-root D:\coupon_demo `
  --backend-base-url http://127.0.0.1:9090 `
  --allow-local-http
miniprogram publisher-api contract validate --mini-program-root D:\coupon_demo --allow-local-http
miniprogram publisher-api contract smoke --mini-program-root D:\coupon_demo --allow-local-http
```

`--backend-base-url` is the current Contract V1 compatibility field. In product docs and architecture discussions, call this the optional `middleServerApiUrl`.

## Contract V1 Fixtures

Keep smoke fixtures small and predictable:

```json
{ "data": { "ok": true }, "traceId": "trace-success" }
```

```json
{ "errorCode": "validation_failed", "message": "Validation failed", "traceId": "trace-error" }
```

```json
{ "items": [], "nextCursor": null, "hasMore": false, "traceId": "trace-page" }
```

Session/auth failures should use the same generic error envelope shape with an appropriate status code.

## Error Handling Rules

Middle-server routes should return JSON for both success and failure. The runtime can then bind predictable fields into UI state.

- Use `traceId` on every response when possible.
- Use stable `errorCode` values, such as `validation_failed`, `unauthorized`, `forbidden`, `not_found`, `rate_limited`, and `server_error`.
- Return pagination as `{ "items": [], "nextCursor": null, "hasMore": false }`.
- For `Mp.lazy.chunk`, keep prior loaded items visible when a later page fails.
- For no configured runtime API URL, actions should enter a predictable failure state instead of crashing.
- Auth, database, payment, provider SDKs, secrets, and admin logic stay inside the middle-server.

Recommended HTTP statuses:

| Status | Meaning |
| --- | --- |
| `200` | Success. |
| `400` | Invalid request or validation failure. |
| `401` | User session expired or missing authentication. |
| `403` | User is authenticated but not allowed. |
| `404` | Route or resource not found. |
| `409` | Conflict, duplicate, or stale update. |
| `429` | Rate limited. |
| `500` | Server error. |
| `503` | Temporary upstream/database outage. |

## Distribution Recommendation

Keep static artifacts and runtime API deployment independent:

- `artifactBaseUrl`: public static files for manifests, screen JSON, assets, and metadata
- `middleServerApiUrl`: HTTPS API for dynamic data and user actions

A middle-server can technically serve static artifacts too, but the recommended production setup is a simple static host/CDN for artifacts and a separate API path for runtime behavior. If both use the same domain, keep the paths separate.

## Future Work

- add typed examples for search, pagination, form submit, file metadata, and order history
- add retry and trace ID recommendations
- add example middle-server implementations outside the core platform repo
- keep static artifact delivery independent from runtime API implementation choices
