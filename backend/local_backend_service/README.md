# local_backend_service

Pure Dart local static artifact service for mini-program frontend delivery.
The package name remains `local_backend_service` for compatibility.

## What it does

- serves manifest JSON from `backend/api/manifests`
- serves screen JSON from `backend/api/screens`
- applies local rollout rules for `latest` manifest selection
- enforces capability-aware manifest delivery when policy files exist
- returns JSON `404` and `400` responses instead of raw file-server behavior
- gives the repo a real local artifact host before production static hosting is
  configured

## Run

```powershell
cd D:\flutter-mini-program-platform\backend\local_backend_service
dart pub get
dart run bin\server.dart
```

If the default port is busy:

```powershell
dart run bin\server.dart --port=9135
```

Default base URL:

- `http://127.0.0.1:8080`

## Endpoints

- `GET /health`
- `GET /api/manifests/:id/latest`
- `GET /api/manifests/:id/latest.json`
- `GET /api/manifests/:id/versions/:version`
- `GET /api/manifests/:id/versions/:version.json`
- `GET /api/screens/:id/:version/:screenId`
- `GET /api/screens/:id/:version/:screenId.json`

## Query-aware latest delivery

When a mini-program has rollout rules or capability policies, the `latest`
manifest route can use query parameters such as:

- `hostApp`
- `sdkVersion`
- `capabilities`

`sdkVersion` is the host runtime compatibility version used for manifest
`sdkVersionRange` checks. It is not the Dart pub package version of
`mini_program_sdk`.

For the current `profile_center` sample, a missing required capability returns
`412` with a JSON error body instead of a manifest.

The current sample also proves backend-side version selection:

- `super_app_host` resolves `latest` to `profile_center` `1.1.0`
- `partner_app_host` resolves `latest` to `profile_center` `1.0.0`

## Verification

```powershell
dart test
dart analyze
```
