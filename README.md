# flutter-mini-program-platform

Portable mini-program platform built around:

- shared contracts
- a shared Flutter runtime SDK
- Stac-authored portable UI
- local and future cloud delivery
- controlled host-native bridges

The project goal is simple:

> one mini-program should be able to run inside multiple host apps without
> rewriting the whole business flow for every host

## What This Platform Is

This is a **platform repo**, not a normal single Flutter app.

It has five main layers:

1. `mini_program_contracts`
2. `mini_program_sdk`
3. mini-program source
4. host apps
5. backend delivery

The key design rule is:

> keep portable UI declarative, keep sensitive and host-specific power behind
> the host bridge

## Current Shipped System

Already shipped:

- published packages:
  - `mini_program_contracts`
  - `mini_program_sdk`
  - `mini_program_tooling`
- global `miniprogram` CLI
- standalone local backend workspace
- standalone local authoring flow
- host-app embedding flow for Flutter apps
- target-aware local runtime defaults for:
  - Android emulator
  - Windows desktop
  - Chrome on the same machine
  - Android USB with `adb reverse`

The current system is strongest for **local developer workflows** and
**portable Flutter-hosted mini-programs**.

Future-only roadmap is tracked in:

- [nextWorkAgents.md](D:/flutter-mini-program-platform/nextWorkAgents.md)

## What This Platform Is Good For

This platform is a good fit for:

- forms
- onboarding
- profile and settings flows
- recharge or top-up flows
- campaign pages
- dashboards
- account flows
- subscription and plan-selection flows
- feedback and support flows
- modular business workflows
- tenant-specific or host-specific presentation differences

It is especially suitable for:

- super-app style products
- company apps
- enterprise apps
- partner-hosted apps

## What Should Stay Native

Do not force everything into a mini-program.

Keep these native:

- payment SDK execution
- banking-grade secure auth
- biometric and OTP/PIN flows
- login bootstrap
- camera-heavy flows
- map-heavy real-time flows
- advanced editors
- highly custom animation-heavy experiences
- actual TV/player playback UI core
- hardware- or device-permission-heavy flows

Use mini-programs for the **portable business UI around those features**, not
for the sensitive or platform-heavy core execution.

## Current Technical Shape

### Contracts
`packages/mini_program_contracts`

This package defines the shared wire language:

- manifest shape
- capability names
- action names
- result payloads
- version rules
- stable error codes

### Runtime SDK
`packages/mini_program_sdk`

This package renders portable mini-program UI inside Flutter host apps.

It is responsible for:

- loading manifests and screens
- validating SDK compatibility
- enforcing declared capabilities
- rendering Stac JSON safely
- dispatching approved actions through the host bridge

### Tooling CLI
`packages/mini_program_tooling`

This package exposes the global `miniprogram` command used for:

- create
- doctor
- env
- build
- preview
- validate
- publish
- cloud
- embed init
- backend init/start/stop/status/reset-local

### Mini-Program Authoring
Mini-programs are authored in Stac DSL and built into JSON.

Safe assumption:

```text
Stac DSL / StacWidget-style Dart -> stac build -> JSON
```

Unsafe assumption:

```text
any arbitrary Flutter widget tree -> automatic portable JSON
```

That is not the model.

## How The Platform Works

At a high level:

1. developer writes Stac DSL mini-program screens
2. `miniprogram build` runs the managed Stac builder
3. JSON screens and manifest artifacts are produced
4. developers either preview them directly or publish them into the local backend workspace
5. host app loads manifest and screen JSON through `mini_program_sdk`
6. host bridge handles approved native operations

High-level flow:

```text
author -> build -> preview
                    or
author -> build -> validate -> publish -> backend delivery -> SDK load ->
render -> action dispatch -> host-native execution when needed
```

## Preferred Developer Entry Point

Install the published CLI once:

```powershell
dart pub global activate mini_program_tooling
```

Then use:

```powershell
miniprogram --help
```

The CLI is the source of truth for developers.

Older wrappers may still exist, but `miniprogram ...` is the preferred path.

## Local Developer Workflow

### 1. Create a mini-program

```powershell
cd D:\
miniprogram create my_coupon_app
```

### 2. Fast preview loop

For the normal authoring loop, use managed preview first:

```powershell
cd D:\my_coupon_app
miniprogram preview -d chrome
```

V1 preview targets:

