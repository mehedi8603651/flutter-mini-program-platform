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

Pushes and pull requests now run the same smoke entrypoint through:

- `.github/workflows/repo-smoke.yml`

The workflow uses `windows-latest`, installs Flutter, and calls:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\smoke_repo.ps1
```

This keeps local verification and CI verification aligned instead of
duplicating command lists in multiple places.
