# profile_center

Portable profile mini-program authored with Stac DSL.

## Current scope

- renders one local profile overview screen
- tracks one analytics event through `hostAction`
- opens one host-owned native profile editor through `hostAction`
- stays portable by using the route alias `profile_editor` instead of a host route constant
- current authored manifest version is `1.1.0`
- backend rollout currently sends `1.1.0` to `super_app_host` while keeping `partner_app_host` on `1.0.0`

## Structure

- `manifest.json`
- `lib/default_stac_options.dart`
- `stac/screens/`
- `stac/components/`
- `stac/.build/` after build

## Build

The Stac CLI is not installed globally in this repo, so use the vendored CLI:

```powershell
cd D:\flutter-mini-program-platform\stac-dev\packages\stac_cli
dart run bin\stac_cli.dart build --project D:\flutter-mini-program-platform\mini_programs\profile_center
```

Expected output:

```text
mini_programs/profile_center/stac/.build/screens/profile_center_home.json
```

## Local host proof

`super_app_host` currently loads a copied snapshot of the built manifest and screen
as Flutter assets for local proof. Rebuild and resync those assets when this
mini-program changes.

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\sync_assets.ps1
```

## Local backend sample

You can also publish this mini-program into the static local backend sample:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_local_backend.ps1
```
