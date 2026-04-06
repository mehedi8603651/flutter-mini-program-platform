# partner_app_host

Reference Flutter host app for portable mini-program partner integration.

## What it proves

- installs `mini_program_sdk` outside the first-party host
- declares a smaller capability surface than `super_app_host`
- loads multiple mini-programs from backend delivery
- sends backend delivery context including `hostApp`, `hostVersion`, `platform`, `locale`, and capabilities
- can add debug release-control overrides such as `tenantId` and `pinnedVersion`
- receives the backend-selected `profile_center` `1.0.0` lane while `super_app_host` receives `1.1.0`
- maps portable route aliases such as `profile_editor` and `feedback_follow_up` to its own native Flutter pages
- keeps `secure_api` host-owned and allowlisted through host-side services behind its bridge
- uses file-backed manifest and screen caches on real devices, with in-memory fallback in tests
- shows an offline notice when stale cached content is rendered
- persists standard Stac network image assets to local files when entry-screen caching is allowed
- shows list-level delivery badges before open: `Live`, `Offline`, or `Unavailable`

## Current flow

1. Start the local backend service.
2. Launch `partner_app_host`.
3. Open `Profile Center` or `Feedback Form`.
4. The SDK loads `latest` from the backend with partner delivery context.
5. The backend resolves that request to the partner lane for each mini-program:
   - `profile_center` -> `1.0.0`
   - `feedback_form` -> `1.1.0`
6. The mini-program renders and can still call `callSecureApi`, `trackEvent`, and `openNativeScreen`.

The host list now resolves discovery state before opening a flow:

- `Live` when the backend is reachable
- `Offline` when a valid cached release can still open
- `Unavailable` when no valid offline copy exists

`callSecureApi` currently flows through:

- `lib/services/auth_session_service.dart`
- `lib/services/secure_api_service.dart`

That keeps session and backend logic out of `HostBridgeImpl`.
The local auth model now supports seeded states for testing:

- `authenticated`
- `signed_out`
- `expired`
- `blocked`

## Run

```powershell
cd D:\flutter-mini-program-platform\backend\local_backend_service
dart pub get
dart run bin\server.dart --host=0.0.0.0 --port=8080
cd D:\flutter-mini-program-platform\hosts\partner_app_host
flutter run
```

If you need another backend address:

```powershell
flutter run --dart-define=PARTNER_APP_BACKEND_BASE_URL=http://127.0.0.1:9135/api/
```

On an Android emulator, use `http://10.0.2.2:8080/api/` instead of
`http://127.0.0.1:8080/api/`.

Useful debug overrides:

```powershell
flutter run ^
  --dart-define=PARTNER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=PARTNER_APP_HOST_VERSION=1.2.3 ^
  --dart-define=PARTNER_APP_TENANT_ID=campus-demo ^
  --dart-define=PARTNER_APP_PINNED_VERSION=1.0.0 ^
  --dart-define=PARTNER_APP_AUTH_STATE=authenticated
```

To test local auth and secure API failures without code changes:

```powershell
flutter run ^
  --dart-define=PARTNER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=PARTNER_APP_AUTH_STATE=signed_out
```

```powershell
flutter run ^
  --dart-define=PARTNER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=PARTNER_APP_AUTH_STATE=expired
```

```powershell
flutter run ^
  --dart-define=PARTNER_APP_BACKEND_BASE_URL=http://10.0.2.2:8080/api/ ^
  --dart-define=PARTNER_APP_AUTH_STATE=blocked
```

## Commands

```bash
flutter test
flutter analyze
```
