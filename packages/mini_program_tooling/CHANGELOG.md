# Changelog

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
