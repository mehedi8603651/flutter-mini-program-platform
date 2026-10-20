## 0.7.0

- Breaking: remove `topBar` JSON and its renderer; use artifacts rebuilt with UI `0.3.0` and the new `appBar` node.
- Render standalone Material app bars with mini-program-owned content and styling, scoped text/icon defaults, bounded scrollable actions on narrow screens, and strict metadata/value validation. Do not imply host back/drawer controls or add status-bar padding; existing navigation and Android task handling remain independent.

## 0.6.17

- Render standalone standard, small, large, and extended floating action buttons with strict JSON validation, accessible names, host-theme colors, and existing gesture-aware action dispatch.
- Prevent duplicate taps while actions are pending, safely handle disposal, constrain extended labels on narrow screens, and disable default Hero tags so several buttons coexist during navigation. Existing page and Android task integrations remain unchanged; no new dependencies or permissions.

## 0.6.16

- Render state-bound date, time, and date-range fields using Flutter's built-in Material pickers, with strict JSON/value validation and existing form submission support.
- Keep confirmed selections across retained Android task switches. Cancellation, backgrounding, disposal, owner/configuration changes, and external state edits invalidate owned dialogs and stale results. Enforce live-state quotas before updating forms or running change actions.
- Store timezone-free `YYYY-MM-DD`, `HH:mm`, and `{start, end}` values while formatting selections through host Material localizations. No native bridge, permissions, or new dependencies.

## 0.6.15

- Add optional, default-denied external map providers and per-app policy. Enforce strict destination validation, user gestures, foreground routes, safe async completion, and atomic result state.
- Opening an external map preserves the calling mini-program session; results
  confirm launch acceptance only. Travel mode and routing remain provider-owned.
- Document the observed Google Maps walking-mode limitation and remaining real
  Amap/Baidu device validation in the Android shop-location guide.

## 0.6.14

- Add independent host-controlled clipboard read/write, short system haptic effects, and user-controlled phone dialer providers. Enforce explicit gestures, foreground visibility, runtime value limits, and safe stale clipboard completion.

## 0.6.13

- Add optional microphone providers, default-denied per-app recording policy,
  duration/size limits, gesture checks, and atomic recording state updates.
- Finalize recording on background/hidden lifecycle transitions while keeping
  permission-dialog inactivity safe; cancel and clean on disposal/app changes.
- Integrate opaque recordings with ownership-checked playback, uploads, sharing,
  and release; clean late, cancelled, invalid, and quota-rejected audio.

## 0.6.12

- Add host-controlled gallery providers and per-app accepted count/byte limits.
- Require an explicit user gesture, preserve the previous selection on cancel,
  validate returned metadata, and clean up late or rejected results.
- Keep selected media across activity pauses and retained Android task switches;
  release app-owned copies on mini-program disposal or explicit media release.
- Integrate gallery references with existing previews, sharing, and uploads.

## 0.6.11

- Add `MiniProgramVisibility` for persistent host surfaces.
- Keep hidden mini-program pages mounted so in-memory state and internal
  navigation resume without reloading.
- Pause or release foreground-only playback, camera, flashlight, QR, and
  brightness resources when a mini-program is hidden or the host backgrounds.
- Ignore system Back events for hidden mini-program pages while preserving
  foreground page navigation.
- Allow SDK loading and error views to scroll in short Android viewports.
- Document native Android windows as the current integration focus; defer the
  SDK-provided in-app workspace and presentation transfer to a future design.

## 0.6.10

- Render page-inherited responsive breakpoints, local-width layout variants,
  centered constrained content, and adaptive grids without storing viewport
  information in mini-program state.

## 0.6.9

- Render and strictly validate root `page` and reusable `topBar` nodes while
  retaining legacy root padding for existing artifacts.
- Prevent inherited text decoration from leaking into SDK toast messages and
  keep transient feedback above the software keyboard.
- Add password visibility controls and a keyboard-aware, scrollable email
  authentication sheet for compact Android viewports.

## 0.6.8

- Add host-policy-controlled, lifecycle-owned temporary display brightness
  scopes that restore the host setting on unmount and app backgrounding.

## 0.6.7

- Add provider-neutral, host-policy-controlled system sharing with explicit
  user-gesture enforcement and stable chooser-opened acknowledgements.
- Validate text, HTTPS URLs, and app-owned media references before invoking a
  host provider, without exposing native paths, content URIs, or file bytes.

## 0.6.6

- Add provider-neutral, app-scoped streamed audio and inline video playback
  sessions with strict artifact/Publisher API source resolution.
- Enforce host-accepted audio/video policy, expose bounded playback status,
  and release sessions during mini-program lifecycle cleanup.
- Add an `audio` runtime cache bucket and per-kind temporary-cache policy while
  leaving native buffering implementation under host provider control.
- Add optional fullscreen sessions, audio volume/speed dispatch, video
  lifecycle callbacks, and app-background pausing while keeping providers
  source-compatible with Phase 1.

## 0.6.5

- Add cross-platform QR rendering plus provider-neutral, host-policy-controlled
  QR scanning with explicit-user-gesture enforcement and inert results.

## 0.6.4

- Add host-policy-controlled, provider-neutral delegated system-camera photo
  capture with cancellation, opaque metadata, and temporary-media cleanup.
- Add host-policy-controlled flashlight management with app ownership,
  status reporting, lifecycle shutdown, and stable failures.
