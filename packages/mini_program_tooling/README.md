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
miniprogram build <mini-program-id>
miniprogram validate <mini-program-id>
miniprogram publish <mini-program-id>
miniprogram embed init --project-root <path>
miniprogram backend start --port 8080
miniprogram backend stop
miniprogram backend status
miniprogram backend reset-local --yes
```

## Examples

Create a standalone mini-program in the current directory:

```bash
miniprogram create coupon_center
```

Build, validate, and publish a standalone mini-program against a platform repo:

```bash
miniprogram build coupon_center --mini-program-root <workspace>/coupon_center --repo-root <repo-root>
miniprogram validate coupon_center --mini-program-root <workspace>/coupon_center --repo-root <repo-root>
miniprogram publish coupon_center --mini-program-root <workspace>/coupon_center --repo-root <repo-root>
```

Initialize the embedding adapter for an existing Flutter app:

```bash
miniprogram embed init --project-root <existing-flutter-app> --repo-root <repo-root>
```

Start and inspect the local backend:

```bash
miniprogram backend start --repo-root <repo-root> --port 8080
miniprogram backend status --repo-root <repo-root>
miniprogram backend stop --repo-root <repo-root>
```

## Local CLI state

The CLI keeps repo-local state in:

- `.mini_program/backend.local.json`
- `.mini_program/published_local_artifacts.json`

`backend reset-local --yes` only removes tracked local publish outputs. It does
not wipe all of `backend/api/` or remove rollout, capability, or secure API
policy files that were not created by the CLI publish flow.

## Notes

- `publish --target cloud` is intentionally reserved for a later CLI phase.
- Local backend lifecycle commands expect the platform repo layout with
  `backend/local_backend_service/` and `backend/api/`.
- Existing low-level Dart bins remain in the repo for compatibility.
- The repo PowerShell wrappers now delegate to the installed `miniprogram`
  command for the standard text workflow and only fall back to legacy Dart
  entrypoints for compatibility-only modes such as `-Output json`.
- `miniprogram ...` is the preferred workflow.
