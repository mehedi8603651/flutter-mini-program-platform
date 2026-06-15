# mini_program_tooling

Command-line tooling for the Flutter mini-program platform.

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
create -> edit -> preview -> build -> validate -> publish static -> partner package -> embed/import host -> run host
```

Important terms:

- `mini-program root`: the folder with `manifest.json`, `mp/`, `tool/`, and `pubspec.yaml`
- `host project root`: the Flutter app folder with `pubspec.yaml`, `lib/`, and platform folders
- `public_mini_program`: the generated static artifact folder to upload
- `artifactBaseUrl`: the public URL where `public_mini_program` is hosted
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

For optional runtime API testing, preview can use a backend URL:

```powershell
miniprogram preview -d chrome --backend-base-url http://127.0.0.1:9090
```

`--backend-base-url` is the compatibility flag name for the optional runtime
middle-server URL. Static opening does not need it.

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

### 5. Publish Static Artifacts

Use when the mini-program is ready to serve from GitHub Pages, CDN, object
storage, or any HTTPS static file host.

```powershell
miniprogram publish --target static --output public_mini_program --clean
```

Use explicit paths:

```powershell
miniprogram publish --target static `
  --mini-program-root D:\my_profile `
  --output D:\my_profile\public_mini_program `
  --clean
```

Static output includes:

```text
manifests/<appId>/latest.json
manifests/<appId>/versions/<version>.json
screens/<appId>/<version>/<screenId>.json
assets/<appId>/<version>/
metadata/
.nojekyll
PUBLISH_INSTRUCTIONS.md
```

Upload the contents of `public_mini_program` to a public static host.

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
- creates `lib/mini_program/`
- creates `openAppMiniProgram(...)`
- creates `buildMiniProgramConfig(...)`
- adds Android debug network files when Android exists

Generated folder shape:

```text
lib/mini_program/
  app_host_bridge.dart
  mini_program.dart
  mini_program_launcher.dart
  mini_program_runtime_setup.dart
```

After importing endpoints, the host also gets:

```text
lib/mini_program/
  mini_program_endpoints.dart
  mini_program_registry.dart
```

Use `--force` only when you intentionally want to overwrite scaffold-managed
generated files:

```powershell
miniprogram embed init --project-root D:\my_profile_host --force
```

### 2. Import A Partner Package

Use when a mini-program publisher gives you a partner JSON file.

```powershell
miniprogram host endpoint import D:\my_profile\my_profile.partner.json --project-root .
```

This writes or updates:

```text
lib/mini_program/mini_program_endpoints.dart
lib/mini_program/mini_program_registry.dart
```

### 3. Add An Endpoint Manually

Use when you know the `artifactBaseUrl` and do not have a partner JSON file.

```powershell
miniprogram host endpoint add my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --title "My Profile" `
  --project-root D:\my_profile_host
```

Only add `--backend-base-url` when the mini-program uses runtime API actions:

```powershell
miniprogram host endpoint add my_profile `
  --artifact-base-url https://<github-user>.github.io/my_profile_static/ `
  --backend-base-url https://publisher.example.com/api/ `
  --project-root D:\my_profile_host
```

Opening the mini-program still uses static artifacts. The backend URL is only
for runtime actions such as `Mp.backend.call`, `Mp.backend.query`, search,
load-more, forms, and `Mp.lazy.chunk`.

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

Use the generated helper from any host page:

```dart
openAppMiniProgram(
  context,
  appId: 'my_profile',
  title: 'My Profile',
);
```

For a fresh host app, wrap the app once:

```dart
MiniProgramScope(
  config: buildMiniProgramConfig(endpoints: buildMiniProgramEndpoints()),
  child: const MyApp(),
)
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
  --backend-base-url http://127.0.0.1:9090 `
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

`--backend-base-url` is the current compatibility flag name for the optional
runtime middle-server URL. In architecture docs this is `middleServerApiUrl`.

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
| `miniprogram publish --target static` | Write public static artifact files. |
| `miniprogram partner package <appId>` | Create a JSON handoff for host apps. |
| `miniprogram embed init` | Add SDK integration files to a Flutter host. |
| `miniprogram host endpoint import` | Import a partner package into a host. |
| `miniprogram host endpoint add` | Add an endpoint manually by URL. |
| `miniprogram host run -d <device>` | Run the host app with Flutter. |
| `miniprogram artifact-host ...` | Manage a local static artifact host. |
| `miniprogram publisher-api ...` | Work with optional runtime middle-server APIs. |
| `miniprogram workflow status` | Inspect mini-program or host setup. |
| `miniprogram doctor` | Check tooling/environment health. |

## Common Problems

- `miniprogram` is not recognized: add Dart pub global bin to `PATH`.
- Host cannot open the mini-program: check `artifactBaseUrl` and verify
  `manifests/<appId>/latest.json` opens in a browser.
- Static publish looks empty on GitHub Pages: upload the contents of
  `public_mini_program`, not the folder itself unless the URL includes that
  folder name.
- Android release build fails with disk errors: keep 5-8 GB free on `C:`.
- Android release build reports missing Cupertino icons: add
  `cupertino_icons: ^1.0.8` to the host app dependencies.
- Backend unreachable errors appear in static Track 1: remove runtime API
  actions/config or finish the optional Publisher API setup.
