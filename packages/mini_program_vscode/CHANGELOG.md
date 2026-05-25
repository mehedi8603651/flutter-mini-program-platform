# Changelog

## 0.1.33

- Require `mini_program_tooling` 0.3.42 for Firebase Hosting publish so newly
  published static delivery includes browser CORS headers and reliable CLI
  version metadata.
- Warn clearly when an older CLI is configured for Firebase Hosting publish.
- Verify CORS on the delivery URL after publish.
- Add Firebase Hosting manifest/CORS readiness rows to the Firebase host
  endpoint sidebar diagnostics.

## 0.1.32

- Add `MiniProgram: Publish MiniProgram to Firebase Hosting`, backed by
  `mini_program_tooling` 0.3.40.
- Guide Firebase publishers through env selection, Hosting public folder,
  optional site ID, deploy/dry-run mode, and generated delivery URL.
- Offer Firebase handoff-package creation after a successful Hosting publish.

## 0.1.31

- Add `MiniProgram: Create Firebase Host Handoff Package`, backed by
  `mini_program_tooling` 0.3.39.
- Guide publishers through Firebase env, delivery URL, access mode, and
  `.partner.json` output without asking for a host app root.
- Keep host wiring provider-neutral through the existing
  `MiniProgram: Import Host Endpoint` command.

## 0.1.30

- Fix Windows execution of the default `miniprogram` CLI by resolving the Dart
  pub shim and invoking it through `cmd.exe /d /c call` with separate arguments.
- Verified the Firebase host wiring command from the installed extension path
  with a multi-word title and local tooling 0.3.38.

## 0.1.29

- Fix Windows command launching so generated Firebase host wiring commands keep
  multi-word titles as one CLI argument.

## 0.1.28

- Update Firebase host integration diagnostics and documentation to recommend
  `mini_program_tooling` 0.3.38.
- Keep the existing Firebase host wiring UI from 0.1.27, but avoid pointing
  developers at stale tooling versions after the 0.3.38 CLI version fix.

## 0.1.27

- Add `MiniProgram: Wire Firebase Publisher Backend Into Host App`, backed by
  `mini_program_tooling` 0.3.36.
- Guide Firebase host wiring through environment, host app root, delivery URL,
  public/protected access mode, and exact generated command preview/run.
- Show Firebase host endpoint readiness diagnostics in the sidebar after the
  host-command check.
- Gate Firebase host integration on the CLI capability map and update
  diagnostics to recommend tooling 0.3.36 for the full Firebase workflow.

## 0.1.26

- Add `MiniProgram: Smoke Test Firebase Publisher Backend With Write`, backed by
  `mini_program_tooling` 0.3.35.
- Prompt for coupon/user IDs and require a modal confirmation before calling
  Firebase `POST /coupon/redeem`.
- Gate Firebase write smoke on the CLI capability map and update diagnostics to
  recommend tooling 0.3.35 for the full Firebase workflow.
- Update docs and package metadata for the Firebase write-smoke workflow.

## 0.1.25

- Add Firebase Firestore production data commands backed by
  `mini_program_tooling` 0.3.34: export, import dry-run, redemption listing,
  and guarded Firebase Function destroy.
- Gate the new Firebase data-management actions on CLI capabilities so older
  tooling gets a clear 0.3.34 upgrade prompt.
- Show Firebase remote status/data counts from `workflow status --remote` in
  the sidebar.
- Update docs and packaging metadata for the Firebase production data workflow.

## 0.1.24

- Add Firebase Functions + Firestore publisher backend workflows backed by
  `mini_program_tooling` 0.3.32.
- Let `MiniProgram: Setup Publisher Backend` scaffold Firebase Functions with
  Firestore storage.
- Add Firebase environment configuration, deploy, status, outputs, smoke, seed,
  and Firestore data status commands.
- Warn when the configured CLI is older than the 0.3.32 Firebase workflow and
  show Firebase publisher backend rows in the sidebar when status reports them.

## 0.1.23

