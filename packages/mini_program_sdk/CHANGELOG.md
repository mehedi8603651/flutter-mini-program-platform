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
