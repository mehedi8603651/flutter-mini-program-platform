# Changelog

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
