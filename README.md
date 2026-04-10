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
miniprogram env init --repo-root <repo-root>
miniprogram build coupon_center
miniprogram validate coupon_center
miniprogram publish coupon_center
miniprogram embed init --project-root <existing-flutter-app>
miniprogram backend start --port 8080
miniprogram backend status
```

The older PowerShell wrappers still work, but `miniprogram ...` is now the
preferred developer entrypoint.

Use `miniprogram doctor` to verify the local machine, saved env config, repo
resolution, and backend state before troubleshooting build or embed issues.

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

The PowerShell wrapper now delegates to the installed `miniprogram` CLI for the
normal text workflow. `-Output json` still uses the legacy Dart entrypoint for
compatibility.

Authoring guide:

- [mini_program_authoring.md](D:/flutter-mini-program-platform/docs/mini_program_authoring.md)
- [embed_existing_flutter_app.md](D:/flutter-mini-program-platform/docs/embed_existing_flutter_app.md)

Portable flows now support internal page-to-page routing by `screenId`, so a
generated mini-program can move from its first screen to a second portable
screen without leaving the mini-program container.

For standalone mini-program workspaces outside this repo, run `miniprogram env
init --repo-root <repo-root>` once from the mini-program root. That writes
`.mini_program/env.json` and refreshes a user-level fallback repo config, so
later `build`, `validate`, `publish`, `embed init`, and `backend ...` commands
can reuse the saved repo context without repeating `--repo-root`.

If you want a developer-owned local backend outside the platform repo, run
`miniprogram backend init` once from the directory that should own the backend
workspace. That scaffolds `backend/local_backend_service`, `backend/api`, and
the tracked `.mini_program/backend_workspace.json` state used by
`backend start`, `backend status`, `backend stop`, and `backend reset-local`.

## Embed Into An Existing Flutter App

Generate the app-owned embedding adapter for an existing Flutter app with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\init_mini_program_embedding.ps1 `
  -ProjectRoot D:\myflutterproject
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

The PowerShell wrapper delegates to the installed `miniprogram` CLI for the
normal text workflow and falls back to the legacy Dart entrypoint only when a
compatibility-only mode such as `-Output json` is requested.

Build a mini-program with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\build_mini_program.ps1 `
  -MiniProgramId profile_center
```

Or build a standalone mini-program against this repo's tooling:

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
