# mini_program_tooling

Command-line tooling for the Flutter mini-program platform.

Tooling `0.7.0` generates mini-program projects against
`mini_program_ui: ^0.2.0` and Flutter host projects against
`mini_program_sdk: ^0.6.0`.

The CLI supports the current MVP architecture:

- mini-program UI is built into public static artifact files
- host apps open mini-programs with `appId + artifactBaseUrl`
- runtime middle-server API calls are optional
- auth, database, payments, files, secrets, and business rules stay behind the publisher-owned API

For the beginner static-only walkthrough, start here:
[Quickstart: static mini-program to host app](../../docs/quickstart_static_miniprogram_to_host.md).

## Install

```powershell
dart pub global activate mini_program_tooling
miniprogram doctor
miniprogram --help
```

On Windows, make sure the Dart pub global bin folder is on `PATH`:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
```

Use `miniprogram <command> --help` for exact command options:

```powershell
miniprogram publish --help
miniprogram host endpoint add --help
miniprogram publisher-api contract init --help
```

## How The CLI Works

The CLI has two main jobs:

1. Build and publish mini-program static artifacts.
2. Wire those artifacts into a Flutter host app.

The normal static flow is:

```text
create -> edit -> preview -> build -> validate -> artifact build -> artifact verify -> partner package -> embed/import host -> run host
```

Important terms:

- `mini-program root`: the folder with `manifest.json`, `mp/`, `tool/`, and `pubspec.yaml`
- `host project root`: the Flutter app folder with `pubspec.yaml`, `lib/`, and platform folders
- `artifacts`: the generated portable static artifact root to upload
- `artifactBaseUrl`: the public URL whose `artifacts/` child is hosted
- `partner package`: JSON handoff containing `appId`, title, and `artifactBaseUrl`
- `publisher API`: optional middle-server API for runtime data actions

Most commands can run from inside the relevant folder. Use explicit paths when
running from another directory:

```powershell
miniprogram build --mini-program-root D:\my_profile
miniprogram embed init --project-root D:\my_profile_host
```

## Static Mini-Program Workflow

Use this workflow when the mini-program is static UI or local/static data only.
It does not require a backend.

### 1. Create

Use when starting a new mini-program.

```powershell
cd D:\
miniprogram create my_profile --screen-format mp
cd D:\my_profile
```

Useful options:

```powershell
miniprogram create my_profile --title "My Profile" --description "Static profile demo."
miniprogram create my_profile --output-root D:\work
miniprogram create my_profile --force
```

What it creates:

```text
manifest.json
mp/program.dart
mp/screens/<app_id>_home.dart
mp/screens/<app_id>_details.dart
tool/build_mp.dart
pubspec.yaml
assets/
```

### 2. Preview

Use while editing UI. Preview builds the mini-program and runs it in a managed
Flutter preview host.

```powershell
miniprogram preview -d chrome
```

Other common devices:

```powershell
miniprogram preview -d edge
miniprogram preview -d windows
miniprogram preview -d emulator-5554
```

Use an explicit root when not inside the mini-program folder:

```powershell
miniprogram preview -d chrome --mini-program-root D:\my_profile
```

For optional runtime API testing, initialize an artifact-owned contract first:

```powershell
miniprogram publisher-api contract init `
  --publisher-api-url http://127.0.0.1:9090 `
  --permission-reason "Load preview data." `
  --allow-local-http
miniprogram preview -d chrome
```

Preview reads `publisher_backend.json` and automatically enables its Publisher
API permission. Static opening does not need the contract.

### 3. Build

Use before validation, publish, or CI checks.

```powershell
miniprogram build
```

Build writes deterministic Mp JSON under:

```text
mp/.build/screens/
```

Useful options:

```powershell
miniprogram build --mini-program-root D:\my_profile
miniprogram build --skip-pub-get
miniprogram build --mp-build-script D:\my_profile\tool\build_mp.dart
```

