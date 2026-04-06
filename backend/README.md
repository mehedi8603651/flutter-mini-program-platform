# backend

Local backend area for mini-program delivery.

## What it is

For the current MVP:

- `backend/api/` holds published JSON artifacts
- `backend/local_backend_service/` serves those artifacts through a real Dart HTTP service

The source of truth still lives in `mini_programs/<id>`.

## Current sample

`profile_center` is published into:

- `api/manifests/profile_center/latest.json`
- `api/manifests/profile_center/versions/1.1.0.json`
- `api/manifests/profile_center/versions/1.0.0.json`
- `api/screens/profile_center/1.1.0/profile_center_home.json`
- `api/screens/profile_center/1.0.0/profile_center_home.json`
- `api/rollout-rules/profile_center.json`
- `api/capability-policies/profile_center.json`

`feedback_form` is published into:

- `api/manifests/feedback_form/latest.json`
- `api/manifests/feedback_form/versions/1.1.0.json`
- `api/manifests/feedback_form/versions/1.0.0.json`
- `api/screens/feedback_form/1.1.0/feedback_form_home.json`
- `api/screens/feedback_form/1.0.0/feedback_form_home.json`
- `api/rollout-rules/feedback_form.json`
- `api/capability-policies/feedback_form.json`
- `api/secure-api-policies/feedback_submit.json`

The current rollout sample uses two lanes:

- `super_app_host` receives `profile_center` `1.1.0`
- `partner_app_host` remains on `profile_center` `1.0.0`
- both hosts receive `feedback_form` `1.1.0`
- `latest.json` is still published, but the local backend service can override it through rollout rules when the request includes host context
- rollout rules are now ordered and can match on `hostApp`, `hostVersionRange`, `platform`, `locale`, and optional `tenantId`
- `latest` can also honor an optional `pinnedVersion` query parameter for debug and release-control testing
- `feedback_form` now proves capability-aware delivery for `secure_api`
- latest-manifest responses now include request trace and decision metadata for local operability debugging
- the local backend service now logs request completion and decision context to stdout with a per-request trace ID

## Refresh sample files

After rebuilding a mini-program, republish the local backend sample:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_local_backend.ps1
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_local_backend.ps1 -MiniProgramId feedback_form
```

## Run the real local backend service

```powershell
cd D:\flutter-mini-program-platform\backend\local_backend_service
dart pub get
dart run bin\server.dart
```

If `8080` is already in use, run for example:

```powershell
dart run bin\server.dart --port=9135
```

Then the local backend serves:

- `http://localhost:8080/api/manifests/profile_center/latest.json`
- `http://localhost:8080/api/manifests/profile_center/versions/1.1.0.json`
- `http://localhost:8080/api/manifests/profile_center/versions/1.0.0.json`
- `http://localhost:8080/api/screens/profile_center/1.1.0/profile_center_home.json`
- `http://localhost:8080/api/screens/profile_center/1.0.0/profile_center_home.json`
- `http://localhost:8080/api/manifests/feedback_form/latest.json`
- `http://localhost:8080/api/manifests/feedback_form/versions/1.1.0.json`
- `http://localhost:8080/api/manifests/feedback_form/versions/1.0.0.json`
- `http://localhost:8080/api/screens/feedback_form/1.1.0/feedback_form_home.json`
- `http://localhost:8080/api/screens/feedback_form/1.0.0/feedback_form_home.json`
- `http://localhost:8080/api/secure/feedback/submit`

For `profile_center`, the `latest` manifest route is context-aware. In local
backend mode the host sends:

- `hostApp`
- `sdkVersion`
- `hostVersion`
- `platform`
- `locale`
- optional `tenantId`
- optional `pinnedVersion`
- `capabilities`

Example allowed request:

```text
GET /api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,auth
```

That request resolves `latest` to `profile_center` `1.1.0`.

Example older-version lane:

