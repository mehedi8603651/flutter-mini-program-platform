# Mini-Program Authoring

This repo currently supports **developer-authored** and **partner-authored**
mini-programs. Authors create a repo-backed package under `mini_programs/`,
write portable UI in Stac DSL, validate it, then publish the generated JSON
into the local backend sample.

## Quick start

Generate a new scaffold from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\create_mini_program.ps1 `
  -MiniProgramId coupon_center
```

Optional inputs:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\create_mini_program.ps1 `
  -MiniProgramId claim_center `
  -Title "Claim Center" `
  -Description "Portable claim intake starter flow." `
  -Capabilities analytics,secure_api `
  -Force
```

The scaffold creates:

- `mini_programs/<id>/manifest.json`
- `mini_programs/<id>/README.md`
- `mini_programs/<id>/pubspec.yaml`
- `mini_programs/<id>/lib/default_stac_options.dart`
- `mini_programs/<id>/stac/screens/<id>_home.dart`
- `mini_programs/<id>/stac/components/`
- `mini_programs/<id>/stac/theme/`
- `mini_programs/<id>/assets/`

## Authoring rules

- Write portable UI in `stac/screens/` and `stac/components/`.
- Do not author normal host Flutter pages for mini-program UI.
- Keep native work behind approved `hostAction` payloads.
- Only use declared manifest capabilities.
- Replace placeholder route aliases and secure endpoints before shipping.

## Current supported capability values

- `auth`
- `analytics`
- `secure_api`
- `native_navigation`

The scaffold only accepts these current contract wire values.

## Build

Preferred local command:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\build_mini_program.ps1 `
  -MiniProgramId <id>
```

Expected screen output:

```text
mini_programs/<id>/stac/.build/screens/<id>_home.json
```

Build resolution order:

1. explicit `-StacCliScript`
2. vendored `stac-dev/packages/stac_cli/bin/stac_cli.dart`
3. global `stac` command

If `stac-dev` is not present locally:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\build_mini_program.ps1 `
  -MiniProgramId <id> `
  -StacCliScript D:\path\to\bin\stac_cli.dart
```

## Validate

Run validation before publish:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\validate_delivery.ps1 `
  -MiniProgramId <id>
```

## Publish the local backend sample

Preferred command:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_mini_program.ps1 `
  -MiniProgramId <id>
```

This command:

1. builds the mini-program
2. runs pre-publish validation
3. copies manifest and screens into `backend/api/`
4. runs post-publish validation

Low-level copy-only command:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_local_backend.ps1 `
  -MiniProgramId <id>
```

## Test in a host

For a local proof:

1. Add the new mini-program to a host catalog.
2. Run `hosts/super_app_host` or `hosts/partner_app_host`.
3. Open the generated entry screen and verify the declared capability path.

## Practical guidance

- Use `analytics,native_navigation` for a low-risk starter flow.
- Use `secure_api` only when the flow truly needs a host-owned secure endpoint.
- If the mini-program depends on `secure_api`, keep caching conservative.
- Prefer one small portable flow first, then add components after the entry
  screen and backend publish path are working.
