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

The current rollout sample uses two lanes:

- `super_app_host` receives `profile_center` `1.1.0`
- `partner_app_host` remains on `profile_center` `1.0.0`
- `latest.json` is still published, but the local backend service can override it through rollout rules when the request includes host context

## Refresh sample files

After rebuilding `mini_programs/profile_center`, republish the local backend
sample:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_local_backend.ps1
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

For `profile_center`, the `latest` manifest route is context-aware. In local
backend mode the host sends:

- `hostApp`
- `sdkVersion`
- `capabilities`

Example allowed request:

```text
GET /api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&capabilities=analytics,native_navigation,auth
```

That request resolves `latest` to `profile_center` `1.1.0`.

Example older-version lane:

```text
GET /api/manifests/profile_center/latest.json?hostApp=partner_app_host&sdkVersion=1.0.0&capabilities=analytics,native_navigation
```

That request resolves `latest` to `profile_center` `1.0.0`.

Example rejected request:

```text
GET /api/manifests/profile_center/latest.json?hostApp=super_app_host&sdkVersion=1.0.0&capabilities=analytics
```

That rejected request returns `412` because `native_navigation` is missing.

`super_app_host` can already consume these URLs through
`HttpMiniProgramSource` by launching with:

```powershell
flutter run --dart-define=SUPER_APP_SOURCE_MODE=local_backend --dart-define=SUPER_APP_BACKEND_BASE_URL=http://127.0.0.1:8080/api/
```

## Package verification

```powershell
cd D:\flutter-mini-program-platform\backend\local_backend_service
dart test
dart analyze
```
