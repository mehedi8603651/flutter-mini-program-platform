## 0.7.15

- List `maps` in `host capability init --help` alongside the other supported
  Android capability installers.

## 0.7.14

- Add optional Android `host capability init maps` generation with host-controlled Google Maps/Amap/Baidu app preferences, explicit coordinate handling, requested/accepted policy, and separate-task-safe regeneration.
- Generate mini-programs against UI `0.2.13` and hosts/preview hosts against
  SDK `0.6.15` and contracts `0.3.17`.
- Keep native maps optional without extra Android permissions, embedded map
  dependencies, or API keys. Provider behavior and validation limits are
  documented in the Android shop-location guide.

## 0.7.13

- Add optional Android `clipboard`, `vibration`, and `phone` capability installers, accepted/requested policy generation, and safe regeneration alongside separate tasks. No extra Android permissions are required.

## 0.7.12

- Add `host capability init microphone --platform android`: foreground AAC/M4A
  recording, runtime RECORD_AUDIO permission, private FileProvider/cache, and a
  process-wide recorder guard shared by separate Android tasks. Keep recorder
  setup/finalization and file work on a dedicated worker to avoid blocking UI.
- Use a distinct microphone FileProvider component so recording, gallery,
  playback, uploads, and sharing can coexist in the same host.
- Add requested/accepted microphone policy handling without accepting app
  permissions during installation; preserve host-owned Dart providers and force
  refresh composition.
- Upgrade tooling-managed Media3 support to play owned audio references through
  the shared native media registry, preserving host-owned Dart adapters.
- Generate against contracts 0.3.15, UI 0.2.11, and SDK 0.6.13.

## 0.7.11

- Add `host capability init gallery --platform android` with Android's system
  Photo Picker, document-picker fallback, single/multiple selection, and
  private app-cache imports without broad gallery or storage permissions.
- Normalize photo orientation, bound decoding and resizing, encode JPEG copies
  without source EXIF metadata, and enforce host count/byte limits atomically.
- Generate a host-owned Dart adapter, private FileProvider, shared native
  registrations, and AndroidX dependencies compatible with separate tasks.
- Add requested/accepted gallery policy handling; installation never grants
  a mini-program permission. Generate against contracts 0.3.14, UI 0.2.10,
  and SDK 0.6.12.

## 0.7.10

- Add optional `embed init --android-separate-tasks` generation for Kotlin
  Android hosts, with five reusable Activity/task slots, a retained Dart
  entrypoint, and an SDK navigation delegate. Standard embedding remains the
  default and keeps its existing generated output.
- Preserve host code, endpoint imports, accepted policies, and native
  capability registrations during task setup and scaffold refreshes. Validate
  conflicts before committing the complete optional setup in one transaction.
- Generate separate-task hosts against SDK `0.6.11` and document independent
  engine configuration, task capacity, Back behavior, and ROM limitations.

## 0.7.9

- Generate Android Media3 fullscreen playback in an opaque immersive window
  that hides system bars, prevents underlying host content from leaking, and
  restores the host orientation after dismissal.
- Upgrade recognized Tooling-owned Media3 Kotlin sources when a newer
  generator template is installed, while preserving unmarked custom files.
- Select portrait or landscape from the active video dimensions and retain
  fit-preserving letterboxing rather than cropping course or product media.
- Generate mini-programs against UI `0.2.8` and hosts/preview hosts against
  contracts `0.3.13` and SDK `0.6.9`.

## 0.7.8

- Import temporary display-brightness requests with safe default denial and
  generate accepted per-app maximum levels for host endpoints.
- Add idempotent Android display-brightness capability installation backed by
  a window-only override with automatic restoration and no Android permission.
- Generate mini-programs against UI `0.2.7` and hosts/preview hosts against
  contracts `0.3.13` and SDK `0.6.8`.

## 0.7.7

- Import requested system-share policy with safe default denial and generate
  accepted text, URL, media, and item-count limits for host endpoints.
- Add idempotent Android system-share capability installation backed by the
  platform chooser and the existing app-owned media registry, with no new
  Android permission or dependency.
- Generate mini-programs against UI `0.2.6` and hosts/preview hosts against
  contracts `0.3.12` and SDK `0.6.7`.

## 0.7.6

- Place generated Android capability sources under one dedicated
  `mini_program/generated/` tree, grouped by capability, with an ownership
  guide that keeps host-native code outside the generated boundary.
- Reduce `MainActivity.kt` integration to one stable
  `MiniProgramNativeSetup.register(...)` call and generate deterministic
  capability registration in `MiniProgramNativeSetup.kt`.
- Move QR and Media3 dependencies into a dedicated generated Gradle script
  referenced by one stable app-Gradle apply block.
- Generate that dependency script with Groovy syntax for both Groovy and
  Kotlin DSL hosts, avoiding Android release-lint crashes on applied Kotlin
  scripts, and migrate the earlier generated `.gradle.kts` file atomically.
- Atomically migrate recognized legacy root Kotlin sources and inline Gradle
  blocks while preserving custom host code and refusing ambiguous conflicts.

## 0.7.5

- Reconcile location, file transfer, camera, flashlight, QR, and media
  playback registrations through one deterministic managed block in
  `MainActivity.kt`, independent of capability installation order.
- Reconcile QR CameraX/ML Kit and Media3 dependencies through one managed
  Gradle block while migrating recognized legacy generated marker blocks.
- Commit each native capability installation as one rollback-capable file
  transaction and reject malformed managed blocks before modifying host files.
- Preserve custom host code and host-owned provider implementations while
  making older generated integrations migrate on the next capability rerun.

## 0.7.4

- Import requested audio/video playback permissions with safe default denial
  and generate accepted media playback plus audio/video cache policy.
- Add idempotent Android `audio` and `video` capability initialization backed
  by one host-owned Media3/ExoPlayer adapter for headless audio and inline
  video.
- Add native MP4/audio range and HLS-segment LRU/TTL caching, audio-focus and
  becoming-noisy handling, foreground lifecycle pausing, and fullscreen video.
- Migrate the unmodified generated Phase 1 `video_player` provider on the next
  audio/video capability initialization while preserving custom host files.
- Generate mini-programs against UI `0.2.5` and hosts/preview hosts against
  contracts `0.3.11` and SDK `0.6.6`.

## 0.7.3

- Import host-owned `qrScanner` policy and add an idempotent Android QR
  capability installer using CameraX and bundled ML Kit QR-only detection.
- Generate mini-programs against UI `0.2.4` and hosts/preview hosts against
  contracts `0.3.10` and SDK `0.6.5`.

## 0.7.2

- Import requested camera and flashlight permissions and generate safe-denied
  host policy plus accepted runtime policy resolvers.
- Add Android capability installers for delegated system-camera capture using
  Activity Result and FileProvider, and flashlight control using CameraManager.
- Generate a shared app-owned Android media registry so camera output can be
  previewed, uploaded through the file provider, and explicitly released.
- Generate mini-programs against UI `0.2.3` and hosts/preview hosts against
  contracts `0.3.9` and SDK `0.6.4`.

## 0.7.1

- Import requested file-transfer policy and generate host-accepted per-app
  upload, download, MIME, destination, concurrency, storage, and optional size
  limits with safe default denial.
- Add `miniprogram host capability init file --platform android` to install a
  host-owned document picker and streaming Publisher API adapter without an
  extra Flutter plugin or broad storage permission.
- Generate mini-programs against UI `0.2.2` and hosts/preview hosts against
  contracts `0.3.8` and SDK `0.6.3`.
- Correct generated host bridge newline escaping.

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