```text
GET /api/manifests/profile_center/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation
```

That request resolves `latest` to `profile_center` `1.0.0`.

Example rejected request:

```text
GET /api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics
```

That rejected request returns `412` because `native_navigation` is missing.

Example pinned request:

```text
GET /api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,auth&pinnedVersion=1.0.0
```

That request resolves `latest` to the pinned `1.0.0` artifact and returns
`deliveryMetadata` with:

- `selectionMode`
- `decisionReason`
- `resolvedVersion`
- optional `declaredDefaultVersion`
- optional `requestedPinnedVersion`
- optional `matchedRuleId`
- optional `evaluatedRuleIds`
- `traceId`
- `deliveryContext`

The response headers also now include:

- `x-backend-trace-id`
- `x-mini-program-selection-mode`
- `x-mini-program-decision-reason`
- optional `x-mini-program-matched-rule-id`

## Decision inspection route

The local backend now also exposes a debug-only inspection route:

```text
GET /api/debug/manifests/:miniProgramId/decision
```

Use the same query parameters you would send to `latest.json`. The response
always returns a structured inspection report with:

- `outcome`: `resolved` or `rejected`
- `simulatedStatusCode`: the status `latest.json` would have returned
- `decision`: selected version and rule metadata when available
- `rollout`: default version plus per-rule match/mismatch inspection
- `capabilityPolicy`: current latest-manifest policy summary
- `manifestSummary` or `rejection`
- `traceId`

Example:

```text
GET /api/debug/manifests/profile_center/decision?hostApp=super_app_host&sdkVersion=1.0.0&hostVersion=1.0.0&platform=android&locale=en-US&capabilities=analytics,native_navigation,auth
```

This is meant for local operability work only. It helps explain why a request
matched a rollout rule, fell back to default, or was rejected before the host
tries to render the mini-program.

You can call it directly with the repo wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\inspect_delivery.ps1 `
  -MiniProgramId profile_center `
  -HostApp super_app_host `
  -SdkVersion 1.0.0 `
  -HostVersion 1.0.0 `
  -Platform android `
  -Locale en-US `
  -Capabilities analytics,native_navigation,auth
```

Or with the pure Dart CLI:

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_tooling
dart run bin\inspect_delivery.dart `
  --mini-program profile_center `
  --host-app super_app_host `
  --sdk-version 1.0.0 `
  --host-version 1.0.0 `
  --platform android `
  --locale en-US `
  --capabilities analytics,native_navigation,auth
```

Use `--output json` when you want to inspect the raw response body.

`super_app_host` can already consume these URLs through
`HttpMiniProgramSource` by launching with:

```powershell
flutter run --dart-define=SUPER_APP_SOURCE_MODE=local_backend --dart-define=SUPER_APP_BACKEND_BASE_URL=http://127.0.0.1:8080/api/
```

## Secure API sample

The local backend now also exposes a real secure feedback endpoint:

```text
POST /api/secure/feedback/submit
```

Required headers:

- `authorization: Bearer <token>`
- `x-host-app`
- `x-host-version`
- `x-host-user-id`
- optional `x-host-tenant-id`

Required JSON body:

- `source`
- `message`
- optional `flow`

The current local policy is defined in:

- `api/secure-api-policies/feedback_submit.json`

It only allows:

- `POST`
- `super_app_host` and `partner_app_host`
- `feedback_form` as the source mini-program

The current local auth/failure sample also supports:

- `expired-` bearer tokens -> `401 secure_api_session_expired`
- blocked demo users from `blockedUserIds` -> `403 secure_api_forbidden`

Secure endpoint responses also include:

- `traceId` in the JSON body
- `x-backend-trace-id` in response headers

This makes it easier to correlate host fallback diagnostics with local backend
logs while you are still running the platform entirely on your machine.

## Package verification

```powershell
cd D:\flutter-mini-program-platform\backend\local_backend_service
dart test
dart analyze
```
