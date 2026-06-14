## 0.6.1

- Generate Android debug manifests that can override host `usesCleartextTraffic` settings safely.
- Generate host/preview projects with `mini_program_sdk: ^0.5.1` so Android release builds use const runtime icons.

## 0.6.0

- Remove external artifact delivery adapters and credential handoff flows from the active CLI.
- Keep static artifact publishing as the current frontend delivery path.
- Keep optional Publisher API/local mock runtime API flows.
- Generate/import partner packages around `appId + artifactBaseUrl`.
- Update workflow status, help text, docs, and tests for the static artifact plus optional middle-server architecture.
