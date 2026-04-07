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
- `create_mini_program.ps1`
  - Wraps the Dart scaffolder in `packages/mini_program_tooling`.
  - Generates a starter mini-program with the current repo structure and
    capability-aware defaults.
  - Intended to reduce copy-paste mistakes when a developer or partner team
    starts a new portable flow.
- `build_mini_program.ps1`
  - Wraps the Dart build helper in `packages/mini_program_tooling`.
  - Resolves the available Stac CLI path and verifies the expected entry screen
    JSON after the build.
  - Intended to keep local authoring and CI-friendly build commands consistent.
- `publish_mini_program.ps1`
  - Wraps the Dart publish helper in `packages/mini_program_tooling`.
  - Runs build plus validation and then publishes the result into the local
  backend sample.
  - Intended to give authors one safe command for the local backend flow.
- `init_mini_program_embedding.ps1`
  - Wraps the Dart embedding initializer in `packages/mini_program_tooling`.
  - Generates `lib/mini_program/` starter files for an existing Flutter app.
  - Intended to make old-app embedding adoption repeatable without copying a sample host.

## CI Rule
- Use `smoke_repo.ps1` as the local pre-push command.
- In GitHub Actions, prefer explicit smoke steps when clearer failure
  diagnostics are more important than reusing the wrapper script directly.