Do not edit `mp/.build` directly. Edit `mp/program.dart` and `mp/screens/*.dart`,
then rebuild.

### 4. Validate

Use before publishing or handing artifacts to a host app.

```powershell
miniprogram validate
```

Validation checks the manifest and generated screen JSON.

Use an explicit root when needed:

```powershell
miniprogram validate --mini-program-root D:\my_profile
```

### 5. Build Portable Artifacts

Use when the mini-program is ready to serve from GitHub Pages, CDN, object
storage, or any HTTPS static file host.

```powershell
miniprogram artifact build
miniprogram artifact verify
```

Use explicit paths:

```powershell
miniprogram artifact build `
  --mini-program-root D:\my_profile `
  --artifacts-root D:\my_profile\artifacts
```

Static output includes:

```text
artifacts/<appId>/latest.json
artifacts/<appId>/catalog.json
artifacts/<appId>/<version>/manifest.json
artifacts/<appId>/<version>/release.json
artifacts/<appId>/<version>/checksums.json
artifacts/<appId>/<version>/screens/<screenId>.json
artifacts/<appId>/<version>/assets/
```

`miniprogram build`, `artifact build`, and `artifact verify` validate every
static `Mp.data.loadJsonAsset` reference. Referenced files must exist under the
mini-program `assets/` directory, use a relative `.json` path, parse to an
object or list, and remain within the runtime size, depth, and member limits.
Preview serves these files from its same-origin `/preview/assets/` route.

Upload or copy the generated `artifacts` directory to a public static host.

For GitHub Pages, a common URL is:

```text
https://<github-user>.github.io/my_profile_static/
```

That URL becomes the mini-program `artifactBaseUrl`.

## Partner Package Workflow

Use a partner package when a publisher wants to hand a mini-program endpoint to
a host app developer.

```powershell
miniprogram partner package my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --output D:\my_profile\my_profile.partner.json
```

Use when:

- the static artifacts are already hosted
- the host app should import a small JSON handoff
- you want to avoid manual endpoint editing

The package contains only static-opening information: app ID, title, and
artifact base URL. It does not need backend credentials or provider config.

## Host App Workflow

Use these commands inside an existing Flutter app, or after `flutter create`.

### 1. Initialize Host Integration

Use once per host app.

```powershell
cd D:\my_profile_host
miniprogram embed init --project-root .
```

What it does:

- adds `mini_program_sdk` and `mini_program_contracts` dependencies
- creates the complete design-neutral `lib/mini_program/` integration
- creates dynamic and registry-based launch helpers
- creates host-owned `buildHostMiniProgramConfig()` composition
- adds Android debug network files when Android exists

Generated folder shape:

```text
lib/mini_program/
  mini_program.dart
  mini_program_host_setup.dart
  mini_program_runtime_setup.dart
  mini_program_endpoints.dart
  mini_program_registry.dart
  mini_program_policy_resolver.dart
  mini_program_launcher.dart
  mini_program_policies.json
  app_host_bridge.dart
```

Use `--force` to refresh scaffold-generated runtime, launcher, barrel, and
README files. Host setup, bridge, policies, and endpoint-import output are
preserved:

```powershell
miniprogram embed init --project-root D:\my_profile_host --force
```

### 2. Import A Partner Package

Use when a mini-program publisher gives you a partner JSON file.

```powershell
miniprogram host endpoint import D:\my_profile\my_profile.partner.json --project-root .
```

This writes or updates generated routing and requested policy while preserving
host-owned accepted policy:

```text
lib/mini_program/mini_program_endpoints.dart
lib/mini_program/mini_program_registry.dart
lib/mini_program/mini_program_policy_resolver.dart
lib/mini_program/mini_program_policies.json
```

Partner handoff schema 3 may request approximate, foreground-only current
location under `requestedPermissions.location`. New requests are imported as
denied unless the host reviews and manually enables them or imports with
`--accept-requested-policy`. Policy acceptance alone does not access the
device.

