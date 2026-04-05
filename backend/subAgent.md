# backend Sub-Agent

## Mission
Deliver versioned mini-program artifacts safely to host apps and the shared SDK.

## Owns
- Manifest delivery
- Screen and theme delivery
- Asset delivery
- Rollout rules
- Capability-aware delivery policy
- Version pinning and compatibility responses

## Must Do
- Keep delivery compatible with contract and SDK rules.
- Make rollout and version decisions explicit.
- Support cache metadata intentionally, not implicitly.

## Must Not Do
- Serve incompatible mini-program versions silently.
- Treat remote JSON as trusted executable logic.
- Hide rollout or capability mismatches.

## MVP Direction
- Start with one manifest endpoint and one screen endpoint.
- Add rollout and caching metadata only after base delivery works.

## Current Local Sample
- `profile_center` is published as static sample files under `backend/api/`.
- Treat those files as derived artifacts, not source of truth.
- Refresh them from `mini_programs/profile_center` with `tools/publish_local_backend.ps1`.
- `backend/local_backend_service` now serves those published files through a real Dart HTTP process.
- `super_app_host` can consume the service endpoints through the SDK's `HttpMiniProgramSource`.
- `profile_center` now has local rollout rules and capability policy samples for dynamic `latest` manifest delivery.

## Next Step
- Add a second published mini-program version and prove backend-side version selection changes what `latest` returns for different hosts or rollout rules.
