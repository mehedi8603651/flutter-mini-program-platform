## 0.7.0

- Establish the feature-oriented CLI and generation architecture completed in
  `0.6.15` as the new tooling baseline while preserving commands, aliases,
  public facades, artifact bytes, and exit behavior.
- Generate new mini-programs with `mini_program_ui: ^0.2.0` and new host and
  preview projects with `mini_program_sdk: ^0.6.0`.

## 0.6.15

- Refactor tooling internals into feature-owned normal Dart libraries across
  delivery validation, host integration, artifact construction, preview,
  policy generation, local state, workflows, scaffolding, development builds,
  handoffs, diagnostics, Publisher API tooling, publishing, and CLI dispatch.
- Preserve public APIs, CLI output and exit codes, generated files, process
  behavior, JSON ordering, and artifact bytes with architecture, public API,
  and parity coverage.
- Replace the remaining mock Publisher API `part` libraries with a thin
  compatibility facade and separately owned workspace, lifecycle, health,
  process, launcher, state, URL, and template modules.
- Make `artifact-host reset-local` clean tracked canonical artifact bundles
  while retaining containment checks and unrelated host configuration.
- Exclude generated Dart/package state when initializing local artifact-host
  workspaces so installed templates never retain source-machine cache paths,
  and align the template and repository samples with canonical `artifacts/`
  delivery paths.
- Make installed-CLI release verification invoke the activated package
  directly so Windows batch wrappers cannot mask command failures, restore the
  source package configuration afterward, and remove its isolated temp data.

## 0.6.14

- Add `miniprogram host capability init location --platform android` to
  install reusable, foreground-only approximate location plumbing in an
  embedded Flutter host without accepting any app policy.
- Import requested foreground approximate location permission while preserving
  host-owned accepted decisions and unknown permission entries.
- Generate per-app location policy resolution and optional host location
  provider wiring with capability advertisement.
- Generate hosts against contracts `0.3.7` and SDK `0.5.13`, and
  mini-programs against UI `0.1.12`.

## 0.6.13

- Generate a complete design-neutral `lib/mini_program/` host integration with
  one public barrel import and a host-owned runtime composition file.
- Add registry-based launch helpers so host UI can open imported mini-programs
  without repeating app IDs and titles.
- Preserve host setup, bridge, policies, and endpoint-import output when
  `embed init --force` refreshes scaffold-generated files.

## 0.6.12

- Package, reference, checksum, and verify root `publisher_backend.json` in
  immutable artifacts.
- Import requested Publisher API permission into host-owned policy while
  preserving explicit host acceptance.
- Generate accepted Publisher API policy resolvers and remove per-app host URL
  and preview URL configuration.
- Rename contract initialization input to `--publisher-api-url` and add a
  host-facing `--permission-reason`.

## 0.6.11

- Validate statically referenced JSON data assets during development builds,
  artifact builds, and artifact verification.
- Generate preview sources that serve JSON resources from the existing
  same-origin `/preview/assets/` route.
- Generate mini-programs and hosts against contracts `0.3.5`, UI `0.1.11`,
  and SDK `0.5.11`.

## 0.6.10

- Generate hosts and mini-programs against contracts `0.3.4` and UI `0.1.10`
  for scoped reusable action support.
- Generate embedded and preview hosts with SDK `^0.5.10` so stale offline
  content remains visible after its temporary notice dismisses.

## 0.6.9

- Generate mini-programs and hosts with the conditional control-flow and
  lifecycle countdown package releases.

## 0.6.8

- Add deterministic `miniprogram artifact build` and
  `miniprogram artifact verify` commands for portable immutable bundles.
- Standardize artifact delivery on
  `artifacts/<appId>/<version>/` with checksums, release metadata, a catalog,
  and an atomically updated latest manifest.
- Generate hosts with `mini_program_sdk: ^0.5.7` for canonical artifact URLs.

## 0.6.7

- Generate mini-programs with `mini_program_ui: ^0.1.8` and hosts with
  `mini_program_sdk: ^0.5.6` for styled action controls and immersive launches.

## 0.6.6

- Generate mini-program and host projects with the expanded state action API.
- Import host-owned live-state limits, preserve accepted policy extensions,
  and generate cache plus live-state endpoint policy resolvers.

## 0.6.5

- Generate mini-program and host projects with the state transformation and
  core math action package releases.

## 0.6.4

- Generate preview hosts that use `MiniProgramCacheBundle.webPersistent()` on
  web so accepted runtime cache can be tested in Chrome.
- Document `webPersistent()` as the browser-host counterpart to native
  `fileBacked(...)` cache bundles.

## 0.6.3

- docs update 

## 0.6.2

- Generate host and preview projects with `mini_program_sdk: ^0.5.2` so new embedded hosts pick up the light mini-program page surface fix.

## 0.6.1

- Generate Android debug manifests that can override host `usesCleartextTraffic` settings safely.
- Generate host/preview projects with `mini_program_sdk: ^0.5.1` so Android release builds use const runtime icons.

## 0.6.0

- Remove external artifact delivery adapters and credential handoff flows from the active CLI.
- Keep static artifact publishing as the current frontend delivery path.
- Keep optional Publisher API/local mock runtime API flows.
- Generate/import partner packages around `appId + artifactBaseUrl`.
- Update workflow status, help text, docs, and tests for the static artifact plus optional middle-server architecture.
