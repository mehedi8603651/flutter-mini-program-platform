# Changelog

## 0.2.14

- fix `miniprogram embed init` so generated host app `pubspec.yaml` files pin
  `mini_program_sdk: ^0.1.1` instead of the stale `^0.1.0` constraint
- refresh the embedding docs and regression tests around the generated hosted
  SDK dependency version

## 0.2.13

- make local backend start attempt `adb reverse tcp:<port> tcp:<port>` for
  connected Android devices and emulators so local host apps can keep using
  `127.0.0.1` when emulator routing to `10.0.2.2` is broken
- report successful `adb reverse` setup in backend start output
- add regression coverage for the new local Android reverse-port setup

## 0.2.12

- make `embed init` generate Android debug-only cleartext/network security
  config so the default local emulator backend URL can work without manual
  manifest edits
- refresh the tooling docs around the generated Android local-backend setup and
  align the public CLI surface with the optional in-folder
  `build`/`validate`/`publish` flow

## 0.2.11

- fix backend workspace resolution so `validate`, `publish`, backend commands,
  and `doctor` fall back to the valid global backend workspace when a stale
  parent `.mini_program/backend_workspace.json` is present
- add regression coverage for stale local backend workspace state masking the
  initialized global backend workspace

## 0.2.10

- let `miniprogram build`, `miniprogram validate`, and `miniprogram publish`
  infer the mini-program id from the current working directory when the user is
  already inside the mini-program root
- keep the explicit forms such as `miniprogram build <id>` and
  `miniprogram publish <id>` for scripted and multi-project workflows
- refresh docs and tests around the simpler in-folder authoring workflow

## 0.2.9

- make `miniprogram backend init` default to the per-user global backend
  workspace on Windows at `%LOCALAPPDATA%\mini_program\backend\`
- keep `miniprogram backend init --root <path>` as the explicit override for a
  custom backend workspace
- document the generated local backend URL defaults so Android emulator
  workflows can usually run with plain `flutter run -d emulator-5554` when the
  backend is already running on port `8080`
- refresh the generated embed README, public docs, and tests around the local
  backend URL defaults and `MINI_PROGRAM_BACKEND_BASE_URL` override

## 0.2.8

- let `miniprogram embed init` default to the current working directory when
  `--project-root` is omitted
- keep `miniprogram embed init --project-root <path>` for explicit and scripted
  workflows
- refresh docs, tests, and installed-CLI smoke coverage for the simpler embed
  flow

## 0.2.7

- manage a pinned Stac builder internally inside `mini_program_tooling`
- expose the managed pinned Stac builder status and version through
  `miniprogram doctor`
- keep `--stac-cli-script` as the escape hatch while removing the normal need
  for a separate visible `stac` install

## 0.2.6

- let `miniprogram env init` succeed without a saved platform repo root for the
  standalone workflow
- let standalone `validate` and `publish` run against `backend init`
  workspaces without any platform repo path
- update `embed init` to patch host app `pubspec.yaml` with hosted
  `mini_program_sdk` and `mini_program_contracts` dependencies
- refresh docs and the installed-CLI smoke flow around the fully standalone
  local workflow

## 0.2.5

- add `miniprogram backend init` to scaffold a standalone backend workspace
- add tracked backend workspace state in `.mini_program/backend_workspace.json`
  and `~/.mini_program/global_backend_workspace.json`
- let backend lifecycle commands resolve either a standalone backend workspace
  or the platform repo layout
- make `miniprogram publish` write manifests and screens into the initialized
  standalone backend workspace when `miniprogram backend init` has been used
- keep tracked local publish state attached to that backend workspace so
  `backend reset-local --yes` cleans the correct local backend
- update validation and installed-CLI smoke coverage for the standalone backend
  publish flow

## 0.2.2

- add `miniprogram doctor` for machine, env, repo, and backend diagnostics

## 0.2.1

- refresh the pub.dev release metadata for the current env-based workflow
- ship the saved global repo-root fallback used by `embed init` and backend
  commands when running from unrelated working directories

## 0.2.0

- add `miniprogram env init`, `miniprogram env use`, and
  `miniprogram env status`
- add `.mini_program/env.json` as saved CLI environment state for standalone
  mini-program workspaces
- add a user-level fallback config in `~/.mini_program/global_env.json` so
  `embed init` and backend commands can reuse the saved repo root from
  unrelated working directories
- let `build`, `validate`, `publish`, and `backend ...` reuse saved repo-root
  configuration instead of requiring repeated `--repo-root`
- update the installed CLI smoke flow and docs around the new env workflow

## 0.1.0

- add the global `miniprogram` executable
- add `create`, `build`, `validate`, `publish`, and `embed init` commands
- add repo-local backend lifecycle commands for `start`, `status`, `stop`, and
  `reset-local`
- add repo-local CLI state tracking under `.mini_program/`
