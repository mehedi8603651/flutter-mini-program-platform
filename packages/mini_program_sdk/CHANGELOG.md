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
