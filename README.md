# flutter-mini-program-platform

Portable Flutter mini-program platform built around shared contracts, a shared
SDK/runtime, portable Stac-authored mini-programs, multiple Flutter host apps,
and local backend delivery.

## Preferred CLI

Install the published tooling once:

```powershell
dart pub global activate mini_program_tooling
```

For repo-local contributor work, use:

```powershell
dart pub global activate --source path <repo-root>\packages\mini_program_tooling
```

Then use the shared `miniprogram` command:

```powershell
miniprogram create coupon_center
miniprogram doctor
miniprogram backend init
miniprogram env init
miniprogram build coupon_center
miniprogram validate coupon_center
miniprogram publish coupon_center
miniprogram backend start --port 8080
miniprogram backend status
```

The older PowerShell wrappers still work, but `miniprogram ...` is now the
preferred developer entrypoint.

Use `miniprogram doctor` to verify the local machine, saved env config, managed
Stac builder state, and backend state before troubleshooting build or embed
issues.

## Create A Mini-Program

Generate a starter mini-program anywhere with:

```powershell
cd D:\
miniprogram create first_miniprogram
```

The command generates the manifest, two starter Stac screens, readable action
helpers for host and internal mini-program routing, build config, README, and
the expected `stac/components`, `stac/theme`, and `assets` folders.

Authoring guide:

- [mini_program_authoring.md](D:/flutter-mini-program-platform/docs/mini_program_authoring.md)
- [embed_existing_flutter_app.md](D:/flutter-mini-program-platform/docs/embed_existing_flutter_app.md)

Portable flows now support internal page-to-page routing by `screenId`, so a
generated mini-program can move from its first screen to a second portable
screen without leaving the mini-program container.

For a standalone local workflow:

```powershell
cd D:\first_miniprogram
miniprogram doctor
miniprogram backend init
miniprogram env init
miniprogram build first_miniprogram
miniprogram validate first_miniprogram
miniprogram publish first_miniprogram
miniprogram backend start --port 8080
```

`env init` now works without a platform repo path. `build` uses the managed
pinned Stac builder bundled inside `mini_program_tooling`. Keep
`--stac-cli-script` only as the expert override when you intentionally need a
different Stac CLI.

If you want a developer-owned local backend outside the platform repo, run
`miniprogram backend init` once from anywhere. On Windows, the default backend
workspace is `%LOCALAPPDATA%\mini_program\backend\`. That scaffolds
`backend/local_backend_service`, `backend/api`, and the tracked
`.mini_program/backend_workspace.json` state used by `backend start`,
`backend status`, `backend stop`, and `backend reset-local`. Use
`miniprogram backend init --root D:\custom_backend` only when you intentionally
want a custom workspace path. When that backend workspace exists,
`miniprogram publish ...` now writes local artifacts there instead of the
platform repo backend.

## Embed Into An Existing Flutter App

Generate the app-owned embedding adapter for an existing Flutter app with:

```powershell
flutter create coupon_host_app
cd coupon_host_app
miniprogram embed init
```

Or from another directory:

```powershell
miniprogram embed init --project-root D:\myflutterproject
```

The command generates:

- `lib/mini_program/mini_program.dart`
- `lib/mini_program/mini_program_app_shell.dart`
- `lib/mini_program/mini_program_routes.dart`
- `lib/mini_program/app_host_bridge.dart`
- `lib/mini_program/mini_program_runtime_setup.dart`
- `lib/mini_program/native_profile_editor_page.dart`
- `lib/mini_program/mini_program_launcher.dart`
- `lib/mini_program/README.md`

It intentionally leaves `main.dart` and the rest of your app shell under
developer control, so existing apps can adopt the shared SDK without copying a
full sample host. Feature pages can then open mini-programs through the
generated `openAppMiniProgram(...)` helper or `AppMiniProgramLauncherButton`,
while `MiniProgramAppShell` keeps app entry code small.

`embed init` now updates the host app `pubspec.yaml` to use the published
`mini_program_sdk` and `mini_program_contracts` packages instead of local
`path:` dependencies.

## Repo Smoke Command

Run the repo-level local/CI smoke suite with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\smoke_repo.ps1
```

By default it runs:

- delivery validation
- `backend/local_backend_service` analyze and test
- `packages/mini_program_sdk` analyze and test
- `hosts/super_app_host` analyze and test
- `hosts/partner_app_host` analyze and test

Useful options:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\smoke_repo.ps1 -SkipAnalyze
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\smoke_repo.ps1 -SkipHosts
```

Verify the installed global CLI from a fresh temporary `PUB_CACHE` with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_global_cli.ps1
```

## GitHub Actions

Pushes and pull requests run the repo smoke workflow through:

- `.github/workflows/repo-smoke.yml`

The workflow uses `windows-latest`, installs Flutter, opts into Node 24 for
JavaScript-based actions, and runs the smoke checks as explicit steps:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_delivery.ps1
dart analyze
dart test
flutter analyze
flutter test
```

Local development should still use [smoke_repo.ps1](D:/flutter-mini-program-platform/tools/smoke_repo.ps1).
CI intentionally runs the same checks inline so GitHub shows the exact failing
step instead of only reporting a top-level wrapper failure.
