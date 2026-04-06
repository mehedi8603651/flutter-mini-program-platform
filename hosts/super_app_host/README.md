# super_app_host

First-party Flutter host app for the portable mini-program platform.

## What it proves

- installs `mini_program_sdk`
- registers host capabilities
- implements a concrete `HostBridge`
- loads one built mini-program through `MiniProgramSource`
- loads multiple built mini-programs through `MiniProgramSource`
- renders the mini-program with the shared SDK
- executes allowlisted `secure_api` calls through host-side services and the host bridge
- opens a host-owned native screen through `openNativeScreen`
- can switch between bundled asset delivery and local backend HTTP delivery
- uses file-backed manifest and screen caches on real devices, with in-memory fallback in tests
- shows an offline notice when stale cached content is rendered
- persists standard Stac network image assets to local files when entry-screen caching is allowed

## Current local flow

1. Launch the app.
2. Open `Profile Center` or `Feedback Form` from the host list.
3. Render the portable screen through `MiniProgramHost`.
4. Trigger `callSecureApi`, `trackEvent`, or `openNativeScreen` from the mini-program.
5. Use `Preview capability failure` to confirm the SDK rejects unsupported capability sets with controlled fallback UI.

`callSecureApi` now goes through:

- `lib/services/auth_session_service.dart`
- `lib/services/secure_api_service.dart`

The bridge stays thin and delegates network/session work to those services.
The local auth model now supports seeded states for testing:

- `authenticated`
- `signed_out`
- `expired`
- `blocked`

## Source of truth

The actual Stac-authored mini-programs live in:

- `mini_programs/profile_center`
- `mini_programs/feedback_form`

For local host proof, this app currently bundles a copied snapshot of:

- `mini_programs/profile_center/manifest.json`
- `mini_programs/profile_center/stac/.build/screens/profile_center_home.json`
- `mini_programs/feedback_form/manifest.json`
- `mini_programs/feedback_form/stac/.build/screens/feedback_form_home.json`

Those files are loaded as Flutter assets through `LocalMiniProgramSource`.
The current bundled snapshots are:

- `profile_center` `1.1.0`
- `feedback_form` `1.1.0`
Refresh them after rebuilding the mini-program:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\sync_assets.ps1
```

## Local backend mode

This host defaults to bundled assets so it can run without a server.

To test local backend delivery:

1. Publish the current mini-program into `backend/api/`
2. Start the real local backend service
3. Launch the host in `local_backend` mode

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_local_backend.ps1
cd D:\flutter-mini-program-platform\backend\local_backend_service
dart pub get
dart run bin\server.dart
flutter run --dart-define=SUPER_APP_SOURCE_MODE=local_backend --dart-define=SUPER_APP_BACKEND_BASE_URL=http://127.0.0.1:8080/api/
```

If you start the backend on another port, update
`SUPER_APP_BACKEND_BASE_URL` to match it.

In local backend mode, this host automatically sends its delivery context to
the backend `latest` manifest route:

- `hostApp=super_app_host`
- `sdkVersion=1.0.0`
- `hostVersion=1.0.0`
- `platform`
- `locale`
- optional `tenantId`
- optional `pinnedVersion`
- `capabilities=auth,analytics,native_navigation,secure_api`

With the current rollout sample, that context resolves:

- `profile_center` `latest` -> `1.1.0`
- `feedback_form` `latest` -> `1.1.0`

If you test on an Android emulator instead of Windows desktop, use
`http://10.0.2.2:8080/api/` for `SUPER_APP_BACKEND_BASE_URL`.

Useful debug overrides:

```powershell
flutter run ^
  --dart-define=SUPER_APP_SOURCE_MODE=local_backend ^
  --dart-define=SUPER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=SUPER_APP_HOST_VERSION=1.4.0 ^
  --dart-define=SUPER_APP_TENANT_ID=internal-demo ^
  --dart-define=SUPER_APP_PINNED_VERSION=1.0.0 ^
  --dart-define=SUPER_APP_AUTH_STATE=authenticated
```

To test local auth and secure API failures without code changes:

```powershell
flutter run ^
  --dart-define=SUPER_APP_SOURCE_MODE=local_backend ^
  --dart-define=SUPER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=SUPER_APP_AUTH_STATE=signed_out
```

```powershell
flutter run ^
  --dart-define=SUPER_APP_SOURCE_MODE=local_backend ^
  --dart-define=SUPER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=SUPER_APP_AUTH_STATE=expired
```

```powershell
flutter run ^
  --dart-define=SUPER_APP_SOURCE_MODE=local_backend ^
  --dart-define=SUPER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=SUPER_APP_AUTH_STATE=blocked
```

## Commands

```bash
flutter run
flutter test
flutter analyze
```
