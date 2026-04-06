# tools Sub-Agent

## Mission
Keep repo-level scripts focused on build, validation, publish, sync, and smoke-test workflows.

## Owns
- Repository automation scripts
- Local developer helper scripts
- CI-friendly wrapper scripts

## Must Do
- Prefer predictable scripts over one-off commands.
- Validate manifests, actions, and capabilities before publish.
- Verify the installed Stac CLI behavior before hardcoding paths in scripts.

## Must Not Do
- Mix business logic into shell scripts.
- Encode host-specific secrets or environment assumptions directly into the repo.
- Skip failure-path checks for convenience.

## Expected Script Areas
- build mini-programs
- validate manifests
- publish artifacts
- smoke test hosts
- sync assets

## Current Script
- `sync_assets.ps1`
  - Syncs `mini_programs/<id>/manifest.json` and `stac/.build/screens/*.json`
    into `hosts/<host>/assets/mini_programs/<id>/`.
  - Validates source and target paths before removing stale copied screen JSON.
- `publish_local_backend.ps1`
  - Publishes `mini_programs/<id>/manifest.json` and built screen JSON into
    `backend/api/` as static sample endpoints.
  - Keeps backend sample files derived from authored mini-program output.
- `inspect_delivery.ps1`
  - Wraps the Dart CLI in `packages/mini_program_tooling`.
  - Calls the local backend decision inspection route with host delivery
    context and prints human-readable or JSON output.
  - Intended for local operability debugging and CI smoke checks.
- `validate_delivery.ps1`
  - Wraps the Dart delivery validator in `packages/mini_program_tooling`.
  - Validates authored manifests, published backend manifests/screens, rollout
    rules, capability policies, and secure API policies before runtime.
- `smoke_repo.ps1`
  - Runs the repo-level smoke suite in a stable order.
  - Covers delivery validation plus backend, SDK, and host analyze/test steps.
  - Intended to be the single local and CI-friendly pre-push command.

## CI Rule
- Root GitHub Actions workflows should call `tools/smoke_repo.ps1` instead of
  duplicating repo smoke commands inline.
- Keep local and CI verification aligned around the same script entrypoint.
