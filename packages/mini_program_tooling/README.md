# mini_program_tooling

Developer tooling for the portable Flutter mini-program platform.

This package exposes the global `miniprogram` CLI used to create mini-programs,
build and validate authored flows, publish to the local backend, initialize
embedding adapters for existing Flutter apps, and manage the local backend
lifecycle.

## Install

Released package:

```bash
dart pub global activate mini_program_tooling
```

Repo-local contributor install:

```bash
dart pub global activate --source path <repo-root>/packages/mini_program_tooling
```

## CLI surface

```text
miniprogram create <mini-program-id>
miniprogram doctor
miniprogram backend init
miniprogram env init
miniprogram env use <local|cloud>
miniprogram env status
miniprogram build [mini-program-id]
miniprogram preview -d <chrome|windows|emulator-5554> [mini-program-id]
miniprogram validate [mini-program-id]
miniprogram publish [mini-program-id]
miniprogram embed init
miniprogram backend start --port 8080
miniprogram backend stop
miniprogram backend status
miniprogram backend reset-local --yes
```

## Examples

Check your machine and saved CLI state first:

```bash
miniprogram doctor
```

Create a standalone mini-program in the current directory:

```bash
miniprogram create coupon_center
```

Use managed preview for the fastest authoring loop:

```bash
cd coupon_center
miniprogram preview -d chrome
```

Preview v1 currently supports:

- `chrome`
- `windows`
- Android emulator ids such as `emulator-5554`

`preview` is a developer-only loop. It does not require `backend init` or
`backend start`, does not publish into `backend/api/`, and keeps a managed
hidden host app under `.mini_program/preview_host`.

During preview, the CLI:

- builds the mini-program before launch
- starts a tiny session-scoped localhost preview server when needed
- watches `manifest.json`, `stac/**`, `assets/**`, and
  `lib/default_stac_options.dart`
- rebuilds on save and triggers a full preview refresh
- uses `http://10.0.2.2:<port>/preview/` automatically for Android emulator
  preview sessions

Preview capability behavior in v1:

- `analytics` logs through the preview host and returns success
- `native_navigation` opens a preview-native placeholder page
- `secure_api` returns an explicit preview-only failure

Initialize a standalone backend workspace once:

```bash
miniprogram backend init
```

On Windows, this defaults to `%LOCALAPPDATA%\mini_program\backend\`. Use
`miniprogram backend init --root <custom-path>` only when you intentionally
want a different workspace location.

Initialize local CLI env once from a standalone mini-program workspace:

```bash
cd <workspace>/coupon_center
miniprogram env init
```

That writes both a workspace-local `.mini_program/env.json` and a user-level
fallback env file, so later commands can run from this workspace or from
unrelated directories without repeating setup.

Then build, validate, and publish without any platform repo path:

```bash
cd coupon_center
miniprogram build
miniprogram validate
miniprogram publish
```

If a standalone backend workspace was initialized earlier with
`miniprogram backend init`, `publish` writes manifests and screens into that
workspace instead of the platform repo backend.

From outside the mini-program folder, the explicit form still works:

```bash
miniprogram build coupon_center
miniprogram validate coupon_center
miniprogram publish coupon_center
```

Initialize the embedding adapter for an existing Flutter app:

```bash
cd <existing-flutter-app>
miniprogram embed init
```

`embed init` updates the host app `pubspec.yaml` to use the published
`mini_program_sdk` and `mini_program_contracts` packages.

When the local backend is already running on port `8080`, the generated
runtime setup uses target-aware defaults:

- Android local default: `http://10.0.2.2:8080/api/`
- desktop, Chrome on the same machine, and iOS simulators:
  `http://127.0.0.1:8080/api/`
- Android USB `adb reverse` flows keep using `127.0.0.1`, and the shared SDK
  retries local loopback between `10.0.2.2` and `127.0.0.1` on transport
  failures

Conditions:

- the local backend should already be running on port `8080`
- Android USB or emulator loopback may still depend on an active `adb reverse`
  session when the device cannot route to `10.0.2.2`
- if the Android device or emulator connects after backend start, rerun
  `miniprogram backend start --port 8080` or reapply `adb reverse`
