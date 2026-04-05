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
- Local secure API policy enforcement

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
- `feedback_form` is now published there as the second real mini-program sample.
- Treat those files as derived artifacts, not source of truth.
- Refresh them from `mini_programs/<id>` with `tools/publish_local_backend.ps1`.
- `backend/local_backend_service` now serves those published files through a real Dart HTTP process.
- `super_app_host` can consume the service endpoints through the SDK's `HttpMiniProgramSource`.
- `profile_center` now has local rollout rules and capability policy samples for dynamic `latest` manifest delivery.
- The delivery selector now supports ordered rollout rules with `hostApp`, `hostVersionRange`, `platform`, `locale`, and optional `tenantId` matching.
- The delivery selector now supports an optional `pinnedVersion` request override for release-control testing.
- Successful `latest` responses now include delivery decision metadata such as `selectionMode`, `resolvedVersion`, and optional `matchedRuleId`.
- The current sample proves backend-side version selection:
  - `super_app_host` resolves `latest` to `1.1.0`
  - `partner_app_host` resolves `latest` to `1.0.0`
  - both hosts can also consume `feedback_form` `1.1.0`
- `feedback_form` delivery now proves capability-aware `secure_api` rollout checks
- `POST /api/secure/feedback/submit` now provides a real local secure endpoint backed by `api/secure-api-policies/feedback_submit.json`

## Next Step
- Move from local sample release control to a production backend service with persistent rollout storage, admin-managed pinning, and stronger observability.
