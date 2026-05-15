# Changelog

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
