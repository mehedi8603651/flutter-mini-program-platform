# mini_program_tooling

Developer tooling for the portable Flutter mini-program platform.

This package exposes the global `miniprogram` CLI used to create mini-programs,
build and validate authored flows, publish to the local backend, initialize
embedding adapters for existing Flutter apps, and manage the repo-local backend
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
miniprogram build <mini-program-id>
miniprogram validate <mini-program-id>
miniprogram publish <mini-program-id>
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

Initialize a standalone backend workspace once:

```bash
miniprogram backend init
```

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
miniprogram build coupon_center
miniprogram validate coupon_center
miniprogram publish coupon_center
```

If a standalone backend workspace was initialized earlier with
`miniprogram backend init`, `publish` writes manifests and screens into that
workspace instead of the platform repo backend.

Initialize the embedding adapter for an existing Flutter app:

```bash
cd <existing-flutter-app>
miniprogram embed init
```

`embed init` updates the host app `pubspec.yaml` to use the published
`mini_program_sdk` and `mini_program_contracts` packages.

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

`backend reset-local --yes` only removes tracked local publish outputs. It does
not wipe all of `backend/api/` or remove rollout, capability, or secure API
policy files that were not created by the CLI publish flow.

## Notes

- `publish --target cloud` is intentionally reserved for a later CLI phase.
- `env use local|cloud` only switches saved CLI context in this phase. Cloud
  publish and cloud backend operations are still follow-up work.
- Standalone build/publish/validate no longer require a platform repo root.
- Normal builds use the managed pinned Stac builder bundled inside
  `mini_program_tooling`.
- `--stac-cli-script` remains the escape hatch when you intentionally need to
  override that managed builder.
- Local backend lifecycle commands can work from either:
  - a `miniprogram backend init` workspace
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
