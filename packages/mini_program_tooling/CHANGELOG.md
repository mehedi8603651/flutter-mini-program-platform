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
