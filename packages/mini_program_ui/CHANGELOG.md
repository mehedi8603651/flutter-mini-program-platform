# Changelog

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
