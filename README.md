# flutter-mini-program-platform

Portable Flutter mini-program platform built around shared contracts, a shared
SDK/runtime, portable Stac-authored mini-programs, multiple Flutter host apps,
and local backend delivery.

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
