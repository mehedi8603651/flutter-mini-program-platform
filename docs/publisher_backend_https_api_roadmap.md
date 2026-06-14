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

## Future Work

- document request headers that are safe for runtime API calls
- add typed examples for search, pagination, form submit, file metadata, and order history
- add retry and trace ID recommendations
- add example middle-server implementations outside the core platform repo
- keep static artifact delivery independent from runtime API implementation choices
