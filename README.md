# flutter-mini-program-platform

Portable Flutter mini-program platform built around shared contracts, a shared
SDK/runtime, portable Stac-authored mini-programs, multiple Flutter host apps,
and local backend delivery.

## Create A Mini-Program

Generate a starter mini-program from the repo root with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\create_mini_program.ps1 `
  -MiniProgramId coupon_center
```

Or generate a standalone mini-program anywhere:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\create_mini_program.ps1 `
  -MiniProgramId first_miniprogram `
  -OutputRoot D:\first-miniprogram
```

The command generates the manifest, two starter Stac screens, readable action
helpers for host and internal mini-program routing, build config, README, and
the expected `stac/components`, `stac/theme`, and `assets` folders under
`mini_programs/<id>/`.

Authoring guide:

- [mini_program_authoring.md](D:/flutter-mini-program-platform/docs/mini_program_authoring.md)
- [embed_existing_flutter_app.md](D:/flutter-mini-program-platform/docs/embed_existing_flutter_app.md)

Portable flows now support internal page-to-page routing by `screenId`, so a
generated mini-program can move from its first screen to a second portable
screen without leaving the mini-program container.

## Embed Into An Existing Flutter App

Generate the app-owned embedding adapter for an existing Flutter app with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\init_mini_program_embedding.ps1 `
  -ProjectRoot D:\myflutterproject
```

The command generates:

- `lib/mini_program/app_host_bridge.dart`
- `lib/mini_program/mini_program_runtime_setup.dart`
- `lib/mini_program/native_profile_editor_page.dart`
- `lib/mini_program/README.md`

It intentionally leaves `main.dart` and the rest of your app shell under
developer control, so existing apps can adopt the shared SDK without copying a
full sample host.

Build a mini-program with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\build_mini_program.ps1 `
  -MiniProgramId profile_center
```

Or build a standalone mini-program against this repo’s tooling:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\build_mini_program.ps1 `
  -MiniProgramRoot D:\first-miniprogram `
  -RepoRoot D:\flutter-mini-program-platform
```

Publish it into the local backend sample with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_mini_program.ps1 `
  -MiniProgramId profile_center
```

Standalone authoring root:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_mini_program.ps1 `
  -MiniProgramRoot D:\first-miniprogram `
  -RepoRoot D:\flutter-mini-program-platform
```

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