Install the reusable Android provider once per host app:

```powershell
miniprogram host capability init location `
  --platform android `
  --project-root .
```

The command adds only coarse, foreground, one-time location support. It is
idempotent, preserves recognized host code, and does not enable location for
any mini-program. Review each app under
`lib/mini_program/mini_program_policies.json` separately. Background tracking,
continuous updates, GPS/fine permission, and app-specific Weather behavior are
not installed.

### 3. Add An Endpoint Manually

Use when you know the `artifactBaseUrl` and do not have a partner JSON file.

```powershell
miniprogram host endpoint add my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --title "My Profile" `
  --project-root D:\my_profile_host
```

When the mini-program has `publisher_backend.json`, use `partner package` from
its root so the handoff requests Publisher API permission. Import with
`--accept-requested-policy` only after reviewing the request. The generated
host endpoint never stores a per-app Publisher API URL.

### 4. Run The Host

Use after importing an endpoint and wiring a host button.

```powershell
miniprogram host run -d chrome --project-root D:\my_profile_host
```

Other common devices:

```powershell
miniprogram host run -d windows --project-root D:\my_profile_host
miniprogram host run -d emulator-5554 --project-root D:\my_profile_host
```

The command wraps `flutter run` with the same device ID.

### 5. Open From Host UI

Import only the public barrel and use the registered helper from any host page:

```dart
import 'mini_program/mini_program.dart';

openRegisteredMiniProgram(
  context,
  MiniPrograms.myProfile,
);
```

For a fresh host app, wrap the app once:

```dart
final miniProgramConfig = await buildHostMiniProgramConfig();

MiniProgramScope(config: miniProgramConfig, child: const MyApp())
```

## Optional Local Static Artifact Host

Most beginners should use `publish --target static` and GitHub Pages. Use the
local artifact host only when you want a local static artifact server/workspace.

Initialize:

```powershell
miniprogram artifact-host init --root D:\mini_program_artifacts
```

Start:

```powershell
miniprogram artifact-host start --root D:\mini_program_artifacts --port 8080
```

Publish into that local artifact host:

```powershell
miniprogram publish my_profile --target local --root D:\mini_program_artifacts
```

Check status:

```powershell
miniprogram artifact-host status --root D:\mini_program_artifacts
miniprogram artifact-host status --root D:\mini_program_artifacts --json
```

Stop:

```powershell
miniprogram artifact-host stop
```

Reset local generated artifacts:

```powershell
miniprogram artifact-host reset-local --root D:\mini_program_artifacts --yes
```

`backend <command>` is a legacy alias for `artifact-host <command>`.

## Optional Publisher API Workflow

Use this only when the mini-program needs dynamic runtime behavior. It is not
needed for static opening.

For a concrete AWS Lambda/DynamoDB/JWT example, see
[Track 2: middle-server API with Lambda, DynamoDB, and JWT](../../docs/middle_server_api_lambda_dynamodb.md).

The publisher API is your middle-server. It can be implemented with any
provider/framework and owns database access, auth, payment, file storage,
secrets, external APIs, admin logic, and business rules.

### Local Mock API

Use when learning or testing runtime API widgets locally.

```powershell
miniprogram publisher-api scaffold --template mock --mini-program-root D:\my_profile
miniprogram publisher-api run --mini-program-root D:\my_profile --port 9090
```

Check status and URLs:

```powershell
miniprogram publisher-api status --mini-program-root D:\my_profile
miniprogram publisher-api urls --port 9090
```

Stop:

```powershell
miniprogram publisher-api stop --mini-program-root D:\my_profile
```

### Runtime API Contract

Use when the mini-program calls a real or mock middle-server.

```powershell
miniprogram publisher-api contract init `
  --mini-program-root D:\my_profile `
  --publisher-api-url http://127.0.0.1:9090 `
  --permission-reason "Load profile data." `
  --allow-local-http
```

Validate the contract:

