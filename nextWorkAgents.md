# Next Work Agents

## Mission
Design and implement the next developer-facing workflow as a **global Dart CLI**
named `miniprogram`, built from the existing
`packages/mini_program_tooling` package.

This document is the handoff for the next implementation wave only. It does
not redefine the whole platform roadmap. The goal is to make mini-program
creation, local backend lifecycle, local publish flow, and existing-app
embedding feel like one coherent CLI instead of a collection of wrappers.

## Locked Outcomes

### Global install shape
- Package remains `mini_program_tooling` for the first CLI wave.
- Preferred released install command is:
  - `dart pub global activate mini_program_tooling`
- Repo-local contributor activation command is:
  - `dart pub global activate --source path <repo-root>/packages/mini_program_tooling`
- Global executable is:
  - `miniprogram`

### V1 command contract
These commands are part of the first implementation wave and should be treated
as the public CLI surface:

- `miniprogram create <mini-program-id>`
- `miniprogram build <mini-program-id>`
- `miniprogram validate <mini-program-id>`
- `miniprogram publish <mini-program-id>`
- `miniprogram embed init --project-root <path>`
- `miniprogram backend start --port 8080`
- `miniprogram backend stop`
- `miniprogram backend status`
- `miniprogram backend reset-local --yes`

### Reserved, but not in the first implementation wave
These are intentionally deferred and must not be implemented as part of v1:

- `miniprogram publish <mini-program-id> --target cloud`
- `miniprogram env use local`
- `miniprogram env use cloud`

The first implementation wave only supports **local** backend publishing. Cloud
publishing and environment switching are the next phase after the local CLI is
stable.

## Implementation Strategy

### Package and entrypoint
- Reuse `packages/mini_program_tooling` as the implementation home.
- Add `packages/mini_program_tooling/bin/miniprogram.dart` as the command
  router entrypoint.
- Prefer one shared parser/router with subcommands over separate unrelated CLIs.

### Compatibility policy
- Keep the current low-level Dart bins for compatibility:
  - `create_mini_program.dart`
  - `build_mini_program.dart`
  - `validate_delivery.dart`
  - `publish_mini_program.dart`
  - `init_mini_program_embedding.dart`
- Keep current PowerShell wrappers for compatibility during the transition.
- Once the global CLI exists, wrappers should delegate to `miniprogram` where
  practical, but that delegation can happen after the router is stable.

### Command ownership map
- `create`
  - wraps the existing scaffolder logic
- `build`
  - wraps the existing builder logic
- `validate`
  - wraps the existing delivery validator logic
- `publish`
  - wraps build + validate + local backend publish logic
- `embed init`
  - wraps the existing embedding initializer
- `backend start|stop|status|reset-local`
  - are new backend lifecycle commands and require new implementation work

## Path Resolution And Local State

### `miniprogram create <id>`
- Default output root is `./<id>` in the current working directory.
- Folder name and mini-program id are the same by default.
- Repo-managed creation remains optional and explicit through future flags.
- The default behavior must favor standalone mini-program folders, not
  `mini_programs/<id>/` inside the platform repo.

### `build`, `validate`, and `publish`
These commands accept `<mini-program-id>` as the primary positional input and
must resolve the mini-program root in this order:

1. explicit `--mini-program-root`
2. `--repo-root` + `mini_programs/<id>`
3. `./<id>`
4. current directory, but only if it already looks like a mini-program root and
   the manifest id matches the provided `<id>`

If nothing resolves, fail with a clear error that explains which paths were
checked.

### Local state directory
- Store CLI-owned local state in:
  - `.mini_program/`
- This directory is repo-local and untracked.
- The implementation must add `.mini_program/` to `.gitignore`.

### State files
Use these files for the first implementation wave:

- `.mini_program/backend.local.json`
  - stores backend PID, configured port, log file paths, and last start time
- `.mini_program/published_local_artifacts.json`
  - stores the locally published artifact folders created by `publish`

The CLI must treat these files as the source of truth for local backend and
local publish bookkeeping.

## Local Backend Lifecycle

### `miniprogram backend start --port 8080`
- Starts `backend/local_backend_service`.
- Records PID, port, log file paths, and startup metadata in
  `.mini_program/backend.local.json`.
- Default port is `8080`.
- Custom port is supplied only through `start --port <n>`.
- No separate `miniprogram backend port` command should exist.

### `miniprogram backend status`
- Reports whether the recorded PID is alive.
- Reports the configured port from local state.
- Attempts a backend health check against the running local service.
- Reports log file paths if they were recorded.
- If the PID is stale, report that clearly and do not pretend the backend is
  healthy.

### `miniprogram backend stop`
- Stops the recorded backend process if it exists.
- Clears stale backend state if the PID no longer exists.
- Does not remove published backend artifacts.

### `miniprogram backend reset-local --yes`
- This is destructive and must require `--yes`.
- Only removes locally published artifact folders tracked in
  `.mini_program/published_local_artifacts.json`.
- Must not wipe all of `backend/api/`.
- Must not remove rollout rules, capability policies, secure API policies, or
  repo-seeded backend files that were not created by the CLI's local publish
  flow.

This rule is critical. "Reset local" means "clean local publish outputs," not
"delete the backend."

## Publish Behavior And Future Cloud Model

### V1 publish behavior
`miniprogram publish <id>` means:

- build
- validate
- publish to the **local backend only**
- update `.mini_program/published_local_artifacts.json`

The first implementation wave must not require environment switching to publish.

### Future cloud model
The intended future environment model is:

- developer works against `local` first
- later points the same host app + SDK to `cloud`
- only backend environment/config changes
- mini-program contracts, host integration, and SDK runtime shape stay the same

Future environment names are locked as:

- `local`
- `cloud`

This doc does not introduce multi-tenant SaaS or per-company product
configuration. The model is company-owned backend infrastructure with
developer-local and cloud environments.

## Required Tests

The implementation that follows this handoff must include:

- CLI parser tests for all listed commands and flags
- `create` flow test for standalone `./<id>` output
- `build`, `validate`, and `publish` path-resolution tests
- local backend `start` / `status` / `stop` lifecycle tests
- `backend reset-local --yes` safety tests proving only tracked local publish
  outputs are removed
- compatibility tests proving legacy Dart bins and PowerShell wrappers still
  work or delegate cleanly
- README/docs updates that make `miniprogram` the preferred command surface for
  the new workflow

## Defaults And Assumptions
- `nextWorkAgents.md` lives at the repo root.
- This handoff is focused on the **CLI roadmap**, not the full platform
  roadmap.
- `mini_program_tooling` remains the implementation home for the first global
  CLI wave.
- Local backend is the only supported publish target in the first wave.
- Cloud targeting and environment switching are documented follow-up work.
- Destructive local cleanup must always be explicit and scoped to CLI-tracked
  publish artifacts only.
