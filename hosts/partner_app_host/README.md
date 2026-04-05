# partner_app_host

Reference Flutter host app for portable mini-program partner integration.

## What it proves

- installs `mini_program_sdk` outside the first-party host
- declares a smaller capability surface than `super_app_host`
- loads the same `profile_center` mini-program from backend delivery
- sends `hostApp=partner_app_host` delivery context
- receives the backend-selected `1.0.0` lane while `super_app_host` receives `1.1.0`
- maps the same portable `profile_editor` route alias to its own native Flutter page

## Current flow

1. Start the local backend service.
2. Launch `partner_app_host`.
3. Open `Profile Center`.
4. The SDK loads `latest` from the backend with partner delivery context.
5. The backend resolves that request to `profile_center` `1.0.0`.
6. The mini-program renders and can still call `trackEvent` and `openNativeScreen`.

## Run

```powershell
cd D:\flutter-mini-program-platform\backend\local_backend_service
dart pub get
dart run bin\server.dart
cd D:\flutter-mini-program-platform\hosts\partner_app_host
flutter run
```

If you need another backend address:

```powershell
flutter run --dart-define=PARTNER_APP_BACKEND_BASE_URL=http://127.0.0.1:9135/api/
```

On an Android emulator, use `http://10.0.2.2:8080/api/` instead of
`http://127.0.0.1:8080/api/`.

## Commands

```bash
flutter test
flutter analyze
```
