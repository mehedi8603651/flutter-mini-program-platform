# mini_program_tooling

Local developer and CI tooling for the Flutter mini-program platform.

## Current CLI

### `validate_delivery`

Validates authored manifests plus backend delivery files before runtime:

- `mini_programs/<id>/manifest.json`
- `backend/api/manifests/...`
- `backend/api/screens/...`
- `backend/api/rollout-rules/...`
- `backend/api/capability-policies/...`

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