- physical devices over Wi-Fi should override
  `MINI_PROGRAM_BACKEND_HOST=<computer-lan-ip>`

So Android emulator development should usually work with:

```bash
flutter run -d emulator-5554
```

`miniprogram embed init` also writes Android debug-only cleartext/network
configuration so the generated emulator default can reach
`http://10.0.2.2:8080/api/` without manual manifest edits.

For physical-device Wi-Fi or cloud testing, override either the full base URL
or just the host/port:

```bash
flutter run -d chrome --dart-define=MINI_PROGRAM_BACKEND_HOST=192.168.1.25
flutter run -d windows --dart-define=MINI_PROGRAM_BACKEND_BASE_URL=https://mini.example.com/api/
```

If you need to target an app from another directory, use:

```bash
miniprogram embed init --project-root <existing-flutter-app>
```

Start and inspect the local backend:

```bash
miniprogram backend start --port 8080
miniprogram backend status
miniprogram backend stop
```

When `adb` is available, `miniprogram backend start` also tries
`adb reverse tcp:<port> tcp:<port>` for connected Android emulators and
devices. That keeps the common local Android flow on plain `flutter run`
instead of requiring a manual reverse step every time.

For local debugging, `miniprogram backend start` and `miniprogram backend
status` print the target-specific URLs the generated host adapter expects:

- Android emulator: `http://10.0.2.2:<port>/api/`
- desktop and Chrome on the same machine: `http://127.0.0.1:<port>/api/`
- Android USB with `adb reverse`: `http://127.0.0.1:<port>/api/`

The generated host runtime also logs the resolved backend base URL and whether
it came from:

- `MINI_PROGRAM_BACKEND_BASE_URL`
- `MINI_PROGRAM_BACKEND_HOST` and `MINI_PROGRAM_BACKEND_PORT`
- target-aware defaults

For Chrome and other web targets, the generated local backend workspace now
includes browser-friendly CORS and localhost private-network headers, so plain
local web runs can reach `http://127.0.0.1:8080/api/` without manual backend
service patching.

`miniprogram doctor` reports:

- Dart runtime availability
- `flutter` on PATH
- managed pinned Stac builder status and pinned version
- saved env configuration
- optional platform repo root
- local backend workspace layout
- current backend health/state

## Local CLI state

The CLI keeps repo-local state in:

- `.mini_program/env.json`
- `.mini_program/backend_workspace.json`
- `.mini_program/backend.local.json`
- `.mini_program/published_local_artifacts.json`

It also keeps a user-level fallback file in:

- `~/.mini_program/global_env.json`
- `~/.mini_program/global_backend_workspace.json`

Project-local preview also manages:

- `.mini_program/preview_host/`

`backend reset-local --yes` only removes tracked local publish outputs. It does
not wipe all of `backend/api/` or remove rollout, capability, or secure API
policy files that were not created by the CLI publish flow.

## Notes

- `publish --target cloud` is intentionally reserved for a later CLI phase.
- `env use local|cloud` only switches saved CLI context in this phase. Cloud
  publish and cloud backend operations are still follow-up work.
- Standalone build/publish/validate no longer require a platform repo root.
- `preview` is the fastest local authoring loop; `publish` plus
  `backend start` remains the real local delivery simulation.
- Normal builds use the managed pinned Stac builder bundled inside
  `mini_program_tooling`.
- `--stac-cli-script` remains the escape hatch when you intentionally need to
  override that managed builder.
- Local backend lifecycle commands can work from either:
  - the default per-user `miniprogram backend init` workspace
  - the platform repo layout with `backend/local_backend_service/` and
    `backend/api/`
- `publish` follows the same backend workspace resolution, so local publish
  outputs and `backend reset-local --yes` stay attached to the initialized
  backend workspace.
- Existing low-level Dart bins remain in the repo for compatibility.
- The repo PowerShell wrappers now delegate to the installed `miniprogram`
  command for the standard text workflow and only fall back to legacy Dart
  entrypoints for compatibility-only modes such as `-Output json`.
- `miniprogram ...` is the preferred workflow.