- `chrome`
- `edge`
- `ios` on macOS with Xcode
- `linux`
- `macos`
- `windows`
- `emulator-5554` and other Android emulator ids
- Android USB device ids such as `R58M123ABC`
- Android Wi-Fi device ids such as `192.168.1.25:5555`

Preview behavior:

- builds the current mini-program
- generates a hidden managed host under `.mini_program/preview_host`
- starts a tiny internal localhost preview transport when needed
- watches `manifest.json`, `stac/**`, `assets/**`, and `lib/default_stac_options.dart`
- rebuilds and fully refreshes the preview after a successful save

Preview mode rules:

- not the real local backend
- not `backend/api/`
- no manual `backend start`
- keeps the last successful UI visible if a rebuild fails
- Android emulator preview prefers `adb reverse tcp:<port> tcp:<port>` and
  uses `http://127.0.0.1:<port>/preview/` when reverse is available
- if emulator reverse cannot be applied, preview falls back to
  `http://10.0.2.2:<port>/preview/`
- Android USB preview auto-applies `adb reverse tcp:<port> tcp:<port>` and
  uses `http://127.0.0.1:<port>/preview/` inside the device session
- Android Wi-Fi preview uses a resolved LAN host such as
  `http://192.168.1.10:<port>/preview/`
- if auto-detected LAN routing is wrong, set `MINI_PROGRAM_PREVIEW_LAN_HOST`
  to your dev machine IP before running preview

Preview capability limits in v1:

- `analytics` logs inside the preview host and succeeds
- `native_navigation` opens a preview-only placeholder screen
- `secure_api` returns an explicit preview-only failure

### 3. Initialize local backend workspace for real delivery testing

```powershell
miniprogram backend init
```

On Windows the default backend workspace is:

```text
%LOCALAPPDATA%\mini_program\backend\
```

### 4. Initialize local env inside the mini-program

```powershell
cd D:\my_coupon_app
miniprogram env init
```

### 5. Build, validate, publish

Inside the mini-program folder:

```powershell
miniprogram build
miniprogram validate
miniprogram publish
```

Or from outside:

```powershell
miniprogram build my_coupon_app
miniprogram validate my_coupon_app
miniprogram publish my_coupon_app
```

### 6. Start backend

```powershell
miniprogram backend start --port 8080
miniprogram backend status
```

Use the backend flow when you want to verify the real local delivery shape,
not for the fastest authoring loop.

## Embed Into A Flutter Host App

Create or open a Flutter app, then run:

```powershell
flutter create my_mini_host
cd my_mini_host
miniprogram embed init
flutter pub get
```

The generated embed layer adds:

- `mini_program_sdk`
- `mini_program_contracts`
- app-owned bridge files under `lib/mini_program/`
- local backend runtime defaults

## Local Run Targets

With the local backend running on port `8080`, the generated runtime uses
target-aware defaults.

### Android emulator

```powershell
flutter run -d emulator-5554
```

Default local backend:

```text
http://10.0.2.2:8080/api/
```

### Windows desktop

```powershell
flutter run -d windows
```

Default local backend:

```text
http://127.0.0.1:8080/api/
```

### Chrome

```powershell
flutter run -d chrome
```

Default local backend:

```text
http://127.0.0.1:8080/api/
```

### Android physical device over USB

Start backend first so `adb reverse` can be applied:

```powershell
miniprogram backend start --port 8080
flutter run -d <android-device-id>
```

### Android or iPhone over Wi-Fi

Override the backend host with your machine LAN IP:

```powershell
flutter run -d <device-id> --dart-define=MINI_PROGRAM_BACKEND_HOST=<your-lan-ip>
```

Override the full URL when needed:

```powershell
flutter run -d <device-id> --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=http://<host>:8080/api/
```

## Current Capability Boundary

The platform can support advanced business domains, but only with the right
bridge boundary.

### Good current direction

- payment flow UI
- banking workflow UI
- recharge UI
- TV business flows
- account and subscription flows

### Required rule

- portable UI stays in the mini-program
- sensitive execution stays native

Examples:

- payment SDK execution should stay native
- secure banking operations should stay native
- video playback core should stay native
- mini-program can orchestrate the user flow around them

## Native Host Expansion

Future native Android or other non-Flutter hosts should follow this path first:

- host app remains mostly native
- mini-program area uses embedded Flutter runtime
- one embedded runtime can support many mini-programs

This means:

- first integration cost is the main cost
- mini-program 2 to 100 mostly reuse the same runtime foundation
- native app size and memory increase
- but the whole native app does not degrade by a simple fixed percentage

