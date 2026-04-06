# feedback_form

Portable feedback mini-program authored with Stac DSL.

## Current scope

- renders one feedback screen with local form validation
- uses approved `hostAction` payloads for `callSecureApi`, `trackEvent`, and `openNativeScreen`
- stays portable by using the route alias `feedback_follow_up`
- current authored manifest version is `1.1.0`
- manifest cache policy is `noCache` for both manifest and entry screen because this is the current sensitive secure flow
- persistent offline reuse is intentionally disabled for this mini-program
- current backend rollout sends `1.1.0` to both `super_app_host` and `partner_app_host`

## Structure

- `manifest.json`
- `lib/default_stac_options.dart`
- `stac/screens/`
- `stac/components/`
- `stac/.build/` after build

## Build

Use the vendored CLI:

```powershell
cd D:\flutter-mini-program-platform\stac-dev\packages\stac_cli
dart run bin\stac_cli.dart build --project D:\flutter-mini-program-platform\mini_programs\feedback_form
```

Expected output:

```text
mini_programs/feedback_form/stac/.build/screens/feedback_form_home.json
```

## Local host proof

`super_app_host` can load a copied snapshot of the built manifest and screen as
Flutter assets for local proof. Rebuild and resync when this mini-program
changes.

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\sync_assets.ps1 -MiniProgramId feedback_form
```

## Local backend sample

Publish this mini-program into the local backend sample:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_local_backend.ps1 -MiniProgramId feedback_form
```
