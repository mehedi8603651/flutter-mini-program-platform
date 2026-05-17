# Changelog

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