For this platform type, that tradeoff is usually acceptable.

## Cloud Direction

The current first shipped cloud path is AWS-backed named environments through
the CLI:

```powershell
miniprogram env init
miniprogram env configure my-aws-prod --provider aws --bucket mini-program-prod --region us-east-1 --cloudfront-base-url https://d111111abcdef8.cloudfront.net --api-base-url https://api.example.com
miniprogram env use my-aws-prod
miniprogram publish --target cloud
```

Current cloud support in this phase:

- provider implementation shipped: `aws`
- planned next providers: `gcp`
- planned next providers: `custom-s3-compatible`

AWS cloud publish in this phase:

- uses the configured named cloud environment
- requires AWS CLI credentials outside the repo
- requires S3 bucket versioning to be enabled
- uploads immutable release artifacts plus release/catalog metadata to S3
- does not provision CloudFront for you from the CLI yet
- deploys and manages the AWS API Gateway and Lambda backend through:
  - `miniprogram cloud deploy`
  - `miniprogram cloud status`
  - `miniprogram cloud outputs`
  - `miniprogram cloud logs`
  - `miniprogram cloud destroy`
  - `miniprogram cloud doctor`
  - `miniprogram cloud rollback <version> [mini-program-id]`
- includes a deployable AWS SAM backend under:
  - [infra/aws/mini_program_cloud_api/README.md](D:/flutter-mini-program-platform/infra/aws/mini_program_cloud_api/README.md)

The shipped AWS backend stack reads the published S3 objects and serves the
existing Flutter backend contract:

- `GET /api/discovery/mini-programs.json`
- `GET /api/manifests/<miniProgramId>/latest.json`
- `GET /api/manifests/<miniProgramId>/versions/<version>.json`
- `GET /api/screens/<miniProgramId>/<version>/<screenId>.json`
- `GET /health`

Typical AWS flow:

```powershell
cd D:\my_coupon_app
miniprogram publish --target cloud
miniprogram cloud deploy
miniprogram cloud outputs
```

Copy the host-ready define directly when needed:

```powershell
miniprogram cloud outputs --format dart-define
```

Then connect an embedded Flutter host app through the CLI:

```powershell
cd D:\my_flutter_host
miniprogram embed init
miniprogram embed cloud configure --env my-aws-prod
miniprogram host run -d chrome --env my-aws-prod
```

`embed cloud configure` stores the selected cloud environment for that host app
under `.mini_program/host_cloud.json`, and `host run` wraps `flutter run` with
the resolved `MINI_PROGRAM_BACKEND_BASE_URL`.

Manual Flutter host wiring still works against the stack output:

```powershell
flutter run -d chrome --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://<api-id>.execute-api.<region>.amazonaws.com/prod/api/
```

The best long-term cloud model remains:

- `S3 + CloudFront` for versioned artifacts
  - manifests
  - screens
  - themes
  - assets
- `API Gateway + Lambda` for dynamic and secure routes
  - discovery
  - rollout and host-aware selection
  - capability filtering
  - secure operations

Public GitHub JSON URLs are okay for a simple public prototype, but not the
recommended real cloud delivery model.

## What Is Not The Right Direction

These are intentionally not the main path:

- replacing the CLI with a VS Code-only workflow
- treating WebView or WASM-in-app as the primary host model
- letting mini-program JSON execute sensitive native behavior directly
- assuming any arbitrary Flutter widget tree can become portable JSON

## Repo Smoke And Verification

Run repo smoke checks with:

```powershell
powershell -ExecutionPolicy Bypass -File D:\flutter-mini-program-platform\tools\smoke_repo.ps1
```

Verify the installed global CLI with:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify_global_cli.ps1
```

Use `miniprogram doctor` before troubleshooting:

```powershell
miniprogram doctor
```

## Additional Docs

- [mini_program_authoring.md](D:/flutter-mini-program-platform/docs/mini_program_authoring.md)
- [embed_existing_flutter_app.md](D:/flutter-mini-program-platform/docs/embed_existing_flutter_app.md)
- [packages/mini_program_tooling/README.md](D:/flutter-mini-program-platform/packages/mini_program_tooling/README.md)
- [packages/mini_program_sdk/README.md](D:/flutter-mini-program-platform/packages/mini_program_sdk/README.md)
- [nextWorkAgents.md](D:/flutter-mini-program-platform/nextWorkAgents.md)