- Add an app-isolated temporary media registry for bounded host previews,
  reference-based file uploads, explicit release, and lifecycle cleanup.

## 0.6.3

- Add host-policy-controlled streaming Publisher API uploads and downloads
  through a provider-neutral `MiniProgramFileTransferProvider`.
- Add app-isolated transfer identity, progress, cancellation, MIME and
  destination enforcement, bounded result metadata, and stable failures.
- Reuse validated artifact Publisher API endpoint resolution and authorization
  without exposing native paths, content URIs, or file bytes to live state.

## 0.6.2

- Accept the add, delete, edit, and note icon names during strict Mp screen
  validation, matching the renderer and `mini_program_ui 0.2.1` authoring API.

## 0.6.1

- Render and strictly validate live-state-controlled `stateTextField` nodes,
  including multiline editing, state synchronization, actions, and styling.
- Render semantic generic `tap` wrappers through the existing action boundary.
- Render common add, delete, edit, and note icons.

## 0.6.0

- Establish the feature-oriented runtime architecture completed in `0.5.14`
  as the new SDK baseline.
- Preserve public APIs, historical import paths, manifest compatibility,
  renderer output, state/cache formats, and runtime behavior.

## 0.5.14

- Refactor validator, action, widget, host lifecycle, navigation, state, router,
  cache, persistence, authentication, data, delivery, asset, catalog, and
  discovery internals into focused feature-owned modules.
- Add architecture, behavioral identity, and historical import guards for the
  reorganized runtime boundaries.
- Preserve existing public APIs, import paths, JSON validation, rendering,
  lifecycle, cache, networking, and error behavior.

## 0.5.13

- Add provider-neutral, host-policy-controlled one-time approximate location.
- Validate and dispatch `location.getCurrent` with atomic state updates,
  stable errors, request deduplication, and target preservation on failure.
- Route accepted per-app location policy through mini-program endpoints.

## 0.5.12

- Load optional versioned `publisher_backend.json` contracts with manifests.
- Enforce host-accepted Publisher API permission before runtime actions and
  create an app-scoped connector from the artifact declaration.
- Return `publisher_api_disabled` when the host denies Publisher API access.

## 0.5.11

- Forward backend query `forceRefresh` to connectors so explicit refreshes can
  bypass otherwise valid response-cache entries.

- Load validated same-origin JSON artifact assets into the accepted data cache
  and search them through bounded app/version-scoped in-memory indexes.
- Render controlled local search fields, horizontal static/dynamic lists,
  single-series line charts, and root pull-to-refresh viewports.
- Add optional JSON asset loading to HTTP and endpoint-routing sources.
- Render reusable location, weather, wind, temperature, and world icons.

## 0.5.10

- Resolve reusable actions from bounded nearest `actionScope` nodes, including
  stable missing-action and recursive-call failures.
- Keep stale cached mini-program content laid out after the temporary offline
  notice dismisses.
- Remount a replaced mini-program screen even when the replacement uses the
  same screen ID, resetting its lifecycle-owned widgets correctly.

## 0.5.9

- Render reactive conditional node branches and dispatch strict boolean
  `action.ifElse` control flow.
- Run lifecycle-owned countdown nodes with bounded durations, pause/resume,
  restart tokens, background elapsed-time reconciliation, remaining-seconds
  state, and exactly-once completion actions.
- Render generic brain, trophy, timer, close, refresh, and bolt icons.

## 0.5.8

- Show the stale-cache offline notice with accessible warning colors and
  dismiss it automatically after two seconds.

## 0.5.7

- Load manifests and screens from the canonical portable artifact layout at
  `artifacts/<appId>/latest.json` and
  `artifacts/<appId>/<version>/screens/<screenId>.json`.

## 0.5.6

- Render and validate reusable styled text and icon action buttons.
- Add history, backspace, and back-arrow runtime icons.
- Allow hosts to hide `MiniProgramPage` chrome and select its background color
  through launch options for immersive mini-programs.

## 0.5.5

- Execute default, decrement, copy conversion, and toggle state actions.
- Support bound increment/decrement operands with finite defaults and clamped
  minimum/maximum bounds.
- Add rollback-capable state batches, atomic patch actions, defensive reads,
  and host-owned live-state byte, entry, value, and depth limits.
- Add one-time initialization and disposable state-scope runtime nodes.
- Add app-scoped cache usage snapshots and the safe `cache.info` action.
- Route generated per-app live-state policy through mini-program endpoints.

## 0.5.4

- Execute bounded text and list state transformation actions.
- Add a core-Dart restricted math parser with evaluate, compare, seeded random,
  and aggregate actions.
- Preserve math targets on failure and expose stable structured error state.

## 0.5.3

- Add `MiniProgramCacheBundle.webPersistent()` backed by shared preferences for browser runtime cache persistence.
- Add a shared-preferences runtime cache store that uses the existing host policy, TTL, and byte-limit enforcement.
- Allow host-accepted `video` buckets in Mp cache actions while keeping `session` host-controlled.

## 0.5.2

- Give `MiniProgramPage` loaded content a normal scaffold and light surface instead of inheriting a dark/transparent host route background.

## 0.5.1

- Fix Android release builds by using const Material `IconData` values for Mp runtime icons.

## 0.5.0

- Remove artifact credential fields and headers from endpoint/source models.
- Keep static artifact loading provider-neutral through `artifactBaseUrl`.
- Keep optional runtime middle-server connectors for backend actions.
- Rename host-only cache priority to `hostPinned`.
