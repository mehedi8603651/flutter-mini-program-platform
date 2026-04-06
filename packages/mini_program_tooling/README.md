# mini_program_tooling

Local developer and CI tooling for the Flutter mini-program platform.

## Current CLI

### `create_mini_program`

Generates a buildable starter mini-program under `mini_programs/<id>/` with:

- `manifest.json`
- `README.md`
- `pubspec.yaml`
- `lib/default_stac_options.dart`
- `stac/screens/<id>_home.dart`
- `stac/components/`
- `stac/theme/`
- `assets/`

Starter behavior:

- analytics starter button is log-only by design
- native starter button uses the shared demo route alias `profile_editor`
- authors should replace that demo route alias before shipping a real mini-program

Example:

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_tooling
dart run bin\create_mini_program.dart --repo-root D:\flutter-mini-program-platform --id coupon_center
```

Standalone output:

```powershell
dart run bin\create_mini_program.dart `
  --id first_miniprogram `
  --output-root D:\first-miniprogram
```

Custom capabilities:

```powershell
dart run bin\create_mini_program.dart `
  --repo-root D:\flutter-mini-program-platform `
  --id claim_center `
  --title "Claim Center" `
  --capabilities analytics,secure_api
```

Repo-level PowerShell wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\create_mini_program.ps1 `
  -MiniProgramId coupon_center
```

Standalone wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\create_mini_program.ps1 `
  -MiniProgramId first_miniprogram `
  -OutputRoot D:\first-miniprogram
```

### `build_mini_program`

Builds a mini-program through the current Stac CLI path and verifies that the
entry screen JSON was produced.

Resolution order:

1. explicit `--stac-cli-script`
2. vendored `stac-dev/packages/stac_cli/bin/stac_cli.dart`
3. global `stac` command

Example:

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_tooling
dart run bin\build_mini_program.dart --repo-root D:\flutter-mini-program-platform --id profile_center
```

Standalone mini-program root with vendored repo CLI:

```powershell
dart run bin\build_mini_program.dart `
  --repo-root D:\flutter-mini-program-platform `
  --mini-program-root D:\first-miniprogram
```

Explicit script path:

```powershell
dart run bin\build_mini_program.dart `
  --repo-root D:\flutter-mini-program-platform `
  --id coupon_center `
  --stac-cli-script D:\path\to\bin\stac_cli.dart
```

Repo-level PowerShell wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\build_mini_program.ps1 `
  -MiniProgramId profile_center
```

Standalone wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\build_mini_program.ps1 `
  -MiniProgramRoot D:\first-miniprogram `
  -RepoRoot D:\flutter-mini-program-platform
```

### `publish_mini_program`

Builds a mini-program, runs a pre-publish validation gate, copies the built
manifest/screens into `backend/api/`, then runs a post-publish validation.

Example:

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_tooling
dart run bin\publish_mini_program.dart --repo-root D:\flutter-mini-program-platform --id profile_center
```

Standalone mini-program root:

```powershell
dart run bin\publish_mini_program.dart `
  --repo-root D:\flutter-mini-program-platform `
  --mini-program-root D:\first-miniprogram
```

Repo-level PowerShell wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_mini_program.ps1 `
  -MiniProgramId profile_center
```

Standalone wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_mini_program.ps1 `
  -MiniProgramRoot D:\first-miniprogram `
  -RepoRoot D:\flutter-mini-program-platform
```

Explicit CLI path:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\publish_mini_program.ps1 `
  -MiniProgramId coupon_center `
  -StacCliScript D:\path\to\bin\stac_cli.dart
```

### `validate_delivery`

Validates authored manifests plus backend delivery files before runtime:

- `mini_programs/<id>/manifest.json`
- `backend/api/manifests/...`
- `backend/api/screens/...`
- `backend/api/rollout-rules/...`
- `backend/api/capability-policies/...`
- `backend/api/secure-api-policies/...`

Example:

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_tooling
dart run bin\validate_delivery.dart --repo-root D:\flutter-mini-program-platform
```

Validate one mini-program only:

```powershell
dart run bin\validate_delivery.dart `
  --repo-root D:\flutter-mini-program-platform `
  --mini-program feedback_form
```

Repo-level PowerShell wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\validate_delivery.ps1
```

Standalone validation:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\validate_delivery.ps1 `
  -RepoRoot D:\flutter-mini-program-platform `
  -MiniProgramRoot D:\first-miniprogram
```

### `inspect_delivery`

Calls the local backend debug inspection route and prints the manifest delivery
decision in text or JSON form.

Example:

```powershell
cd D:\flutter-mini-program-platform\packages\mini_program_tooling
dart run bin\inspect_delivery.dart `
  --mini-program profile_center `
  --host-app super_app_host `
  --sdk-version 1.0.0 `
  --host-version 1.0.0 `
  --platform android `
  --locale en-US `
  --capabilities analytics,native_navigation,auth
```

JSON output:

```powershell
dart run bin\inspect_delivery.dart `
  --mini-program profile_center `
  --host-app partner_app_host `
  --sdk-version 1.0.0 `
  --host-version 1.0.0 `
  --platform android `
  --locale en-US `
  --capabilities analytics,native_navigation `
  --output json
```

Repo-level PowerShell wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\inspect_delivery.ps1 `
  -MiniProgramId feedback_form `
  -HostApp partner_app_host `
  -SdkVersion 1.0.0 `
  -HostVersion 1.0.0 `
  -Platform android `
  -Locale en-US `
  -Capabilities analytics,native_navigation,secure_api
```

## Authoring guide

See:

- `docs/mini_program_authoring.md`
