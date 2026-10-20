## 0.3.0

- Breaking: replace `Mp.topBar` with the standalone pure-Dart `Mp.appBar` builder. Rebuild mini-program artifacts and upgrade hosts to SDK `0.7.0`; the old `topBar` node is removed without an alias.
- Add custom title, leading and action content, centered titles, literal colors, toolbar/leading sizing, spacing, and elevation. Icon buttons without an explicit color inherit toolbar foreground styling while retaining their usual default outside an app bar.

## 0.2.15

- Add pure-Dart standalone `Mp.floatingActionButton(...)`, `.small`, `.large`, and `.extended` builders with existing actions, accessible names, disabled state, and optional colors. Position them with existing stack/positioned nodes; no page API changes or new dependencies.

## 0.2.14

- Add pure-Dart `Mp.dateTime.dateField`, `timeField`, and `dateRangeField` with state keys, form names, literal date limits, initial selections, required/disabled options, and change actions. No new dependencies.

## 0.2.13

- Add pure-Dart `Mp.maps.openLocation` and `Mp.maps.openDirections` with bounded destinations and runtime coordinate bindings.

## 0.2.12

- Add `Mp.clipboard.readText/writeText`, `Mp.vibration.trigger`, and `Mp.phone.openDialer` with pure-Dart validation and deterministic JSON.

## 0.2.11

- Add foreground `Mp.microphone.record`, `stop`, and `cancel` authoring.
- Add `MpAudioSource.hostMedia` for playback of app-owned voice notes.

## 0.2.10

- Add `Mp.gallery.pickImages` and `Mp.gallery.cancel` for single or multiple
  photo selection, bounded resizing, and JPEG quality requests.
- Reuse host-media image previews, sharing, uploads, and explicit release.

# Changelog

## 0.2.9

- Add page-level responsive breakpoints, width-selected `Mp.responsive`
  variants, centered `Mp.constrainedContent`, and adaptive grid sizing while
  preserving existing fixed-column grid JSON.

## 0.2.8

- Add root-only `Mp.page` authoring for explicit safe-area and background
  ownership without the SDK's legacy compatibility padding.
- Add `Mp.topBar` with bounded leading, title, and action regions so compact
  headers remain stable across narrow Android screens.

## 0.2.7

- Add lifecycle-owned `Mp.display.brightnessScope` authoring for temporary,
  host-controlled window brightness with automatic restoration.

## 0.2.6

- Add `Mp.share.open` for user-initiated system sharing of bounded text,
  absolute HTTPS URLs, and app-owned opaque media references.
- Keep native paths, content URIs, file bytes, and share-completion claims out
  of authored JSON and live state.

## 0.2.5

- Add trusted artifact and Publisher API audio/video source models.
- Add headless `Mp.audio` playback actions, inline `Mp.videoView`, and
  `Mp.video` controls with strict source, player, volume, speed, and cache-mode
  validation.
- Add the host-managed `audio` cache bucket alongside existing video policy.
- Add `Mp.audio.setVolume`/`setSpeed`, video enter/exit-fullscreen actions,
  and optional `onReady`, `onEnded`, and `onError` video lifecycle actions.

## 0.2.4

- Add cross-platform `Mp.qr.generate` rendering and host-controlled
  `Mp.qr.scan` authoring with bounded values, timeouts, and state targets.

## 0.2.3

- Add `Mp.camera.capturePhoto` and `Mp.camera.cancel` with optional bounded
  dimensions and host-private opaque media references.
- Add `Mp.flashlight.turnOn`, `turnOff`, `toggle`, and `getStatus` actions.
- Add app-owned temporary media composition through `MpImageSource.hostMedia`,
  `Mp.file.upload(mediaRefs: ...)`, and `Mp.media.release`.

## 0.2.2

- Add strictly validated `Mp.file.upload`, `Mp.file.download`, and
  `Mp.file.cancel` authoring actions for Publisher API file transfers.
- Keep native paths and file bytes outside mini-program JSON and live state.

## 0.2.1

- Add a live-state-controlled `Mp.stateTextField` for reusable single-line and
  multiline local editing with bounded input, actions, and explicit styling.
- Add semantic `Mp.tap` action wrapping for arbitrary authored child content.
- Add common add, delete, edit, and note icon names.

## 0.2.0

- Establish the feature-oriented authoring architecture as the supported
  baseline while preserving the public barrel API and serialized JSON output.
- Remove the temporary legacy `lib/src` compatibility re-exports announced in
  `0.1.13`; mini-program authors must import `mini_program_ui.dart`.

## 0.1.13

- Reorganize the pure-Dart authoring implementation into core, program, and
  feature-owned libraries while preserving the existing public API and JSON.
- Keep `Mp` as a signatures-and-delegation facade and add architecture tests
  for dependency direction, public exports, and legacy internal import shims.
- Retain old `lib/src` import paths as compatibility re-exports until `0.2.0`.

## 0.1.12

- Add strict `Mp.location.getCurrent` authoring for foreground, one-time,
  approximate host-provided location requests.

## 0.1.11

- Add artifact-local JSON load and ranked search action helpers.
- Add controlled search fields, horizontal list/repeat layouts, single-series
  line charts, and root pull-to-refresh authoring nodes.
- Add reusable location, weather, wind, temperature, and world icon names.

## 0.1.10

- Add bounded `Mp.actionScope` definitions and static `Mp.action.call`
  references for compact, reusable in-screen behavior.

## 0.1.9

- Add reactive `Mp.condition` node authoring.
- Add generic `Mp.action.ifElse` branching actions.
- Add lifecycle-owned `Mp.timer.countdown` nodes with pause, restart,
  remaining-seconds state, and completion actions.
- Add generic brain, trophy, timer, close, refresh, and bolt icon names.

## 0.1.8

- Add reusable styled text buttons and semantic icon buttons for compact,
  domain-specific mini-program controls.
- Add `history`, `backspace`, and `arrowBack` runtime icon names.

## 0.1.7

- Add `state.setDefault`, `state.decrement`, `state.copy`, and `state.toggle`.
- Extend `state.increment` with bound operands, defaults, and numeric bounds.
- Add atomic `state.patch`, `Mp.initialize`, and `Mp.stateScope` builders.
- Add app-scoped `Mp.cache.info` usage and accepted-policy introspection.

## 0.1.6

- Add bounded text and list state transformation action helpers.
- Add safe offline evaluate, compare, random, and aggregate math helpers.

## 0.1.5

- Add `Mp.cache.*` authoring helpers for `memory`, `data`, `image`, `state`,
  and `video` cache actions.
- Keep `session` and host-pinned cache priority out of mini-program authoring
  helpers.

## 0.1.3

- add `Mp.lazy.chunk` and `Mp.lazy.loadMore` authoring helpers for manual
  chunk/page loading with provider-neutral backend actions

## 0.1.2

- add `Mp.lazy.section` authoring helpers for cached lazy sections, action
  execution, status state, retry configuration, and placeholder/error templates

## 0.1.1

- refresh package metadata for the post-`0.1.0` patch release

## 0.1.0

- add Mp state, router, sequence, and `stateBuilder` authoring helpers
- keep `Mp.navigation` compatibility while adding `Mp.router` params/results
- add Mp authoring helpers for auth, backend, paged backend, and navigation
  runtime parity nodes and actions
- add the pure-Dart Mp JSON authoring foundation
- add explicit `MpProgram` screen registry and deterministic screen JSON output
- add layout, text, image, card, button, and email-auth action helpers
## 0.1.4

- Update the contracts dependency for the current static artifact plus runtime API boundary.
