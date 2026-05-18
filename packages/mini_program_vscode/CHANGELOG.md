# Changelog

## 0.1.10

- Add `MiniProgram: Publish Public Static MiniProgram` as a direct GitHub
  Pages/CDN export command with optional `--clean`.
- Extend host diagnostics for public endpoints by checking latest manifest and
  entry screen URLs, and by confirming no MiniProgram access key is required.
- Update docs for `mini_program_tooling` 0.3.13 public static publishing.

## 0.1.9

- Add public/static endpoint support to publish, host endpoint, and partner
  package prompts.
- Let host developers add/import public endpoints without MiniProgram access
  keys while keeping protected endpoint command logging redacted.
- Show public/protected endpoint mode in status and diagnostics.

## 0.1.8

- Add `MiniProgram: Check Host Endpoint Remote` so host developers can pick a
  configured endpoint appId and inspect cloud/app/access-key status from VS Code.
- Add `MiniProgram: Copy Cleanup Commands` for test/E2E app cleanup and access
  key revocation command snippets.
- Improve host status and diagnostics wording when endpoint routing is active,
  making clear the default backend URL is only a fallback.
- Document Flutter pub mirror advisory warnings and Kotlin daemon cache warnings
  as troubleshooting notes.

## 0.1.7

- Add host registry helpers for generating `lib/mini_program/mini_program_registry.dart`
  and adding mini-program entries from configured endpoints.
- Add `MiniProgram: Copy Demo Host Button` and `MiniProgram: Copy Workflow
  Commands` for faster host app setup and repeatable publish/install/test flows.
- Keep demo button assistance copy-only so the extension never edits
  host-owned `main.dart`.
- Extend host diagnostics to warn when an endpoint is configured but no likely
  host UI launcher opens that appId.
- Clarify that MiniProgram access keys protect delivery access and are not
  user-auth or server secrets.

## 0.1.6

- Add one-click guided workflows for new mini-program setup, AWS publish,
  partner handoff, host setup, host endpoint add/import, and host smoke tests.
- Guided workflows run existing CLI commands in sequence and stop on the first
  failed step.
- Add tests for guided workflow definitions and ordering.

## 0.1.5

- Add diagnostics commands for workspace, mini-program, host app, and cloud
  delivery checks.
- Print pass/warn/error reports with concrete fix suggestions in the MiniProgram
  output channel.
- Keep diagnostics secret-safe by redacting MiniProgram access-key values.

## 0.1.4

- Add partner package commands for publisher handoff creation, local validation,
  and opening/revealing existing `.partner.json` files.
- Redact partner package access-key inputs from command lines printed in the
  output channel.
- Refresh workflow status after creating a partner package so the sidebar shows
  nearby handoff files.

## 0.1.3

- Add environment commands for init, AWS configuration, active environment
  selection, and environment status.
- Add cloud commands for deploy, status, and outputs.
- Add local backend commands for init, start, stop, and status.
- Keep status-style commands useful when the backend/cloud stack is not ready by
  printing CLI output instead of treating readiness as an extension failure.

## 0.1.2

- Add access-key commands for create, list, revoke, and rotate.
- Infer mini-program appId from the current mini-program workspace manifest
  when prompting for access-key commands.
- Keep generated access keys visible in the output channel for copy/paste while
  still redacting secret command-line inputs.

## 0.1.1

- Add host app commands for embed init, host cloud configuration, endpoint
  import, endpoint add, and host run.
- Add sidebar title buttons for partner endpoint import and host run.
- Redact access-key values from command lines printed in the output channel.
- Keep endpoint setup prompts open while switching windows to copy API URLs or
  access keys.

## 0.1.0

- Add the local-first MiniProgram Tools VS Code extension MVP.
- Add a native Activity Bar/sidebar status view backed by
  `miniprogram workflow status --json`.
- Add core workflow commands for create, build, validate, preview, publish,
  local status refresh, and manual remote status refresh.