- Use `miniprogram capabilities --json` from `mini_program_tooling` 0.3.29
  for AWS DynamoDB feature detection.
- Cache CLI capability detection per workspace so sidebar actions stop running
  repeated `aws ... --help` probes.
- Keep the old help-probe detection as a fallback for older CLI installs.
- Update diagnostics to recommend `mini_program_tooling` 0.3.29 when quiet
  capability discovery is unavailable.

## 0.1.22

- Add AWS DynamoDB production data workflows backed by `mini_program_tooling`
  0.3.28: export, import dry-run, redemption listing, and guarded stack destroy.
- Add a 0.3.28 CLI capability warning for DynamoDB data management actions.
- Update README and command contributions for the new production data actions.

## 0.1.21

- Add AWS publisher backend smoke, write smoke, DynamoDB seed, DynamoDB data
  status, and outputs commands backed by `mini_program_tooling` 0.3.27.
- Let publisher backend setup scaffold AWS Lambda with bundled JSON or
  DynamoDB storage.
- Warn when the configured CLI is older than the 0.3.27 AWS smoke/write
  workflow and show richer AWS publisher backend status rows.

## 0.1.20

- Add AWS Lambda publisher backend commands for setup, deploy, status, logs, and
  host command copying.
- Let `MiniProgram: Setup Publisher Backend` choose between mock local and AWS
  Lambda templates.
- Show AWS publisher backend scaffold/deploy state in sidebar and diagnostics.
- Update docs for `mini_program_tooling` 0.3.23 publisher backend AWS flows.

## 0.1.19

- Add local mock backend mode to `MiniProgram: Add Host Endpoint`, backed by
  `miniprogram host endpoint add --backend-local-mock`.
- Add `MiniProgram: Copy Mock Backend Host Command` for quick local host setup.
- Show endpoint backend mode in sidebar/diagnostics.
- Update docs for `mini_program_tooling` 0.3.22 and `mini_program_sdk` 0.3.5
  loopback fallback.

## 0.1.18

- Add publisher backend starter commands for setup, run, stop, status, and
  local URL copying.
- Let mini-program creation and guided setup choose a mock publisher backend
  starter that uses `miniprogram create --with-backend mock`.
- Show publisher backend starter presence in the sidebar and diagnostics.
- Update docs for `mini_program_tooling` 0.3.20 mock backend starter flows.

## 0.1.17

- Show mini-program publisher backend action/query/builder usage in sidebar
  status and diagnostics.
- Warn when backend query/state helpers are detected so host setup includes
  `--backend-base-url`.
- Update docs for `mini_program_tooling` 0.3.19 and SDK backend binding
  helpers.

## 0.1.16

- Add optional publisher backend URL prompts to host endpoint add and partner
  package creation workflows.
- Show publisher backend endpoint status in the sidebar and diagnostics without
  exposing delivery access keys.
- Validate partner package `backendBaseUrl` shape when present and pass
  `--backend-base-url` through to the installed MiniProgram CLI.

## 0.1.15

- Prompt for a display title when adding host endpoints manually and pass it
  through to `miniprogram host endpoint add --title`.
- Support the generated registry `values` and `byAppId` helpers.
- Warn in host diagnostics when endpoint appIds and registry appIds drift.

## 0.1.14

- Add `--with-demo` support to `MiniProgram: Embed Init` and guided host setup
  so first-run host apps can generate a public jsDelivr demo endpoint and
  registry from VS Code.
- Update copied host workflow commands to use the public demo endpoint for
  first-run testing.

## 0.1.13

- Add the public Marketplace URL to README install instructions.

## 0.1.12

- Prepare the public Marketplace release metadata for publisher
  `MiniProgramTools`.
- Add the Marketplace PNG icon to packaged extension metadata.
- Put Marketplace install instructions before local VSIX development install
  instructions in the README.

## 0.1.11

- Fix `MiniProgram: Setup New MiniProgram` and `MiniProgram: Create MiniProgram`
  command argument order for `mini_program_tooling` 0.3.13.

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