```powershell
miniprogram publisher-api contract validate `
  --mini-program-root D:\my_profile `
  --allow-local-http
```

Smoke test the API:

```powershell
miniprogram publisher-api contract smoke `
  --mini-program-root D:\my_profile `
  --allow-local-http
```

For protected runtime API smoke checks:

```powershell
miniprogram publisher-api contract smoke `
  --mini-program-root D:\my_profile `
  --auth-token <token>
```

The command writes root `publisher_backend.json`. `artifact build` validates,
packages, references, and checksums it. Hosts accept or deny the requested
Publisher API permission without overriding its URL.

`publisher-backend <command>` is a legacy alias for `publisher-api <command>`.

Runtime API responses should be JSON:

```json
{ "data": { "ok": true }, "traceId": "trace-success" }
```

```json
{ "items": [], "nextCursor": null, "hasMore": false, "traceId": "trace-page" }
```

```json
{ "errorCode": "validation_failed", "message": "Validation failed", "traceId": "trace-error" }
```

## Diagnostics And Workflow Commands

### Doctor

Use after installing the CLI or when the environment is broken.

```powershell
miniprogram doctor
miniprogram doctor --json
```

### Capabilities

Use when authoring `manifest.json` capabilities or checking supported feature
IDs.

```powershell
miniprogram capabilities
miniprogram capabilities --json
```

### Workflow Status

Use to inspect a mini-program or host workspace.

```powershell
miniprogram workflow status --workspace D:\my_profile
miniprogram workflow status --workspace D:\my_profile --json
miniprogram workflow status --workspace D:\my_profile_host --json
```

This helps confirm build output, validation state, partner packages, generated
host files, endpoint files, and optional runtime API usage.

`--remote` is kept as a compatibility flag. Provider remote checks were removed
from the MVP static artifact flow.

### Environment Commands

Use only for legacy/local artifact workspace state. Most static GitHub Pages
workflows do not need environment commands.

```powershell
miniprogram env init
miniprogram env list
miniprogram env use local
miniprogram env status
miniprogram env status --json
```

## Command Cheat Sheet

| Command | Use when |
| --- | --- |
| `miniprogram create <appId>` | Start a new mini-program. |
| `miniprogram preview -d chrome` | Test UI quickly during editing. |
| `miniprogram build` | Generate Mp JSON from Dart authoring code. |
| `miniprogram validate` | Check manifest and generated screen JSON. |
| `miniprogram artifact build` | Create an immutable portable release bundle. |
| `miniprogram artifact verify` | Verify bundle structure, identity, and checksums. |
| `miniprogram partner package <appId>` | Create a JSON handoff for host apps. |
| `miniprogram embed init` | Add SDK integration files to a Flutter host. |
| `miniprogram host endpoint import` | Import a partner package into a host. |
| `miniprogram host endpoint add` | Add an endpoint manually by URL. |
| `miniprogram host capability init location --platform android` | Install generic one-time approximate Android location support. |
| `miniprogram host run -d <device>` | Run the host app with Flutter. |
| `miniprogram artifact-host ...` | Manage a local static artifact host. |
| `miniprogram publisher-api ...` | Work with optional runtime middle-server APIs. |
| `miniprogram workflow status` | Inspect mini-program or host setup. |
| `miniprogram doctor` | Check tooling/environment health. |

## Common Problems

- `miniprogram` is not recognized: add Dart pub global bin to `PATH`.
- Host cannot open the mini-program: check `artifactBaseUrl` and verify
  `artifacts/<appId>/latest.json` opens in a browser.
- Static artifacts are missing on GitHub Pages: upload the generated
  `artifacts` directory without changing its internal paths.
- Android release build fails with disk errors: keep 5-8 GB free on `C:`.
- Android release build reports missing Cupertino icons: add
  `cupertino_icons: ^1.0.8` to the host app dependencies.
- Backend unreachable errors appear in static Track 1: remove runtime API
  actions/config or finish the optional Publisher API setup.
