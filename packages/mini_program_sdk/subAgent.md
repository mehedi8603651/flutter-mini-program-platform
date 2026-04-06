# mini_program_sdk Sub-Agent

## Mission
Build the portable runtime that validates, loads, renders, and safely bridges mini-programs inside Flutter host apps.

## Current Status
`mini_program_sdk` v1 exists and provides the first local proof path for:
- manifest loading through a host-provided source
- HTTP-backed manifest and screen loading through `HttpMiniProgramSource`
- manifest query-parameter support for backend delivery context
- release-control aware backend loading with optional pinned-version context
- SDK version validation
- capability validation
- feature-flag gating
- Stac initialization and entry-screen rendering
- approved host action dispatch for `openNativeScreen`, `callSecureApi`, and `trackEvent`
- controlled loading and fallback error UI
- basic SDK logging
- in-memory and file-backed manifest and screen caching with stale-on-error fallback
- persistent offline reuse when hosts provide a file-backed cache bundle

This package is the current shared runtime from the root `AGENTS.md`.
It now includes contract-driven cache rules, file-backed cache storage, and
bounded stale reuse for offline-safe recovery paths.

## Owns
- `HostBridge`
- `MiniProgramHost`
- Manifest loading
- Version validation
- Capability checks
- Stac initialization
- Safe action dispatch
- Fallback UI
- Basic SDK logging
- Contract-driven manifest and entry-screen caching
- Persistent cache bundle support for host apps

## Must Do
- Fail early on incompatible SDK or capability requirements.
- Keep native power behind the host bridge.
- Show controlled fallback UI for unsupported or broken flows.
- Log failures with stable error codes from contracts.

## Must Not Do
- Hardcode `super_app_host` behavior into the SDK.
- Call sensitive native features directly from remote JSON.
- Hide compatibility or validation failures.

## Current Package Structure
- `pubspec.yaml`
- `analysis_options.yaml`
- `lib/mini_program_sdk.dart`
- `lib/mini_program_host.dart`
- `lib/host_bridge.dart`
- `lib/capability_registry.dart`
- `lib/feature_flag_evaluator.dart`
- `lib/manifest_loader.dart`
- `lib/version_validator.dart`
- `lib/sdk_context.dart`
- `lib/mini_program_failure.dart`
- `lib/actions/`
- `lib/network/`
- `lib/observability/`
- `lib/rendering/`
- `lib/widgets/`
- `test/`

## Current File Notes
- `lib/network/mini_program_source.dart` defines the source contract for both asset and HTTP loaders.
- `lib/network/http_mini_program_source.dart` provides the current backend-facing sample loader for static or server-hosted JSON delivery.
- `lib/network/mini_program_source_exception.dart` carries backend rejection details and transport failures into SDK fallback UI.
- `lib/cache/manifest_cache.dart` provides async manifest cache abstractions plus in-memory and file-backed implementations.
- `lib/cache/screen_cache.dart` provides async entry-screen cache abstractions plus in-memory and file-backed implementations.
- `lib/cache/mini_program_cache_bundle.dart` groups manifest and screen cache stores for host injection.
- `lib/rendering/stac_initializer.dart` owns the current parser/action initialization path.
- `lib/observability/sdk_logger.dart` provides logging only. Error reporting and tracing are future additions, not current guarantees.

## v1 Runtime Surface
- Host widget: `MiniProgramHost`
- Host bridge: `HostBridge`
- Source contract: `MiniProgramSource`
- Backend loader: `HttpMiniProgramSource`
- Validation helpers: `VersionValidator`, `CapabilityRegistry`
- Runtime scope: `MiniProgramSdkScope`
- Stac bridge action: `hostAction`
- Host action dispatcher: `HostActionDispatcher`
- Default UI: `SdkLoadingView`, `SdkErrorView`
- Logging: `SdkLogger`

## Runtime Rules
- Always validate manifest SDK range before rendering.
- Always validate required capabilities before rendering.
- Treat manifest feature flags as hard gates when an evaluator is provided.
- Only dispatch approved contract actions through `HostBridge`.
- Use `HostActionRequest` and `HostActionResult` for bridge handoff.
- Keep `callSecureApi` allowlisted at the host layer. The SDK may dispatch it, but it must not invent endpoint policy.
- Keep Stac custom action support inside the SDK, not in host apps.
- Keep backend format assumptions out of the SDK except for explicit contracts and `MiniProgramSource`.
- Keep screen loading version-aware. Hosts may ignore version for bundled assets, but backend loaders must not.
- Pass host delivery context to backend loaders explicitly instead of hardcoding backend-side assumptions in widgets.
- Preserve backend rejection messages and transport failures as structured source errors so hosts get controlled fallback UX on real devices.
- Keep backend decision metadata intact enough for host-facing diagnostics when rollout or capability checks fail.
- Keep auth passive in v1. `Capability.auth` may be validated, but auth bridge APIs are not part of this package yet.
- Cache only when the manifest allows it. `noCache` manifests and entry screens must never reuse stale cached content.
- Only use stale cache on retryable backend failures such as unreachable or timeout conditions.
- Enforce `maxStaleSeconds` when reusing persisted manifest or screen payloads.
- Treat persisted cache as a host runtime concern. Tests may inject in-memory caches, but mobile hosts should prefer file-backed cache bundles.

## Deferred Until Later Phases
- Asset caching
- Backend client helpers such as `mini_program_api.dart`
- Auth header injection and asset resolution helpers
- Broader parser and widget fallback registries
- Error reporting and trace context plumbing
- Additional bridge actions such as payment or secure API calls

These are valid future additions, but they should not be added until the current host proof is working end to end.

## Tests and Verification
- `flutter test`
- `flutter analyze`

## Next Step
The next implementation phase is stronger offline freshness policy and
production backend work on top of the current capability surface.

That phase should keep using this SDK while adding:
- persistent cache storage beyond manifest and entry-screen JSON
- richer stale-cache diagnostics and user-visible offline state where needed
- cache metadata for more than manifest and entry-screen payloads
